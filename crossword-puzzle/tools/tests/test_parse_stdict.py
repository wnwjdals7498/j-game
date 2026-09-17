"""02-04 표준국어대사전 파서 테스트. 픽스처: tools/fixtures/stdict/stdict_sample.json

02-01 재조사(2026-09-17)로 원본이 XML 이 아니라 평평한 JSON(`channel.item[]`) 임이
확인되어 픽스처와 파서를 함께 갈아엎었다. 샘플은 손수 만든 것이며 실데이터가 아니다
(tools/README.md 참조).

02-01 재조사로 방언/옛말/북한어 판정 필드가 실데이터에 없음이 확인되어(전수 스캔
436,587건) 02-04 의 해당 필터를 제거했다 — 이 테스트 파일에는 그 필터 테스트가 없다.
"""
import json

import pytest

from tools import config, io_util
from tools import parse_krdict
from tools.parse_stdict import OUT, iter_entries, run

# 픽스처가 일부러 심어 둔 라이선스 비개방 텍스트 (예문)
SAMPLE_EXAMPLES = [
    "가게 주인이 손님을 맞았다.",
]

ALLOWED_KEYS = {
    "source", "sense_id", "raw_headword", "homonym",
    "pos", "word_type", "definition", "synonyms",
}

FIXTURE = config.FIXTURES / "stdict" / "stdict_sample.json"


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


def _by_headword(rows) -> dict:
    out: dict[str, list] = {}
    for r in rows:
        out.setdefault(r["raw_headword"], []).append(r)
    return out


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


def test_excludes_phrases(rows):
    """word_unit in {구, 속담, 관용구}. 02-01 재조사로 방언/옛말/북한어 필터는 제거됐다
    (실데이터에 판정 근거가 없음, tools/README.md 참조)."""
    assert _headwords(rows).isdisjoint(
        {"가게^주인", "발^없는^말이^천^리^간다", "손이^크다"})
    assert all(r["word_type"] not in {"구", "속담", "관용구"} for r in rows)


def test_keeps_technical_terms(rows):
    """전문어는 아직 거르지 않는다 — 02-04 "막히면"(처음부터 세게 걸지 말 것)."""
    assert {"심근경색", "미분방정식"} <= _headwords(rows)


def test_raw_headword_kept_verbatim(rows):
    """`^`·`-`·동형어 번호를 파서가 손대지 않는다. 판정은 02-06."""
    src = {
        item["word_info"]["word"]
        for item in json.loads(FIXTURE.read_text(encoding="utf-8"))["channel"]["item"]
    }
    assert _headwords(rows) <= src, "출력 표제어가 원문에 없는 형태로 바뀌었다"
    assert "-님" in _headwords(rows), "접사 하이픈이 사라졌다"
    assert "나무01" in _headwords(rows), "동형어 번호가 사라졌다"


def test_homonym_extracted_from_word_suffix(rows):
    """실데이터에는 동형어 번호 전용 필드가 없다(전수 스캔 436,587건 중 0건) — word 문자열
    끝의 숫자(항상 2자리)에서만 뽑아낸다(02-01)."""
    got = _by_headword(rows)["나무01"][0]
    assert got["homonym"] == "01"
    assert _by_headword(rows)["책상"][0]["homonym"] is None


def test_skips_empty_definition(rows):
    # 구름: sense 2개 중 하나가 빈 definition -> 그 sense 만 버린다
    got = [r for r in rows if r["raw_headword"] == "구름"]
    assert len(got) == 1
    assert got[0]["definition"]


def test_polysemous_item_yields_multiple_rows(rows):
    got = _by_headword(rows)["나무01"]
    assert len(got) == 2
    assert all(r["homonym"] == "01" for r in got)


def test_multi_pos_info_uses_matching_pos_per_sense(rows):
    """실데이터에는 품사가 둘 이상인 표제어가 있다(pos_info 가 여러 개, 약 3천 건).
    각 sense 는 자기 pos_info 의 pos 를 써야 한다 — 첫 pos_info 하나로 전부 라벨링하면
    틀린다(02-01에서 발견, 02-04 골격의 버그)."""
    got = {r["pos"]: r for r in rows if r["raw_headword"] == "가늘다01"}
    assert set(got) == {"형용사", "보조 형용사"}
    assert got["형용사"]["definition"] == "물체의 굵기가 얇거나 작다."
    assert got["보조 형용사"]["definition"] == "앞말이 뜻하는 정도가 약함을 나타내는 말."


def test_synonyms_accept_synonym_and_similar_word_types(rows):
    """실데이터 관계 유형 분포는 동의어(다수) > 비슷한말 > 반대말 > ... > 참고 어휘 순이다
    (02-01). 동의어·비슷한말 둘 다 유의어로 인정하고 반대말·참고 어휘는 제외한다."""
    got = _by_headword(rows)["각본02"][0]
    assert got["synonyms"] == ["대본", "시나리오"]


def test_missing_sense_code_is_skipped(rows):
    """sense_code 가 없는 sense 는 방어적으로 스킵한다(실데이터 0건이지만 방어 경로 유지)."""
    got = _by_headword(rows)["깨진표제"]
    assert len(got) == 1
    assert got[0]["definition"] == "정상 뜻풀이."


def test_drop_counts_are_logged(tmp_path, monkeypatch, capsys):
    monkeypatch.setattr(config, "BUILD", tmp_path)
    n = run(use_fixtures=True)
    out = capsys.readouterr().out
    assert "stdict:" in out
    for key in ("total", "kept", "drop_phrase", "drop_technical"):
        assert key in out, f"제외 개수 로그에 {key} 없음"
    stats = json.loads(out.split("stdict:", 1)[1].strip().replace("'", '"'))
    assert stats["total"] == 18
    assert stats["kept"] == n
    assert stats["drop_phrase"] == 3
    assert stats["drop_technical"] == 0


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
    for banned in [".jpg", ".png", "http://", "https://", "dicmedia"]:
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
    """json.load 는 파일 하나를 통째로 읽지만(02-01: 파일당 최대 ~10MB 라 스트리밍
    불필요), 그 뒤 항목별 처리는 제너레이터라 첫 행이 파일의 모든 항목을 순회하기 전에
    나와야 한다."""
    stats = {"total": 0, "kept": 0, "drop_phrase": 0, "drop_technical": 0}
    gen = iter_entries(FIXTURE, stats)
    first = next(gen)
    assert first["source"] == "stdict"
    assert stats["total"] < 18, "첫 행 시점에 파일 전체 항목을 순회했다"
    gen.close()


def test_output_is_valid_jsonl_utf8(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "BUILD", tmp_path)
    run(use_fixtures=True)
    lines = (tmp_path / OUT).read_text(encoding="utf-8").splitlines()
    assert lines and all(json.loads(line) for line in lines)
    assert "강아지" in "\n".join(lines), "한글이 이스케이프되면 안 된다"
