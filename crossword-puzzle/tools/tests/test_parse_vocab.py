"""02-05 학습용 어휘 파서 테스트. 픽스처: tools/fixtures/vocab_sample.csv

샘플은 손수 만든 것이며 실데이터가 아니다 (00-01 승인 대기, tools/README.md 참조).
"""
import json

import pytest

from tools import config, io_util
from tools.parse_vocab import GRADE_MAP, OUT, run

ALLOWED_KEYS = {"headword", "grade"}


def _run(tmp_path, monkeypatch, src=None) -> list[dict]:
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


def _grades(rows) -> dict[str, str]:
    return {r["headword"]: r["grade"] for r in rows}


def test_basic_parse_row_count(rows):
    """샘플 50행 중 미매칭 등급 1행(`예쁘다`/`등급 없음`)이 빠져 49개."""
    assert len(rows) == 49


def test_schema(rows):
    for r in rows:
        assert set(r) == ALLOWED_KEYS
        assert r["headword"]
        assert r["grade"] in {"A", "B", "C"}


def test_grade_mapping(rows):
    g = _grades(rows)
    assert g["사람"] == "A"          # 초급
    assert g["딸기"] == "B"          # 중급
    assert g["심근경색"] == "C"      # 고급
    assert GRADE_MAP["초급"] == "A"


def test_grade_distribution(rows):
    counts = {k: sum(1 for r in rows if r["grade"] == k) for k in "ABC"}
    assert counts == {"A": 25, "B": 20, "C": 4}


def test_unmapped_grade_dropped_and_counted(rows, tmp_path, monkeypatch, capsys):
    """미매칭 등급은 조용히 버리지 않는다 — 개수와 실제 값을 로그에 찍는다 (02-05)."""
    assert "예쁘다" not in _grades(rows)
    _run(tmp_path, monkeypatch)
    out = capsys.readouterr().out
    assert "'drop_unmapped_grade': 1" in out
    assert "미매칭 등급 1건" in out and "등급 없음" in out


def test_duplicate_headword_keeps_easiest_grade(tmp_path, monkeypatch):
    """표제어가 PK 이므로 중복이면 가장 쉬운 등급만 남는다 (README "미해결")."""
    src = tmp_path / "src"
    _write(src / "vocab.csv", "어휘,등급\n사과,고급\n사과,초급\n나무,중급\n나무,고급\n")
    assert _grades(_run(tmp_path, monkeypatch, src)) == {"사과": "A", "나무": "B"}


def test_reads_cp949(tmp_path, monkeypatch, capsys):
    src = tmp_path / "src"
    _write(src / "vocab.csv", "어휘,품사,등급\n사람,명사,초급\n", encoding="cp949")
    assert _run(tmp_path, monkeypatch, src) == [{"headword": "사람", "grade": "A"}]
    assert "인코딩=cp949" in capsys.readouterr().out


def test_reads_utf8_bom_without_residue(tmp_path, monkeypatch):
    src = tmp_path / "src"
    _write(src / "vocab.csv", "어휘,등급\n사람,초급\n", encoding="utf-8-sig")
    assert _run(tmp_path, monkeypatch, src) == [{"headword": "사람", "grade": "A"}]
    assert "﻿" not in (tmp_path / "build" / OUT).read_text(encoding="utf-8")


def test_missing_source_raises(tmp_path, monkeypatch):
    empty = tmp_path / "raw"
    empty.mkdir()
    monkeypatch.setattr(config, "RAW", empty)
    monkeypatch.setattr(config, "BUILD", tmp_path / "build")
    with pytest.raises(FileNotFoundError):
        run(use_fixtures=False)


def test_skips_rows_without_headword(tmp_path, monkeypatch):
    src = tmp_path / "src"
    _write(src / "vocab.csv", "어휘,등급\n사람,초급\n ,초급\n")
    assert [r["headword"] for r in _run(tmp_path, monkeypatch, src)] == ["사람"]


def test_output_is_valid_jsonl_utf8(tmp_path, monkeypatch):
    _run(tmp_path, monkeypatch)
    lines = (tmp_path / "build" / OUT).read_text(encoding="utf-8").splitlines()
    assert lines and all(json.loads(line) for line in lines)
    assert "무지개" in "\n".join(lines), "한글이 이스케이프되면 안 된다"


def test_encoding_is_logged(tmp_path, monkeypatch, capsys):
    _run(tmp_path, monkeypatch)
    assert "인코딩=utf-8-sig" in capsys.readouterr().out
