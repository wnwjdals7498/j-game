"""02-03 기초사전 파서 테스트. 픽스처: tools/fixtures/krdict/krdict_sample.json

02-01 재조사(2026-09-17)로 원본이 XML 이 아니라 JSON(LMF att/val) 임이 확인되어
픽스처와 파서를 함께 갈아엎었다. 샘플은 손수 만든 것이며 실데이터가 아니다
(tools/README.md "실제 파일 구조 조사 결과" 참조).
"""
import json

import pytest

from tools import config, io_util
from tools.parse_krdict import OUT, run

# 픽스처가 일부러 심어 둔 라이선스 비개방 텍스트 (예문)
SAMPLE_EXAMPLES = [
    "동생이 학교에 간다.",
    "결혼식에 가다.",
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


def _by_headword(rows) -> dict:
    out: dict[str, list] = {}
    for r in rows:
        out.setdefault(r["raw_headword"], []).append(r)
    return out


def test_parses_every_sense(rows):
    # 픽스처 21항목 중 20개가 표제어를 갖고(1개는 표제어가 빈 방어 케이스),
    # '가다01' 만 뜻풀이 2개라 19*1 + 1*2 = 21행.
    assert len(rows) == 21


def test_required_fields_present(rows):
    for r in rows:
        for k in ("source", "sense_id", "raw_headword", "definition"):
            assert r.get(k), f"{k} 누락: {r}"
        assert r["source"] == "krdict"
        assert set(r) <= ALLOWED_KEYS, f"스키마에 없는 키: {set(r) - ALLOWED_KEYS}"
        assert isinstance(r["synonyms"], list)


def test_sense_id_unique(rows):
    ids = [r["sense_id"] for r in rows]
    assert len(ids) == len(set(ids))


def test_sense_id_prefixed(rows):
    assert all(r["sense_id"].startswith("krdict:") for r in rows)


def test_polysemous_item_yields_multiple_rows(rows):
    got = _by_headword(rows)["가다01"]
    assert len(got) == 2
    assert {r["definition"] for r in got} == {
        "한 곳에서 다른 곳으로 장소를 이동하다.",
        "일정한 목적을 위하여 어디에 참석하다.",
    }
    assert all(r["homonym"] == "1" for r in got)


def test_homonym_number_zero_means_none(rows):
    """homonym_number 값 '0'은 "동형어 없음" 이다(별도 필드 부재가 아니라 값이 '0') -- 02-01."""
    got = _by_headword(rows)["사람"][0]
    assert got["homonym"] is None


def test_synonyms_list_only_similar_words(rows):
    """유의어 관계 유형의 실제 값은 '비슷한말'이 아니라 '유의어'다(02-01 재조사).
    반대말·참고어는 유의어로 치지 않는다.
    """
    got = _by_headword(rows)["가다01"]
    with_syns = next(r for r in got if r["synonyms"])
    assert with_syns["synonyms"] == ["이동하다", "향하다"]
    # 유의어 관계 자체가 없는 항목은 빈 리스트
    assert _by_headword(rows)["나무"][0]["synonyms"] == []


def test_sense_feat_as_list_still_parses_definition(rows):
    """실데이터에서 Sense.feat 는 dict 하나(정의만)이거나 list(구문 패턴+정의)로 온다.
    '사과02' 픽스처가 list 케이스를 재현한다 -- definition 을 정확히 골라내야 한다.
    """
    got = _by_headword(rows)["사과02"][0]
    assert got["definition"] == "잘못에 대하여 용서를 빎."


def test_lemma_as_list_uses_first_written_form(rows):
    """Lemma 가 list(변이형)면 첫 원소의 writtenForm 만 표제어로 쓴다 -- 실데이터
    '체스'/variant='케스, 셰스' 패턴(02-01)."""
    assert "돈가스" in _by_headword(rows)
    assert "돈까스" not in _by_headword(rows)


def test_entry_val_collision_gets_unique_sense_id(rows):
    """관용구가 원어의 entry.val 을 재사용하는 실데이터 버그(02-01)의 회귀 케이스.
    '나무'(val=20002)와 '나무를 심다'(관용구, val=20002 재사용)가 같은 파일에 있어도
    sense_id 가 갈라져야 한다.
    """
    namu = _by_headword(rows)["나무"][0]
    idiom = _by_headword(rows)["나무를 심다"][0]
    assert namu["sense_id"] != idiom["sense_id"]
    assert namu["sense_id"] == "krdict:20002-1"
    assert idiom["sense_id"] == "krdict:20002+1-1"


def test_grammar_pattern_word_type_is_not_filtered_here(rows):
    """"문법‧표현"(가운뎃점 U+2027)은 파서 단계에서 거르지 않는다 -- F4 필터(02-06)가 한다.
    파서는 lexicalUnit 값을 그대로 word_type 에 옮겨야 한다.
    """
    got = _by_headword(rows)["다고"][0]
    assert got["word_type"] == "문법‧표현"


def test_idiom_without_optional_feats_has_empty_pos(rows):
    """관용구/속담 항목은 homonym_number/partOfSpeech/vocabularyLevel 자체가 없다(02-01
    전수 조사: lexicalUnit != '단어' 인 2,884건 전부). pos 는 빈 문자열이 된다."""
    got = _by_headword(rows)["나무를 심다"][0]
    assert got["pos"] == ""
    assert got["homonym"] is None


def test_excludes_examples(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "BUILD", tmp_path)
    run(use_fixtures=True)
    text = (tmp_path / OUT).read_text(encoding="utf-8")
    for ex in SAMPLE_EXAMPLES:
        assert ex not in text, f"예문이 섞임: {ex}"


def test_excludes_licensed_media(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "BUILD", tmp_path)
    run(use_fixtures=True)
    text = (tmp_path / OUT).read_text(encoding="utf-8")
    for banned in [".wav", ".jpg", ".png", "http://", "https://", "dicmedia"]:
        assert banned not in text, f"라이선스 비개방 자료가 섞임: {banned}"


def test_skips_empty_headword(rows):
    assert all(r["raw_headword"] for r in rows)
    assert "" not in _by_headword(rows)


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
