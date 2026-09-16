"""02-07 표제어 기준 결합 테스트.

케이스는 02-07 "테스트" 절의 표(11종)를 그대로 옮긴 것이다.
입력은 02-03~02-06 이 픽스처로 만든 build/*.jsonl 이며 **실데이터가 아니다**
(00-01 승인 대기, tools/README.md 참조).
"""
import re

import pytest

from tools import config, io_util, normalize, parse_freq, parse_krdict, parse_stdict, parse_vocab
from tools.merge import IN, OUT, run

SCHEMA_KEYS = {"headword", "len", "syllables", "pos", "source", "freq_rank",
               "vocab_grade", "in_krdict", "senses"}
SENSE_KEYS = {"sense_id", "definition", "synonyms", "source"}


def _n(source, sense_id, headword, definition="뜻풀이.", synonyms=(), pos="명사") -> dict:
    """normalized.jsonl 한 행 (02-06 출력 스키마)."""
    return {"source": source, "sense_id": sense_id, "headword": headword,
            "raw_headword": headword, "len": len(headword),
            "syllables": list(headword), "pos": pos,
            "definition": definition, "synonyms": list(synonyms)}


def _build(tmp_path, monkeypatch, normalized, freq=None, vocab=None):
    """tmp BUILD 에 입력 jsonl 을 깐다. None 이면 **파일을 안 만든다.**"""
    build = tmp_path / "build"
    build.mkdir(parents=True, exist_ok=True)
    monkeypatch.setattr(config, "BUILD", build)
    io_util.write_jsonl(build / IN, normalized)
    if freq is not None:
        io_util.write_jsonl(build / "freq.jsonl", freq)
    if vocab is not None:
        io_util.write_jsonl(build / "vocab.jsonl", vocab)
    return build


def _run(tmp_path, monkeypatch, normalized, freq=None, vocab=None) -> list[dict]:
    build = _build(tmp_path, monkeypatch, normalized, freq, vocab)
    n = run(use_fixtures=True)
    rows = list(io_util.read_jsonl(build / OUT))
    assert n == len(rows)
    return rows


def _by_hw(rows) -> dict:
    return {r["headword"]: r for r in rows}


# --- 02-07 "테스트" 표 11종 ---

def test_homonyms_collapse_into_one_word(tmp_path, monkeypatch):
    """동음이의어 결합: 같은 표제어 2 sense -> `word` 1행."""
    rows = _run(tmp_path, monkeypatch, [
        _n("krdict", "krdict:1", "사과", "둥근 과일."),
        _n("krdict", "krdict:2", "사과", "잘못을 빎."),
    ])
    assert [r["headword"] for r in rows] == ["사과"]
    assert set(rows[0]) == SCHEMA_KEYS
    assert set(rows[0]["senses"][0]) == SENSE_KEYS


def test_krdict_wins_over_stdict(tmp_path, monkeypatch):
    """기초 우선: 둘 다 있으면 `senses[0].source == 1`."""
    rows = _run(tmp_path, monkeypatch, [
        _n("stdict", "stdict:1", "나무", "표준 뜻풀이."),
        _n("krdict", "krdict:9", "나무", "기초 뜻풀이."),
    ])
    s0 = rows[0]["senses"][0]
    assert s0["source"] == config.SRC_KRDICT
    assert s0["definition"] == "기초 뜻풀이."
    assert rows[0]["in_krdict"] is True


def test_stdict_fills_gap(tmp_path, monkeypatch):
    """표준 보충: 기초에 없는 표제어는 표준 것이 들어간다."""
    rows = _by_hw(_run(tmp_path, monkeypatch, [
        _n("krdict", "krdict:1", "사과"),
        _n("stdict", "stdict:1", "구름", "하늘에 뜬 것."),
    ]))
    assert rows["구름"]["senses"][0]["definition"] == "하늘에 뜬 것."
    assert rows["구름"]["source"] == config.SRC_STDICT
    assert rows["구름"]["in_krdict"] is False


