"""02-06 표제어 정규화·필터 테스트.

규칙이 많아 케이스별로 쓰면 놓친다 — 02-06 "테스트" 절대로 **표 기반**으로 쓴다.
입력은 02-03/02-04 가 픽스처로 만든 build/entries.*.jsonl 이며 실데이터가 아니다
(00-01 승인 대기, tools/README.md 참조).
"""
import json
import re
import unicodedata

import pytest

from tools import config, io_util, parse_krdict, parse_stdict
from tools.normalize import OUT, check, normalize_headword, run

SCHEMA_KEYS = {"source", "sense_id", "headword", "raw_headword", "len",
               "syllables", "pos", "definition", "synonyms"}


def _entry(raw, pos="명사", wtype="단어", **kw) -> dict:
    e = {"source": "krdict", "sense_id": f"krdict:{raw}", "raw_headword": raw,
         "homonym": None, "pos": pos, "word_type": wtype,
         "definition": "뜻풀이.", "synonyms": []}
    e.update(kw)
    return e


def _run(tmp_path, monkeypatch, krdict=None, stdict=None) -> list[dict]:
    """entries.*.jsonl 을 tmp BUILD 에 깔고 run() 을 끝까지 태운다. None 이면 파일을 안 만든다."""
    build = tmp_path / "build"
    build.mkdir(parents=True, exist_ok=True)
    monkeypatch.setattr(config, "BUILD", build)
    if krdict is not None:
        io_util.write_jsonl(build / "entries.krdict.jsonl", krdict)
    if stdict is not None:
        io_util.write_jsonl(build / "entries.stdict.jsonl", stdict)
    n = run(use_fixtures=True)
    rows = list(io_util.read_jsonl(build / OUT))
    assert n == len(rows)
    return rows


def _log_counts(out: str) -> dict:
    """로그에서 입력·통과·사유별 개수를 되읽는다. 로그가 02-06 DoD 의 산출물이다."""
    head = re.search(r"입력 ([\d,]+) → 통과 ([\d,]+)", out)
    assert head, out
    counts = {k: int(v.replace(",", ""))
              for k, v in zip(("in", "out"), head.groups())}
    for code in ("F1", "F2", "F3", "F4", "F5"):
        m = re.search(rf"^\s+{code} \S+\s+([\d,]+)$", out, re.M)
        assert m, f"{code} 줄 없음:\n{out}"
        counts[code] = int(m.group(1).replace(",", ""))
    return counts


# --- 1. 정규화 (02-06 표 기반 테스트, 7 케이스) ---

@pytest.mark.parametrize("raw,expected", [
    ("가다01", "가다"),
    ("사과02", "사과"),
    ("가다", "가다"),
    ("  사과  ", "사과"),
    ("가다¹", "가다"),
    ("-이다", "-이다"),         # 하이픈은 안 고친다 (F1에서 탈락)
    ("가게 주인", "가게 주인"),  # 공백도 안 고친다 (F1에서 탈락)
])
def test_normalize_headword(raw, expected):
    assert normalize_headword(raw) == expected


def test_nfc_normalization():
    """조합형(NFD)으로 온 표제어는 완성형(NFC)으로 고친다."""
    nfd = unicodedata.normalize("NFD", "사과")
    assert nfd != "사과" and len(nfd) == 4
    assert normalize_headword(nfd) == "사과"


# --- 2. 필터 (02-06 표 기반 테스트, 13 케이스) ---

@pytest.mark.parametrize("hw,pos,wtype,why", [
    ("사과",         "명사",     "일반어", None),
    ("사과나무",     "명사",     "일반어", None),
    ("가나다라마",   "명사",     "일반어", None),      # 5음절 통과
    ("달",           "명사",     "일반어", "F2"),      # 1음절
    ("가나다라마바", "명사",     "일반어", "F2"),      # 6음절
    ("PC방",         "명사",     "일반어", "F1"),
    ("MP3",          "명사",     "일반어", "F1"),
    ("-이다",        "명사",     "일반어", "F1"),
    ("가게 주인",    "명사",     "일반어", "F1"),
    ("가게^주인",    "명사",     "일반어", "F1"),
    ("사과",         "동사",     "일반어", "F3"),
    ("사과",         "명사",     "속담",   "F4"),
    ("서울",         "고유명사", "일반어", "F5"),
])
def test_filter(hw, pos, wtype, why):
    e = {"headword": hw, "pos": pos, "word_type": wtype}
    assert check(e) == why


def test_f1_runs_before_f2():
    """비한글이 섞이면 길이 개념이 무의미하다 — F1 이 먼저다 (02-06)."""
    assert check({"headword": "P", "pos": "명사", "word_type": "단어"}) == "F1"


# --- 3. run() 전체 ---

