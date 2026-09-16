"""02-04 표준국어대사전 파서 테스트. 픽스처: tools/fixtures/stdict/stdict_sample.xml

샘플은 손수 만든 것이며 실데이터가 아니다 (00-01 승인 대기, tools/README.md 참조).
"""
import json
import xml.etree.ElementTree as ET

import pytest

from tools import config, io_util
from tools import parse_krdict
from tools.parse_stdict import OUT, iter_entries, run

# 픽스처가 일부러 심어 둔 라이선스 비개방 텍스트 (예문)
SAMPLE_EXAMPLES = [
    "가게 주인이 손님을 맞았다.",
    "책상 위에 책이 놓여 있다.",
]

ALLOWED_KEYS = {
    "source", "sense_id", "raw_headword", "homonym",
    "pos", "word_type", "definition", "synonyms",
}

FIXTURE = config.FIXTURES / "stdict" / "stdict_sample.xml"


def _run_fixture(tmp_path, monkeypatch) -> list[dict]:
    monkeypatch.setattr(config, "BUILD", tmp_path)
    n = run(use_fixtures=True)
    rows = list(io_util.read_jsonl(tmp_path / OUT))
    assert n == len(rows)
    return rows


@pytest.fixture
def rows(tmp_path, monkeypatch):
    return _run_fixture(tmp_path, monkeypatch)


def _headwords(rows) -> set[str]:
    return {r["raw_headword"] for r in rows}


def test_schema_matches_krdict(rows, tmp_path, monkeypatch):
    """02-03과 같은 키 집합이어야 한다 (02-07 merge 가 두 파일을 같은 모양으로 읽는다)."""
    monkeypatch.setattr(config, "BUILD", tmp_path)
    parse_krdict.run(use_fixtures=True)
    krdict_rows = list(io_util.read_jsonl(tmp_path / parse_krdict.OUT))

    assert krdict_rows and rows
    assert {frozenset(r) for r in rows} == {frozenset(r) for r in krdict_rows}
    for r in rows:
        assert set(r) == ALLOWED_KEYS
        assert r["source"] == "stdict"
        assert isinstance(r["synonyms"], list)
        for k in ("sense_id", "raw_headword", "pos", "definition"):
            assert r[k], f"{k} 누락: {r}"


def test_sense_id_prefixed(rows):
    assert all(r["sense_id"].startswith("stdict:") for r in rows)


def test_sense_id_unique(rows):
    ids = [r["sense_id"] for r in rows]
    assert len(ids) == len(set(ids))


def test_excludes_dialect(rows):
    # 정구지·가시개: word_type=방언 + dialect_info
    assert _headwords(rows).isdisjoint({"정구지", "가시개"})
    assert "방언" not in "".join(r["definition"] for r in rows)


def test_excludes_old_and_north_korean(rows):
    # 즈믄·온뫼(옛말), 인민배우·날바라지(북한어)
    assert _headwords(rows).isdisjoint({"즈믄", "온뫼", "인민배우", "날바라지"})


def test_excludes_phrases(rows):
    # word_unit in {구, 속담, 관용구}
    assert _headwords(rows).isdisjoint(
        {"가게^주인", "발^없는^말이^천^리^간다", "손이^크다"})
    assert all(r["word_type"] not in {"구", "속담", "관용구"} for r in rows)


def test_keeps_technical_terms(rows):
    """전문어는 아직 거르지 않는다 — 02-04 "막히면"(처음부터 세게 걸지 말 것)."""
    assert {"심근경색", "미분방정식"} <= _headwords(rows)


def test_raw_headword_kept_verbatim(rows):
    """`^`·`-`·동형어 번호를 파서가 손대지 않는다. 판정은 02-06."""
    src = {
        (w.findtext("word") or "").strip()
        for w in ET.parse(FIXTURE).getroot().iterfind("item/word_info")
    }
    assert _headwords(rows) <= src, "출력 표제어가 원문에 없는 형태로 바뀌었다"
    assert "-님" in _headwords(rows), "접사 하이픈이 사라졌다"
    assert "나무01" in _headwords(rows), "동형어 번호가 사라졌다"


def test_skips_empty_definition(rows):
    # 구름: sense 2개 중 하나가 빈 definition -> 그 sense 만 버린다
    got = [r for r in rows if r["raw_headword"] == "구름"]
    assert [r["sense_id"] for r in got] == ["stdict:98786"]
    assert all(r["definition"] for r in rows)


def test_polysemous_item_yields_multiple_rows(rows):
    got = [r for r in rows if r["raw_headword"] == "나무01"]
    assert len(got) == 2
    assert all(r["homonym"] == "01" for r in got)


def test_drop_counts_are_logged(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(config, "BUILD", tmp_path)
    n = run(use_fixtures=True)
    out = capsys.readouterr().out
    assert "stdict:" in out
    for key in ("total", "kept", "drop_dialect", "drop_old",
                "drop_technical", "drop_phrase"):
        assert key in out, f"제외 개수 로그에 {key} 없음"
    stats = json.loads(out.split("stdict:", 1)[1].strip().replace("'", '"'))
    assert stats["total"] == 20
    assert stats["kept"] == n
    assert (stats["drop_dialect"], stats["drop_old"],
            stats["drop_technical"], stats["drop_phrase"]) == (2, 4, 0, 3)


def test_excludes_examples(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "BUILD", tmp_path)
    run(use_fixtures=True)
    text = (tmp_path / OUT).read_text(encoding="utf-8")
    for ex in SAMPLE_EXAMPLES:
        assert ex not in text, f"예문이 섞임: {ex}"
    assert "example" not in text


def test_excludes_licensed_media(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "BUILD", tmp_path)
    run(use_fixtures=True)
    text = (tmp_path / OUT).read_text(encoding="utf-8")
    for banned in [".mp3", ".wav", ".jpg", ".png", "http://", "https://"]:
        assert banned not in text, f"라이선스 비개방 자료가 섞임: {banned}"


def test_missing_source_writes_empty_file(tmp_path, monkeypatch):
    """표준은 보충 자료다. 원본 0개여도 예외 없이 빈 jsonl 을 낸다 (02-04 DoD)."""
    empty = tmp_path / "raw"
    empty.mkdir()
    monkeypatch.setattr(config, "RAW", empty)
    monkeypatch.setattr(config, "BUILD", tmp_path / "build")
    assert run(use_fixtures=False) == 0
    assert (tmp_path / "build" / OUT).read_text(encoding="utf-8") == ""


def test_iter_entries_streams_lazily():
    """전체 로드 금지. 첫 행이 파일을 다 읽기 전에 나와야 한다."""
    stats = {"total": 0, "kept": 0, "drop_dialect": 0, "drop_old": 0,
             "drop_technical": 0, "drop_phrase": 0}
    gen = iter_entries(FIXTURE, stats)
    first = next(gen)
    assert first["source"] == "stdict"
    assert stats["total"] < 20, "첫 행 시점에 파일 전체를 읽었다"
    gen.close()


def test_output_is_valid_jsonl_utf8(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "BUILD", tmp_path)
    run(use_fixtures=True)
    lines = (tmp_path / OUT).read_text(encoding="utf-8").splitlines()
    assert lines and all(json.loads(line) for line in lines)
    assert "강아지" in "\n".join(lines), "한글이 이스케이프되면 안 된다"