def test_source_bits(tmp_path, monkeypatch):
    """`source` 비트: 기초=1, 표준=2, 양쪽=3."""
    rows = _by_hw(_run(tmp_path, monkeypatch, [
        _n("krdict", "krdict:1", "사과"),
        _n("stdict", "stdict:1", "사과"),
        _n("krdict", "krdict:2", "나무"),
        _n("stdict", "stdict:2", "구름"),
    ]))
    assert rows["사과"]["source"] == 3
    assert rows["나무"]["source"] == config.SRC_KRDICT
    assert rows["구름"]["source"] == config.SRC_STDICT


def test_senses_are_cut_to_limit(tmp_path, monkeypatch):
    """뜻풀이 개수 컷: `len(senses) <= SENSES_PER_WORD` (DESIGN 6절 용량)."""
    rows = _run(tmp_path, monkeypatch, [
        _n("krdict", f"krdict:{i}", "사과", f"뜻 {i}.") for i in range(1, 6)
    ])
    assert len(rows[0]["senses"]) == config.SENSES_PER_WORD
    assert rows[0]["senses"][0]["definition"] == "뜻 1."


def test_synonyms_are_collected_from_dropped_senses(tmp_path, monkeypatch):
    """유의어 수집: 컷으로 버려진 sense 의 유의어도 `senses[0].synonyms` 에 들어간다."""
    rows = _run(tmp_path, monkeypatch, [
        _n("krdict", "krdict:1", "사과", "뜻 1.", synonyms=[]),
        _n("krdict", "krdict:2", "사과", "뜻 2.", synonyms=["능금"]),
        _n("stdict", "stdict:1", "사과", "뜻 3.", synonyms=["林檎대용"]),
    ])
    assert rows[0]["senses"][0]["synonyms"] == ["능금", "林檎대용"]


def test_synonyms_are_deduplicated(tmp_path, monkeypatch):
    """유의어 중복 제거: 같은 유의어가 두 번 안 나온다. 순서는 첫 등장 순(재현성)."""
    rows = _run(tmp_path, monkeypatch, [
        _n("krdict", "krdict:1", "사람", "뜻 1.", synonyms=["인간", ""]),
        _n("krdict", "krdict:2", "사람", "뜻 2.", synonyms=["인간", "인류"]),
        _n("stdict", "stdict:1", "사람", "뜻 3.", synonyms=["인류"]),
    ])
    assert rows[0]["senses"][0]["synonyms"] == ["인간", "인류"]


def test_freq_join(tmp_path, monkeypatch, capsys):
    """빈도 결합: 매칭되면 `freq_rank`, 없으면 `null`. 매칭률이 로그에 찍힌다 (02-07 DoD)."""
    rows = _by_hw(_run(tmp_path, monkeypatch,
                       [_n("krdict", "krdict:1", "사과"),
                        _n("krdict", "krdict:2", "구름")],
                       freq=[{"headword": "사과", "rank": 25, "count": 7560}]))
    assert rows["사과"]["freq_rank"] == 25
    assert rows["구름"]["freq_rank"] is None
    assert re.search(r"빈도 매칭\s+1 \(50\.0%\)", capsys.readouterr().out)


def test_vocab_join(tmp_path, monkeypatch, capsys):
    """등급 결합: 매칭되면 `vocab_grade`, 없으면 `null`. 매칭률이 로그에 찍힌다 (02-07 DoD)."""
    rows = _by_hw(_run(tmp_path, monkeypatch,
                       [_n("krdict", "krdict:1", "사과"),
                        _n("krdict", "krdict:2", "구름")],
                       vocab=[{"headword": "사과", "grade": "A"}]))
    assert rows["사과"]["vocab_grade"] == "A"
    assert rows["구름"]["vocab_grade"] is None
    assert re.search(r"등급 매칭\s+1 \(50\.0%\)", capsys.readouterr().out)


