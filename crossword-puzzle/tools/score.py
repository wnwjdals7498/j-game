"""복합 점수 + 7티어 -> build/scored.jsonl (02-08).

`merged.jsonl` 의 각 표제어에 0(쉬움)~1(어려움) 점수를 매기고,
**피라미드 비율**(`config.TIER_RATIO`)로 7티어로 자른다. 산식과 비율은
[docs/plan/02-08.score-tier.md](../docs/plan/02-08.score-tier.md) "산식"·"티어 분할" 이
정한 것이고, 여기서 그대로 구현한다. 조정 손잡이는 전부 `config.py` 에 있다.

> 7등분할 때 **등분위 금지** — 상위 티어를 얇게 가져간다 (DESIGN 4절 "난이도 7단계 기준").

`config.MAX_WORDS` 가 설정돼 있으면 점수 매긴 뒤 tier 나누기 전에 상위(쉬운) N개만
남긴다 (02-01 실데이터 88,957개가 10MB 목표를 크게 넘어 02-09 "막히면"의 대안으로
채택 — `config.py` MAX_WORDS 주석 참고).
"""
from . import config, hangul, io_util

OUT = "scored.jsonl"
IN = "merged.jsonl"


def compute_score(r: dict, max_rank: int) -> float:
    """clamp(base + adj, 0, 1). `max_rank` 는 이번 실행의 최하위 빈도 순위.

    빈도가 주 신호이고 나머지는 보정이다. 빈도 정보가 없으면 `NO_FREQ_BASE`(=1.0) —
    빈도 조사에 안 나오는 단어는 실제로 어렵다 (02-08 "`base` 정규화" 주의).
    """
    rank = r.get("freq_rank")
    base = (config.NO_FREQ_BASE if rank is None
            else (rank - 1) / max(max_rank - 1, 1))

    adj = 0.0
    g = r.get("vocab_grade")
    if g in config.ADJ_VOCAB:
        adj += config.ADJ_VOCAB[g]
    if r.get("in_krdict"):
        adj += config.ADJ_IN_KRDICT
    adj += config.ADJ_PER_EXTRA_SYLLABLE * (r["len"] - 2)
    if hangul.has_complex_jamo(r["headword"]):
        adj += config.ADJ_COMPLEX_JAMO

    return min(1.0, max(0.0, base + adj))


def assign_tiers(scored: list[dict]) -> None:
    """`scored` 를 score 오름차순으로 정렬한 뒤 `tier` 를 부여한다 (제자리 수정).

    동점은 `headword` 로 안정 정렬한다 — 같은 입력이면 같은 티어 배정이 나와야
    `words.sqlite` 의 sha256 비교(05-01)가 안정적이다 (02-08 DoD "동점 처리가 안정적").
    """
    scored.sort(key=lambda r: (r["score"], r["headword"]))
    n = len(scored)
    bounds, acc = [], 0
    for ratio in config.TIER_RATIO:
        acc += ratio
        bounds.append(round(n * acc / 100))
    bounds[-1] = n                     # 반올림 오차 흡수 (02-08 "막히면")

    t, start = 1, 0
    for end in bounds:
        for i in range(start, end):
            scored[i]["tier"] = t
        start = end
        t += 1


def apply_word_cap(rows: list[dict]) -> list[dict]:
    """`config.MAX_WORDS` 가 있으면 score 오름차순(쉬운 순) 상위 N개만 남긴다.

    실데이터(88,957개, 02-01)에서는 `DEFINITION_MAX_CHARS` 로 10MB 목표를 맞출 수
    없었다(config.py MAX_WORDS 주석 참고) — 그래서 여기서 표제어 수 자체를 줄인다.
    자르는 기준이 score(빈도·등급·기초사전 등재 보정을 이미 반영한 값)이므로,
    잘려 나가는 쪽은 빈도 정보가 없는(가장 불확실한) 표제어부터다. `assign_tiers`
    는 이 함수가 돌려준 부분집합에 대해서만 새로 호출되므로 TIER_RATIO 비율은
    그대로 유지된다. fixtures/소규모 입력은 `len(rows) <= MAX_WORDS` 라 그대로 통과한다.
    """
    rows.sort(key=lambda r: (r["score"], r["headword"]))
    cap = config.MAX_WORDS
    if cap and len(rows) > cap:
        dropped = len(rows) - cap
        print(f"    score: 용량 컷 적용 - 상위 {cap:,}개만 유지 (하위 {dropped:,}개 제외,"
              f" config.MAX_WORDS)")
        rows = rows[:cap]
    return rows


def run(use_fixtures: bool = False) -> int:
    rows = list(io_util.read_jsonl(config.BUILD / IN))
    ranks = [r["freq_rank"] for r in rows if r.get("freq_rank")]
    max_rank = max(ranks) if ranks else 1

    for r in rows:
        # round(, 6): 부동소수 꼬리 때문에 파일이 실행마다 달라지는 걸 막는다 (재현성).
        r["score"] = round(compute_score(r, max_rank), 6)
    rows = apply_word_cap(rows)
    assign_tiers(rows)

    counts: dict[int, int] = {}
    for r in rows:
        counts[r["tier"]] = counts.get(r["tier"], 0) + 1
    print(f"    score: {len(rows):,} words")
    for t in range(1, config.TIER_COUNT + 1):
        n = counts.get(t, 0)
        print(f"      tier {t}  {n:>7,}  {n / max(len(rows), 1) * 100:5.1f}%")

    return io_util.write_jsonl(config.BUILD / OUT, rows)
