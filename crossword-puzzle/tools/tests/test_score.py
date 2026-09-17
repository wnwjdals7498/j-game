"""02-08 난이도 점수 · 7티어 분할 테스트.

케이스는 02-08 "테스트" 절 표 중 점수·티어 11종을 그대로 옮긴 것이다
(자모 4종은 `test_hangul.py`). 입력은 손으로 만든 `merged.jsonl` 이며
**실데이터가 아니다** (00-01 승인 대기, tools/README.md 참조).
"""
import re

import pytest

from tools import config, io_util
from tools.score import IN, OUT, apply_word_cap, assign_tiers, compute_score, run


def _r(headword="가나", freq_rank=None, vocab_grade=None, in_krdict=False) -> dict:
    """merged.jsonl 한 행 (02-07 출력 스키마). 점수에 쓰이는 필드만 의미가 있다."""
    return {"headword": headword, "len": len(headword), "syllables": list(headword),
            "pos": "명사", "source": config.SRC_KRDICT if in_krdict else config.SRC_STDICT,
            "freq_rank": freq_rank, "vocab_grade": vocab_grade,
            "in_krdict": in_krdict, "senses": []}


def _run(tmp_path, monkeypatch, rows) -> list[dict]:
    build = tmp_path / "build"
    build.mkdir(parents=True, exist_ok=True)
    monkeypatch.setattr(config, "BUILD", build)
    io_util.write_jsonl(build / IN, rows)
    n = run(use_fixtures=True)
    out = list(io_util.read_jsonl(build / OUT))
    assert n == len(out)
    return out


def _hw(i: int) -> str:
    """서로 다른 2음절 표제어. 동점일 때 정렬 키가 되므로 중복되면 안 된다."""
    return chr(0xAC00 + (i % 11172)) + chr(0xAC00 + (i * 7 + 3) % 11172)


# --- 02-08 "테스트" 표: 산식 ---

def test_top_frequency_gives_base_zero():
    """빈도 1위 -> base 0. 보정이 하나도 없으면 점수도 0."""
    assert compute_score(_r("가나", freq_rank=1), max_rank=1000) == 0.0
    assert compute_score(_r("가나", freq_rank=1), max_rank=1) == 0.0


def test_no_frequency_gives_no_freq_base():
    """빈도 없음 -> `NO_FREQ_BASE`. 보정이 없으면 그 값이 그대로 점수."""
    assert compute_score(_r("가나", freq_rank=None), max_rank=1000) == config.NO_FREQ_BASE


def test_vocab_grade_a_is_easier_than_b():
    """등급 A 보정: 다른 조건이 같으면 A 가 B 보다 점수가 낮다 (C < 없음 순서도 확인)."""
    s = {g: compute_score(_r("가나", freq_rank=500, vocab_grade=g), 1000)
         for g in ("A", "B", "C", None)}
    assert s["A"] < s["B"] < s["C"] < s[None]


def test_in_krdict_is_easier():
    """기초 등재 보정: 기초사전에 있는 쪽이 점수가 낮다."""
    assert (compute_score(_r("가나", freq_rank=500, in_krdict=True), 1000)
            < compute_score(_r("가나", freq_rank=500, in_krdict=False), 1000))


def test_syllable_penalty():
    """음절 패널티: 다른 조건이 같으면 5음절이 2음절보다 점수가 높다.

    표제어는 둘 다 복잡 자모가 없어야 음절 수만 비교된다.
    """
    short, long = _r("가나", freq_rank=500), _r("가나다라마", freq_rank=500)
    assert compute_score(long, 1000) > compute_score(short, 1000)
    assert compute_score(long, 1000) - compute_score(short, 1000) == pytest.approx(
        config.ADJ_PER_EXTRA_SYLLABLE * 3)


def test_complex_jamo_penalty():
    """복잡 자모 패널티: `닭고기`(겹받침 ㄺ)가 `다고기`(단순)보다 점수가 높다."""
    a = compute_score(_r("닭고기", freq_rank=500), 1000)
    b = compute_score(_r("다고기", freq_rank=500), 1000)
    assert a > b
    assert a - b == pytest.approx(config.ADJ_COMPLEX_JAMO)


@pytest.mark.parametrize("rank", [None, 1, 2, 500, 999, 1000])
@pytest.mark.parametrize("grade", ["A", "B", "C", None])
@pytest.mark.parametrize("headword", ["가나", "닭", "왜죄궤귀긔", "가나다라마"])
@pytest.mark.parametrize("in_krdict", [True, False])
def test_score_is_clamped(rank, grade, headword, in_krdict):
    """clamp: 어떤 조합이든 결과가 [0, 1] 안에 있다."""
    s = compute_score(_r(headword, rank, grade, in_krdict), 1000)
    assert 0.0 <= s <= 1.0


# --- 02-08 "테스트" 표: 티어 ---

@pytest.fixture
def tiered() -> list[dict]:
    """1000행에 서로 다른 점수를 줘서 티어를 매긴 결과. 1000행이면 비율이 딱 떨어진다."""
    rows = [{"headword": _hw(i), "score": round(i / 1000, 6)} for i in range(1000)]
    assign_tiers(rows)
    return rows


def _counts(rows) -> list[int]:
    return [sum(1 for r in rows if r["tier"] == t)
            for t in range(1, config.TIER_COUNT + 1)]


def test_tier_ratio_matches_config(tiered):
    """티어 비율: 각 티어 개수가 `TIER_RATIO` ±1%."""
    n = len(tiered)
    for got, ratio in zip(_counts(tiered), config.TIER_RATIO):
        assert abs(got / n * 100 - ratio) <= 1.0


