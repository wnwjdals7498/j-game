"""02-05 학습용 어휘 파서 테스트. 픽스처: tools/fixtures/vocab_sample.xls

02-01 재조사(2026-09-17)로 원본이 csv 가 아니라 xls(레거시 BIFF) 임이 확인되어
픽스처와 파서를 함께 갈아엎었다. 샘플은 손수 만든 것이며 실데이터가 아니다
(tools/README.md 참조). `xlrd` 2.x 는 `.xlsx` 를 못 읽으므로, freq 테스트처럼 테스트
안에서 즉석 파일을 만들 수가 없다(쓰기 라이브러리 `xlwt` 는 픽스처 생성 1회용 스크립트
에서만 썼고 런타임/테스트 의존성에 넣지 않았다) — 그래서 편집·중복·미매칭 케이스를
전부 커밋된 `vocab_sample.xls` 안에 심어 뒀다.
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


@pytest.fixture
def rows(tmp_path, monkeypatch):
    return _run(tmp_path, monkeypatch)


def _grades(rows) -> dict[str, str]:
    return {r["headword"]: r["grade"] for r in rows}


def test_basic_parse_row_count(rows):
    """픽스처 14행 중 미매칭 등급 1행('예쁘다') + 정규화 후 중복 1행('나무01'/'나무02')
    + 표제어 빈 행 2개가 빠져 10개."""
    assert len(rows) == 10


def test_schema(rows):
    for r in rows:
        assert set(r) == ALLOWED_KEYS
        assert r["headword"]
        assert r["grade"] in {"A", "B", "C"}


def test_grade_is_already_abc_no_text_mapping_needed(rows):
    """02-01 전수 확인: 실데이터 등급 컬럼은 이미 A/B/C 이고 "초급/중급/고급" 표기는
    0건이다. GRADE_MAP 의 항등 매핑만 실제로 쓰인다."""
    g = _grades(rows)
    assert g["가게"] == "A"
    assert g["가꾸다"] == "B"
    assert g["심근경색"] == "C"
    assert GRADE_MAP["A"] == "A" and GRADE_MAP["초급"] == "A"


def test_headword_normalized_before_matching(rows):
    """단어 컬럼에도 동형어 번호가 붙어 있다(예 '가격03') — freq 와 같은 이유로
    normalize_headword 를 적용해야 merge 와 맞는다(02-07.merge.md "막히면")."""
    g = _grades(rows)
    assert "가격03" not in g and "가격" in g
    assert g["가격"] == "B"


def test_duplicate_headword_keeps_easiest_grade(rows):
    """정규화 후 '나무01'(C)·'나무02'(A) 가 같은 표제어가 되고, 더 쉬운 등급(A)이 남는다."""
    assert _grades(rows)["나무"] == "A"


def test_skips_rows_without_headword(rows):
    """표제어가 비었거나 공백만 있는 행은 스킵한다(실데이터엔 0건이지만 방어 경로 유지)."""
    assert all(r["headword"].strip() for r in rows)
    assert len(rows) == 10  # 빈 표제어 2행이 이미 위 count 에 반영됨


def test_unmapped_grade_dropped_and_counted(rows, tmp_path, monkeypatch, capsys):
    """미매칭 등급은 조용히 버리지 않는다 — 개수와 실제 값을 로그에 찍는다 (02-05)."""
    assert "예쁘다" not in _grades(rows)
    _run(tmp_path, monkeypatch)
    out = capsys.readouterr().out
    assert "'drop_unmapped_grade': 1" in out
    assert "미매칭 등급 1건" in out and "등급없음" in out


def test_missing_source_raises(tmp_path, monkeypatch):
    empty = tmp_path / "raw"
    empty.mkdir()
    monkeypatch.setattr(config, "RAW", empty)
    monkeypatch.setattr(config, "BUILD", tmp_path / "build")
    with pytest.raises(FileNotFoundError):
        run(use_fixtures=False)


def test_output_is_valid_jsonl_utf8(tmp_path, monkeypatch):
    _run(tmp_path, monkeypatch)
    lines = (tmp_path / "build" / OUT).read_text(encoding="utf-8").splitlines()
    assert lines and all(json.loads(line) for line in lines)
    assert "무지개" in "\n".join(lines), "한글이 이스케이프되면 안 된다"


def test_kept_and_drop_counts_are_logged(tmp_path, monkeypatch, capsys):
    _run(tmp_path, monkeypatch)
    out = capsys.readouterr().out
    assert "'kept': 10" in out


def test_extra_headword_for_merge_fixture(rows):
    """'사과' 등급은 02-07 merge 픽스처 end-to-end 테스트가 기대하는 값이다."""
    assert _grades(rows)["사과"] == "A"