@pytest.fixture
def fixture_run(tmp_path, monkeypatch, capsys):
    """02-03/02-04 파서를 픽스처로 돌려 만든 entries.*.jsonl 을 입력으로 쓴다 (end-to-end).

    `(행 목록, 로그)` 를 돌려준다 — 픽스처 단계의 stdout 은 테스트 본문의 capsys 에 남지 않는다.
    """
    build = tmp_path / "build"
    monkeypatch.setattr(config, "BUILD", build)
    parse_krdict.run(use_fixtures=True)
    parse_stdict.run(use_fixtures=True)
    n = run(use_fixtures=True)
    rows = list(io_util.read_jsonl(build / OUT))
    assert n == len(rows)
    return rows, capsys.readouterr().out


@pytest.fixture
def fixture_rows(fixture_run):
    return fixture_run[0]


def test_fixture_end_to_end_counts(fixture_run):
    """샘플 32행(기초 20 + 표준 12) -> 20행. tools/README.md "정규화 실적 (02-06)" 표의 근거."""
    rows, log = fixture_run
    assert len(rows) == 20
    assert _log_counts(log) == {
        "in": 32, "out": 20, "F1": 5, "F2": 2, "F3": 5, "F4": 0, "F5": 0}


def test_output_schema(fixture_rows):
    for r in fixture_rows:
        assert set(r) == SCHEMA_KEYS
        assert r["len"] == len(r["headword"])
        assert r["syllables"] == list(r["headword"])
        assert len(r["syllables"]) == r["len"]
        assert config.MIN_LEN <= r["len"] <= config.MAX_LEN
        assert r["pos"] in config.ALLOWED_POS


def test_raw_headword_is_kept(fixture_rows):
    """`headword` 는 정규화 결과, `raw_headword` 는 추적용 원문 (02-06)."""
    got = {r["raw_headword"]: r["headword"] for r in fixture_rows}
    assert got["사과01"] == "사과"
    assert got["사과02"] == "사과"
    assert got["나무01"] == "나무"


def test_stats_add_up(tmp_path, monkeypatch, capsys):
    """사유별 개수 합 + 통과 수 == 입력 수 (02-06 DoD "사유별 탈락 개수 로그 출력")."""
    _run(tmp_path, monkeypatch, krdict=[
        _entry("사과02"),                       # 통과
        _entry("PC방"),                         # F1
        _entry("물"),                           # F2
        _entry("예쁘다", pos="형용사"),         # F3
        _entry("사과", wtype="속담"),           # F4
        _entry("서울", pos="고유명사"),         # F5
    ])
    c = _log_counts(capsys.readouterr().out)
    assert c == {"in": 6, "out": 1, "F1": 1, "F2": 1, "F3": 1, "F4": 1, "F5": 1}
    assert c["out"] + sum(c[k] for k in ("F1", "F2", "F3", "F4", "F5")) == c["in"]


def test_missing_input_file_is_skipped(tmp_path, monkeypatch, capsys):
    """02-04 가 표준 파일을 아예 안 낼 수 있다. 예외 없이 건너뛴다."""
    rows = _run(tmp_path, monkeypatch, krdict=[_entry("사과02")], stdict=None)
    assert [r["headword"] for r in rows] == ["사과"]
    assert _log_counts(capsys.readouterr().out)["in"] == 1


def test_both_sources_are_read(tmp_path, monkeypatch):
    rows = _run(tmp_path, monkeypatch,
                krdict=[_entry("사과02")],
                stdict=[_entry("구름", source="stdict", sense_id="stdict:1")])
    assert {r["source"] for r in rows} == {"krdict", "stdict"}


def test_empty_input_files(tmp_path, monkeypatch):
    assert _run(tmp_path, monkeypatch, krdict=[], stdict=[]) == []


def test_proper_noun_without_basis_is_warned(tmp_path, monkeypatch, capsys):
    """F5 판정 근거가 입력에 없으면 조용히 넘어가지 않고 로그에 남긴다 (02-06 "고유명사 판정").

    02-03 출력 스키마의 `word_type` 은 원본 `word_unit`(단어/구/...) 에서 오고,
    샘플에서 고유명사 표시는 원본 `word_type` 에 있다 - 실어 나를 자리가 없다.
    그래서 `대한민국` 이 통과한다. tools/README.md "미해결" 참조.
    """
    rows = _run(tmp_path, monkeypatch,
                krdict=[_entry("대한민국", pos="명사", wtype="단어")])
    assert [r["headword"] for r in rows] == ["대한민국"]
    out = capsys.readouterr().out
    assert _log_counts(out)["F5"] == 0
    assert "F5 경고" in out


def test_output_is_valid_jsonl_utf8(fixture_rows, tmp_path):
    lines = (tmp_path / "build" / OUT).read_text(encoding="utf-8").splitlines()
    assert lines and all(json.loads(line) for line in lines)
    assert "김치찌개" in "\n".join(lines), "한글이 이스케이프되면 안 된다"
