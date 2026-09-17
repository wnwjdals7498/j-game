"""한국어 학습용 어휘 목록 xls -> build/vocab.jsonl (02-05).

02-01 재조사(2026-09-17) 결과 원본은 csv 가 아니라 xls(레거시 BIFF)다(00-01 예상과 다름).
실제 파일 `tools/raw/한국어 학습용 어휘 목록.xls` (5,965행, 헤더 `순위,단어,품사,풀이,등급`).
`xlrd` 2.x 는 `.xlsx` 를 읽지 못하고 `.xls` 만 지원한다 -- 이 파일이 진짜 레거시 xls 라
그대로 맞는다.

**등급 컬럼이 이미 `A`/`B`/`C` 그대로다** (5,965행 전수 확인 -- "초급/중급/고급" 표기는
한 건도 없다). `GRADE_MAP` 의 항등 매핑(`"A": "A"` 등)이 그대로 전부를 커버한다.
분포는 A(초급) 982 / B(중급) 2,111 / C(고급) 2,872 로, 절대다수를 차지할 거라 가정했던
A 가 오히려 가장 적다.

**단어 컬럼에도 동형어 번호가 붙어 있다** (예: '가격03' -- 5,965행 중 2,778행).
freq 와 같은 이유로 `hangul.normalize_headword` 를 적용한 뒤 등급을 결합한다
(02-07.merge.md "막히면", tools/parse_freq.py 상단 주석 참고).
"""
from collections import Counter
from pathlib import Path

import xlrd

from . import config, io_util
from .hangul import normalize_headword

OUT = "vocab.jsonl"

# README 4절 조사 결과(헤더 1행, `순위,단어,품사,풀이,등급`).
VOCAB_COL_WORD = "단어"
VOCAB_COL_GRADE = "등급"

# 원본 등급 표기 -> A(초급)/B(중급)/C(고급). 02-05 "출력 스키마".
# 실데이터는 이미 A/B/C 이므로 항등 매핑만 실제로 쓰인다. "초급/중급/고급" 매핑은
# 과거(00-01 승인 전 샘플 기준) 가정이 남긴 것으로, 향후 원본이 텍스트 표기로 바뀌어도
# 깨지지 않도록 그대로 둔다.
GRADE_MAP = {
    "초급": "A", "중급": "B", "고급": "C",
    "A": "A", "B": "B", "C": "C",
}

# 중복 표제어에서 어느 등급을 남길지의 순서. A 가 가장 쉽다 (config.ADJ_VOCAB).
GRADE_ORDER = {"A": 0, "B": 1, "C": 2}


def _src_files(use_fixtures: bool) -> list[Path]:
    base = config.FIXTURES if use_fixtures else config.RAW
    if use_fixtures:
        return sorted(base.glob("*vocab*.xls")) or sorted((base / "vocab").glob("*.xls"))
    # 실데이터 파일명은 "한국어 학습용 어휘 목록.xls" 하나뿐이라(00-01: 이름 변경 금지)
    # 재귀로 .xls 를 찾되 확장자로 구분한다(빈도 파일은 .xlsx 라 섞이지 않는다).
    return sorted(base.rglob("*.xls"))


def _rows_from_sheet(path: Path):
    """xls 첫 시트를 `{컬럼명: 값}` dict 의 이터레이터로 돌려준다 (csv.DictReader 대응)."""
    wb = xlrd.open_workbook(str(path))
    sh = wb.sheet_by_index(0)
    header = sh.row_values(0)
    idx = {name: i for i, name in enumerate(header) if name}
    for r in range(1, sh.nrows):
        row = sh.row_values(r)
        yield {name: row[i] if i < len(row) else None for name, i in idx.items()}


def _best_by_headword(rows: list[dict]) -> dict[str, dict]:
    """표제어가 PK 이므로 (DESIGN 4절) 중복이면 **가장 쉬운 등급(A<B<C)만** 남긴다.

    02-05 "중복 표제어 처리"가 빈도에 대해 정한 "가장 높은 순위만 = 쉽게 보는 쪽" 규칙을
    같은 방향으로 적용한 것이다. 실데이터에는 정규화 전 기준으로도 104개 표제어가
    중복이다(예: '가다01' 이 글자 그대로 두 번 나옴) -- 02-01 "미해결" 항목 해소.
    """
    best: dict[str, dict] = {}
    for r in rows:
        cur = best.get(r["headword"])
        if cur is None or GRADE_ORDER[r["grade"]] < GRADE_ORDER[cur["grade"]]:
            best[r["headword"]] = r
    return best


def run(use_fixtures: bool = False) -> int:
    files = _src_files(use_fixtures)
    if not files:
        raise FileNotFoundError(
            "학습용 어휘 xls 없음. tools/raw/한국어 학습용 어휘 목록.xls 확인 (00-01)")

    stats = {"files": len(files), "read": 0, "drop_no_word": 0,
              "drop_unmapped_grade": 0}
    unmapped: Counter[str] = Counter()
    rows: list[dict] = []
    for p in files:
        print(f"    vocab: {p.name}")
        for r in _rows_from_sheet(p):
            stats["read"] += 1
            w_raw = str(r.get(VOCAB_COL_WORD) or "").strip()
            if not w_raw:
                stats["drop_no_word"] += 1
                continue
            w = normalize_headword(w_raw)
            if not w:
                stats["drop_no_word"] += 1
                continue
            raw_grade = str(r.get(VOCAB_COL_GRADE) or "").strip()
            grade = GRADE_MAP.get(raw_grade)
            if grade is None:
                # 조용히 버리지 않는다 — 개수와 실제 값을 로그에 찍는다 (02-05).
                stats["drop_unmapped_grade"] += 1
                unmapped[raw_grade] += 1
                continue
            rows.append({"headword": w, "grade": grade})

    best = _best_by_headword(rows)
    stats["drop_dup"] = len(rows) - len(best)
    stats["kept"] = io_util.write_jsonl(config.BUILD / OUT, best.values())
    print(f"    vocab: {stats}")
    if unmapped:
        print(f"    vocab: 미매칭 등급 {stats['drop_unmapped_grade']}건 "
              f"-> {dict(unmapped)} (GRADE_MAP 에 추가할지 02-01 로 확인)")
    return stats["kept"]
