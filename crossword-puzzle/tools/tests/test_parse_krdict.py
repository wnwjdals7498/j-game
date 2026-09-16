"""02-03 기초사전 파서 테스트. 픽스처: tools/fixtures/krdict/krdict_sample.xml

샘플은 손수 만든 것이며 실데이터가 아니다 (00-01 승인 대기, tools/README.md 참조).
"""
import json

import pytest

from tools import config, io_util
from tools.parse_krdict import OUT, run

# 픽스처가 일부러 심어 둔 라이선스 비개방 텍스트 (예문)
SAMPLE_EXAMPLES = [
    "동생이 학교에 간다.",
    "결혼식에 가다.",
    "사람은 누구나 실수를 한다.",
]

ALLOWED_KEYS = {
    "source", "sense_id", "raw_headword", "homonym",
    "pos", "word_type", "definition", "synonyms",
}


def _run_fixture(tmp_path, monkeypatch) -> list[dict]:
    monkeypatch.setattr(config, "BUILD", tmp_path)
    n = run(use_fixtures=True)
    rows = list(io_util.read_jsonl(tmp_path / OUT))
    assert n == len(rows)
    return rows


@pytest.fixture
def rows(tmp_path, monkeypatch):
    return _run_fixture(tmp_path, monkeypatch)


def test_parses_every_sense(rows):
    # 샘플 20항목 중 19개가 표제어를 가지고, 그중 '가다01' 만 뜻풀이 2개 -> 20행
    assert len(rows) == 20


def test_required_fields_present(rows):
    for r in rows:
        for k in ("source", "sense_id", "raw_headword", "pos", "definition"):
            assert r.get(k), f"{k} 누락: {r}"
        assert r["source"] == "krdict"
        assert set(r) <= ALLOWED_KEYS, f"스키마에 없는 키: {set(r) - ALLOWED_KEYS}"


def test_sense_id_unique(rows):
    ids = [r["sense_id"] for r in rows]
    assert len(ids) == len(set(ids))


def test_sense_id_prefixed(rows):
    assert all(r["sense_id"].startswith("krdict:") for r in rows)


def test_polysemous_item_yields_multiple_rows(rows):
    got = [r for r in rows if r["raw_headword"] == "가다01"]
    assert len(got) == 2
    assert {r["definition"] for r in got} == {
        "한 곳에서 다른 곳으로 장소를 이동하다.",
        "일정한 목적을 위하여 어디에 참석하다.",
    }
    assert all(r["homonym"] == "01" for r in got)


def test_synonyms_list_only_similar_words(rows):
    by_id = {r["sense_id"]: r for r in rows}
    # 비슷한말만 뽑고 반대말('오다')은 버린다
    assert by_id["krdict:12345"]["synonyms"] == ["이동하다", "향하다"]
    # rel_info 자체가 없는 항목은 빈 리스트
    assert by_id["krdict:20002"]["synonyms"] == []
    assert all(isinstance(r["synonyms"], list) for r in rows)


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


def test_skips_empty_headword(rows):
    assert all(r["raw_headword"] for r in rows)
    # 빈 표제어 항목의 sense_code 20018 은 행을 내지 않는다
    assert "krdict:20018" not in {r["sense_id"] for r in rows}


def test_missing_source_raises(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "RAW", tmp_path)
    with pytest.raises(FileNotFoundError):
        run(use_fixtures=False)


def test_output_is_valid_jsonl_utf8(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "BUILD", tmp_path)
    run(use_fixtures=True)
    lines = (tmp_path / OUT).read_text(encoding="utf-8").splitlines()
    assert lines and all(json.loads(line) for line in lines)
    assert "사람" in "\n".join(lines), "한글이 이스케이프되면 안 된다"
