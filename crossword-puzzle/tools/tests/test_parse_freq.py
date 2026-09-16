"""02-05 빈도 파서 테스트. 픽스처: tools/fixtures/freq_sample.csv

샘플은 손수 만든 것이며 실데이터가 아니다 (00-01 승인 대기, tools/README.md 참조).
"""
import json

import pytest

from tools import config, io_util
from tools.parse_freq import OUT, _to_int, run

ALLOWED_KEYS = {"headword", "rank", "count"}

FIXTURE = config.FIXTURES / "freq_sample.csv"


def _run(tmp_path, monkeypatch, src=None) -> list[dict]:
    """src 를 주면 그 폴더를 픽스처로 쓴다 (인코딩 테스트용)."""
    if src is not None:
        monkeypatch.setattr(config, "FIXTURES", src)
    monkeypatch.setattr(config, "BUILD", tmp_path / "build")
    n = run(use_fixtures=True)
    rows = list(io_util.read_jsonl(tmp_path / "build" / OUT))
    assert n == len(rows)
    return rows


def _write(path, text, encoding="utf-8"):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(text.encode(encoding))


@pytest.fixture
def rows(tmp_path, monkeypatch):
    return _run(tmp_path, monkeypatch)


def _by_word(rows) -> dict[str, dict]:
    return {r["headword"]: r for r in rows}


def test_basic_parse_row_count(rows):
    """샘플 100행 중 `사람` 이 2번(명사/의존명사) 나오므로 99개 표제어."""
    assert len(rows) == 99
    assert len(_by_word(rows)) == 99


def test_schema(rows):
    for r in rows:
        assert set(r) == ALLOWED_KEYS
        assert r["headword"].strip() == r["headword"] and r["headword"]
        assert isinstance(r["rank"], int) and r["rank"] >= 1
        assert isinstance(r["count"], int)


def test_thousands_separator(rows):
    """`"62,384"` -> 62384 (샘플 100행 중 10행이 천단위 구분자)."""
    assert _by_word(rows)["사람"]["count"] == 62384
    assert _to_int("1,234") == 1234
    assert _to_int("") is None and _to_int(None) is None and _to_int("없음") is None


def test_duplicate_headword_keeps_best_rank(rows):
    """`사람` 은 순위 1(명사)·100(의존명사). 작은 rank 만 남는다 (DESIGN 4절 PK)."""
    got = [r for r in rows if r["headword"] == "사람"]
    assert len(got) == 1
    assert got[0]["rank"] == 1
    assert got[0]["count"] == 62384


def test_uses_rank_column_when_present(rows):
    by = _by_word(rows)
    assert by["나무"]["rank"] == 21
    assert by["예쁘다"]["rank"] == 99


def test_assigns_rank_when_column_missing(tmp_path, monkeypatch):
    """순위 컬럼이 없으면 count 내림차순으로 1부터 부여한다."""
    src = tmp_path / "src"
    _write(src / "freq.csv", "어휘,빈도\n나무,10\n사람,30\n하늘,20\n")
    rows = _run(tmp_path, monkeypatch, src)
    assert {r["headword"]: r["rank"] for r in rows} == {"사람": 1, "하늘": 2, "나무": 3}
    assert min(r["rank"] for r in rows) == 1


def test_ties_get_same_rank(tmp_path, monkeypatch):
    """동률은 같은 순위. 그 뒤 rank 가 건너뛰어도 무방하다 (02-08은 정규화만)."""
    src = tmp_path / "src"
    _write(src / "freq.csv", "어휘,빈도\n가,30\n나,20\n다,20\n라,10\n")
    ranks = {r["headword"]: r["rank"] for r in _run(tmp_path, monkeypatch, src)}
    assert ranks["나"] == ranks["다"] == 2
    assert ranks == {"가": 1, "나": 2, "다": 2, "라": 4}


def test_reads_cp949(tmp_path, monkeypatch, capsys):
    """국립국어원 csv 는 CP949 인 경우가 많다 (02-05 "인코딩")."""
    src = tmp_path / "src"
    _write(src / "freq.csv", "순위,어휘,빈도\n1,사람,999\n", encoding="cp949")
    rows = _run(tmp_path, monkeypatch, src)
    assert rows == [{"headword": "사람", "rank": 1, "count": 999}]
    assert "인코딩=cp949" in capsys.readouterr().out


def test_reads_utf8_bom_without_residue(tmp_path, monkeypatch, capsys):
    """BOM 이 첫 컬럼 이름에 남으면 표제어를 못 읽어 행이 통째로 사라진다."""
    src = tmp_path / "src"
    _write(src / "freq.csv", "어휘,순위,빈도\n사람,1,999\n", encoding="utf-8-sig")
    rows = _run(tmp_path, monkeypatch, src)
    assert rows == [{"headword": "사람", "rank": 1, "count": 999}]
    assert "﻿" not in (tmp_path / "build" / OUT).read_text(encoding="utf-8")
    assert "인코딩=utf-8-sig" in capsys.readouterr().out


def test_missing_source_raises(tmp_path, monkeypatch):
    empty = tmp_path / "raw"
    empty.mkdir()
    monkeypatch.setattr(config, "RAW", empty)
    monkeypatch.setattr(config, "BUILD", tmp_path / "build")
    with pytest.raises(FileNotFoundError):
        run(use_fixtures=False)


def test_skips_rows_without_headword(tmp_path, monkeypatch):
    src = tmp_path / "src"
    _write(src / "freq.csv", "순위,어휘,빈도\n1,사람,999\n2, ,888\n")
    assert [r["headword"] for r in _run(tmp_path, monkeypatch, src)] == ["사람"]


def test_output_is_valid_jsonl_utf8(tmp_path, monkeypatch):
    _run(tmp_path, monkeypatch)
    lines = (tmp_path / "build" / OUT).read_text(encoding="utf-8").splitlines()
    assert lines and all(json.loads(line) for line in lines)
    assert "강아지" in "\n".join(lines), "한글이 이스케이프되면 안 된다"


def test_encoding_is_logged(tmp_path, monkeypatch, capsys):
    _run(tmp_path, monkeypatch)
    out = capsys.readouterr().out
    assert "인코딩=utf-8-sig" in out, "성공한 인코딩이 로그에 없다 (02-05 DoD)"
    assert "'kept': 99" in out and "'drop_dup': 1" in out
