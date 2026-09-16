"""한국어 학습용 어휘 목록 csv -> build/vocab.jsonl (02-05).

난이도 산식(02-08)의 **보정 지표**(`config.ADJ_VOCAB`). 컬럼 이름은 tools/README.md
"실제 파일 구조 조사 결과 -> 4. 한국어 학습용 어휘 목록" 절 기준이다.
표제어는 원문 그대로 싣는다 — 정규화는 02-06.
"""
import csv
from collections import Counter
from pathlib import Path
from . import config, io_util

OUT = "vocab.jsonl"

# README 4절 조사 결과(헤더 1행, `어휘,품사,등급`).
VOCAB_COL_WORD = "어휘"
VOCAB_COL_GRADE = "등급"

# 원본 등급 표기 -> A(초급)/B(중급)/C(고급). 02-05 "출력 스키마".
# 실데이터가 `1급/2급/...` 으로 오면 02-01 로 돌아가 값을 전수 조사한 뒤 여기에 추가한다.
GRADE_MAP = {
    "초급": "A", "중급": "B", "고급": "C",
    "A": "A", "B": "B", "C": "C",
}

# 중복 표제어에서 어느 등급을 남길지의 순서. A 가 가장 쉽다 (config.ADJ_VOCAB).
GRADE_ORDER = {"A": 0, "B": 1, "C": 2}


def _src_files(use_fixtures: bool) -> list[Path]:
    base = config.FIXTURES if use_fixtures else config.RAW
    return sorted(base.glob("*vocab*.csv")) or sorted((base / "vocab").glob("*.csv"))


def _best_by_headword(rows: list[dict]) -> dict[str, dict]:
    """표제어가 PK 이므로 (DESIGN 4절) 중복이면 **가장 쉬운 등급(A<B<C)만** 남긴다.

    02-05 "중복 표제어 처리"가 빈도에 대해 정한 "가장 높은 순위만 = 쉽게 보는 쪽" 규칙을
    같은 방향으로 적용한 것이다. 샘플에는 중복이 없어 실데이터로 확인이 필요하다
    (tools/README.md "미해결").
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
        raise FileNotFoundError("학습용 어휘 csv 없음. tools/raw/ 확인 (00-01)")

    stats = {"files": len(files), "read": 0, "drop_no_word": 0,
             "drop_unmapped_grade": 0}
    unmapped: Counter[str] = Counter()
    rows: list[dict] = []
    for p in files:
        f, enc = io_util.open_csv(p)
        print(f"    vocab: {p.name} 인코딩={enc}")
        with f:
            for r in csv.DictReader(f):
                stats["read"] += 1
                w = (r.get(VOCAB_COL_WORD) or "").strip()
                if not w:
                    stats["drop_no_word"] += 1
                    continue
                raw_grade = (r.get(VOCAB_COL_GRADE) or "").strip()
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