def test_tier_distribution_is_pyramid(tiered):
    """피라미드: `count[1] > count[2] > ... > count[7]`. 등분위였다면 여기서 깨진다."""
    counts = _counts(tiered)
    assert all(a > b for a, b in zip(counts, counts[1:])), counts


def test_tier_range(tiered):
    """티어 범위: 모든 행이 1..7 을 받는다 (빠진 행 없음)."""
    assert {r["tier"] for r in tiered} == set(range(1, config.TIER_COUNT + 1))
    assert all("tier" in r for r in tiered)


def test_ties_are_assigned_stably(tmp_path, monkeypatch):
    """동점 안정 정렬: 전부 동점이어도 입력 순서를 뒤집어 두 번 돌리면 같은 결과.

    `words.sqlite` 의 sha256 비교(05-01)가 안정적이려면 여기부터 재현 가능해야 한다.
    """
    rows = [_r(_hw(i), freq_rank=7) for i in range(40)]      # 전원 동점
    a = _run(tmp_path, monkeypatch, rows)
    first = (config.BUILD / OUT).read_bytes()

    b = _run(tmp_path, monkeypatch, list(reversed(rows)))
    assert (config.BUILD / OUT).read_bytes() == first
    assert {r["headword"]: r["tier"] for r in a} == {r["headword"]: r["tier"] for r in b}


# --- run() 출력 스키마 · 로그 ---

def test_run_adds_score_and_tier(tmp_path, monkeypatch, capsys):
    """`scored.jsonl` = `merged.jsonl` + `score`/`tier`. 티어별 개수가 로그에 찍힌다 (DoD)."""
    src = [_r("사과", 25, "A", True), _r("심근경색", None, "C", False),
           _r("나무", 21, "A", True), _r("미분방정식", None, "C", False)]
    rows = _run(tmp_path, monkeypatch, src)

    assert set(rows[0]) == set(src[0]) | {"score", "tier"}
    assert all(0.0 <= r["score"] <= 1.0 for r in rows)
    assert all(1 <= r["tier"] <= config.TIER_COUNT for r in rows)
    assert [r["score"] for r in rows] == sorted(r["score"] for r in rows)
    # 빈도 없는 전문어가 위쪽 티어로 간다 (02-08 "`base` 정규화" 주의: 정상 동작)
    by = {r["headword"]: r for r in rows}
    assert by["사과"]["tier"] < by["심근경색"]["tier"]

    out = capsys.readouterr().out
    assert re.search(r"score: 4 words", out)
    for t in range(1, config.TIER_COUNT + 1):
        assert re.search(rf"tier {t}\s+\d", out)


# --- 02-01 재적재(88,957개 실측) 대응: 용량 컷 (config.MAX_WORDS) ---

def test_apply_word_cap_keeps_lowest_scoring_rows(monkeypatch):
    """컷이 있으면 score 오름차순(쉬운 순) 상위 N개만 남는다."""
    monkeypatch.setattr(config, "MAX_WORDS", 3)
    rows = [{"headword": _hw(i), "score": s} for i, s in enumerate([0.9, 0.1, 0.5, 0.3, 0.7])]
    kept = apply_word_cap(rows)
    assert len(kept) == 3
    assert sorted(r["score"] for r in kept) == [0.1, 0.3, 0.5]


def test_apply_word_cap_noop_when_under_limit(monkeypatch):
    """행 수가 `MAX_WORDS` 이하면 그대로 통과한다 (fixtures 빌드가 이 경로를 탄다)."""
    monkeypatch.setattr(config, "MAX_WORDS", 100)
    rows = [{"headword": _hw(i), "score": 0.5} for i in range(5)]
    assert len(apply_word_cap(rows)) == 5


def test_apply_word_cap_disabled_when_falsy(monkeypatch):
    """`MAX_WORDS` 가 0/None 이면 컷을 걸지 않는다."""
    monkeypatch.setattr(config, "MAX_WORDS", None)
    rows = [{"headword": _hw(i), "score": 0.5} for i in range(5)]
    assert len(apply_word_cap(rows)) == 5


def test_run_applies_word_cap_before_tiering(tmp_path, monkeypatch):
    """`run()` 전체 경로: 컷 이후에도 tier 비율은 잘린 부분집합 기준으로 다시 맞는다."""
    monkeypatch.setattr(config, "MAX_WORDS", 100)
    rows = [_r(_hw(i), freq_rank=i + 1) for i in range(1000)]
    out = _run(tmp_path, monkeypatch, rows)
    assert len(out) == 100
    # 컷 후에도 가장 쉬운(빈도 1위) 쪽이 남고, tier 1이 존재한다 (등분위 아님 유지).
    assert {r["tier"] for r in out} <= set(range(1, config.TIER_COUNT + 1))
    assert min(r["tier"] for r in out) == 1


def test_score_is_rounded_to_six_places(tmp_path, monkeypatch):
    """`round(score, 6)`: 부동소수 꼬리가 파일에 새어 나오면 실행마다 바이트가 달라진다.

    `1/3` 처럼 딱 안 떨어지는 base 를 만들어 **파일에 적힌 자릿수**를 센다.
    """
    _run(tmp_path, monkeypatch, [_r(_hw(i), freq_rank=i + 1) for i in range(4)])
    text = (config.BUILD / OUT).read_text(encoding="utf-8")
    tails = re.findall(r'"score": \d+\.(\d+)', text)
    assert tails and all(len(t) <= 6 for t in tails), tails
