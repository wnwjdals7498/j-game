"""현대 국어 사용 빈도 조사 2 csv -> build/freq.jsonl (02-05).

난이도 산식(02-08)의 **주 지표**. 컬럼 이름은 tools/README.md
"실제 파일 구조 조사 결과 -> 3. 현대 국어 사용 빈도 조사 2" 절 기준이다.
표제어는 원문 그대로 싣는다 — 정규화는 02-06.
"""
import csv
from pathlib import Path
from . import config, io_util

OUT = "freq.jsonl"

# README 3절 조사 결과(헤더 1행, `순위,어휘,품사,빈도`).
# 실데이터 헤더가 다르면 02-01 로 돌아가 조사한 뒤 여기만 고친다.
FREQ_COL_WORD = "어휘"
FREQ_COL_RANK = "순위"      # 순위 컬럼이 없는 원본이면 None 으로 바꾼다
FREQ_COL_COUNT = "빈도"

_MISSING = object()


def _src_files(use_fixtures: bool) -> list[Path]:
    base = config.FIXTURES if use_fixtures else config.RAW
    return sorted(base.glob("*freq*.csv")) or sorted((base / "freq").glob("*.csv"))


def _to_int(v):
    """`"1,234"` 같은 천단위 구분자를 처리한다. 숫자가 아니면 None."""
    if v is None:
        return None
    s = str(v).replace(",", "").strip()
    return int(s) if s.isdigit() else None


def _assign_ranks(rows: list[dict]) -> None:
    """순위 컬럼이 없을 때 count 내림차순으로 rank 를 직접 부여한다 (02-05 출력 스키마).

    동률은 같은 순위를 준다. 그 뒤 rank 가 건너뛰어도 무방하다 — 02-08은 정규화만 한다.
    """
    rows.sort(key=lambda r: -(r["count"] or 0))
    prev, rank = _MISSING, 0
    for i, r in enumerate(rows, 1):
        if r["count"] != prev:
            rank, prev = i, r["count"]
        r["rank"] = rank


def _best_by_headword(rows: list[dict]) -> dict[str, dict]:
    """같은 표제어가 품사별로 여러 번 나온다 (`사람/명사`, `사람/의존명사`).

    게임의 `word` 는 표제어 문자열이 PK 이므로 (DESIGN 4절) **가장 높은 순위(작은 rank)만**
    남긴다. 난이도상 보수적인(= 쉽게 보는) 선택이다 — 02-05 "중복 표제어 처리".
    """
    best: dict[str, dict] = {}
    for r in rows:
        cur = best.get(r["headword"])
        if cur is None or r["rank"] < cur["rank"]:
            best[r["headword"]] = r
    return best


def run(use_fixtures: bool = False) -> int:
    files = _src_files(use_fixtures)
    if not files:
        raise FileNotFoundError("빈도 csv 없음. tools/raw/ 확인 (00-01)")

    stats = {"files": len(files), "read": 0, "drop_no_word": 0}
    rows: list[dict] = []
    for p in files:
        f, enc = io_util.open_csv(p)
        print(f"    freq: {p.name} 인코딩={enc}")
        with f:
            for r in csv.DictReader(f):
                stats["read"] += 1
                w = (r.get(FREQ_COL_WORD) or "").strip()
                if not w:
                    stats["drop_no_word"] += 1
                    continue
                cnt = _to_int(r.get(FREQ_COL_COUNT))
                rk = _to_int(r.get(FREQ_COL_RANK)) if FREQ_COL_RANK else None
                rows.append({"headword": w, "rank": rk, "count": cnt})

    if any(r["rank"] is None for r in rows):
        _assign_ranks(rows)

    best = _best_by_headword(rows)
    stats["drop_dup"] = len(rows) - len(best)
    stats["kept"] = io_util.write_jsonl(config.BUILD / OUT, best.values())
    print(f"    freq: {stats}")
    return stats["kept"]