def test_output_is_byte_stable(tmp_path, monkeypatch):
    """출력 순서 안정: 입력 순서를 섞어도 파일 바이트가 같아야 한다.

    `words.sqlite` 의 sha256(05-01)이 안정적이려면 여기부터 재현 가능해야 한다 (02-07).
    """
    entries = [
        _n("stdict", "stdict:2", "구름", "뜻 b.", synonyms=["운무"]),
        _n("krdict", "krdict:1", "사과", "뜻 a."),
        _n("krdict", "krdict:3", "나무", "뜻 c."),
        _n("stdict", "stdict:1", "사과", "뜻 d."),
    ]
    build = _build(tmp_path, monkeypatch, entries)
    run()
    a = (build / OUT).read_bytes()

    io_util.write_jsonl(build / IN, list(reversed(entries)))
    run()
    b = (build / OUT).read_bytes()
    assert a == b


def test_works_without_stdict(tmp_path, monkeypatch):
    """표준 파일 없음: 기초만으로 정상 동작 (02-04 가 아무 행도 안 낼 수 있다)."""
    rows = _run(tmp_path, monkeypatch, [_n("krdict", "krdict:1", "사과")])
    assert [r["source"] for r in rows] == [config.SRC_KRDICT]
    assert rows[0]["in_krdict"] is True


# --- 보조 입력 파일 자체가 없는 경로 · 경고 ---

def test_missing_freq_and_vocab_files_are_skipped(tmp_path, monkeypatch):
    """freq/vocab 파일이 아예 없어도 예외 없이 `null` 로 채운다 (02-07 결합 규칙 표)."""
    rows = _run(tmp_path, monkeypatch, [_n("krdict", "krdict:1", "사과")],
                freq=None, vocab=None)
    assert rows[0]["freq_rank"] is None and rows[0]["vocab_grade"] is None


def test_low_match_rate_is_warned(tmp_path, monkeypatch, capsys):
    """매칭률이 02-07 "막히면" 의 기준(빈도 30% · 등급 5%)을 밑돌면 경고를 찍는다."""
    _run(tmp_path, monkeypatch,
         [_n("krdict", f"krdict:{i}", f"사과{'나' * i}") for i in range(1, 5)],
         freq=[], vocab=[])
    out = capsys.readouterr().out
    assert "빈도 매칭률 30% 미만" in out
    assert "등급 매칭률 5% 미만" in out


# --- 픽스처 end-to-end (README "결합 실적 (02-07)" 표의 근거) ---

@pytest.fixture
def fixture_run(tmp_path, monkeypatch, capsys):
    """02-03~02-06 을 픽스처로 전부 돌린 뒤 merge 를 태운다. `(행 목록, 로그)`."""
    monkeypatch.setattr(config, "BUILD", tmp_path / "build")
    for step in (parse_krdict, parse_stdict, parse_freq, parse_vocab, normalize):
        step.run(use_fixtures=True)
    n = run(use_fixtures=True)
    rows = list(io_util.read_jsonl(config.BUILD / OUT))
    assert n == len(rows)
    return rows, capsys.readouterr().out


def test_fixture_end_to_end(fixture_run):
    """샘플 normalized 20행 -> 16 표제어 (`사람`·`나무` 가 양쪽, `사과` 가 동음이의어)."""
    rows, log = fixture_run
    assert len(rows) == 16
    assert [r["headword"] for r in rows] == sorted(r["headword"] for r in rows)
    assert re.search(r"merge: 16 words", log)
    assert re.search(r"기초사전만 6 / 표준만 8 / 양쪽 2", log)

    by = _by_hw(rows)
    assert by["사람"]["source"] == 3
    assert by["사람"]["senses"][0]["synonyms"] == ["인간"]
    assert by["사과"]["senses"][0]["definition"] == "둥글고 붉으며 단맛이 나는 과일."
    assert by["사과"]["freq_rank"] == 25 and by["사과"]["vocab_grade"] == "A"
    assert by["심근경색"]["freq_rank"] is None
