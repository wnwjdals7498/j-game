"""02-05 빈도 파서 테스트. 픽스처: tools/fixtures/freq_sample.xlsx

02-01 재조사(2026-09-17)로 원본이 csv 가 아니라 xlsx 임이 확인되어 픽스처와 파서를
함께 갈아엎었다. 샘플은 손수 만든 것이며 실데이터가 아니다(tools/README.md 참조).
xlsx 는 숫자 셀이 이미 int/float 라 csv 의 "천단위 구분자"·"인코딩 판별" 문제 자체가
없다 — 관련 테스트는 이번 픽스처에서 뺐다(해당 없음, tools/README.md 02-05 절 참고).
"""
import json

import openpyxl
import pytest

from tools import config, io_util
from tools.parse_freq import OUT, _to_int, run

ALLOWED_KEYS = {"headword", "rank", "count"}


def _run(tmp_path, monkeypatch, src=None) -> list[dict]:
    """src 를 주면 그 폴더를 픽스처로 쓴다."""
    if src is not None:
        monkeypatch.setattr(config, "FIXTURES", src)
    monkeypatch.setattr(config, "BUILD", tmp_path / "build")
    n = run(use_fixtures=True)
    rows = list(io_util.read_jsonl(tmp_path / "build" / OUT))
    assert n == len(rows)
    return rows


def _write_xlsx(path, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    wb = openpyxl.Workbook()
    ws = wb.active
    for r in rows:
        ws.append(r)
    wb.save(path)


@pytest.fixture
def rows(tmp_path, monkeypatch):
    return _run(tmp_path, monkeypatch)


def _by_word(rows) -> dict[str, dict]:
    return {r["headword"]: r for r in rows}


def test_basic_parse_row_count(rows):
    """픽스처 11행 중 '사람'(순위100 중복)·'가02'·'사과02'가 정규화 후 중복이라 8행."""
    assert len(rows) == 8
    assert len(_by_word(rows)) == 8


def test_schema(rows):
    for r in rows:
        assert set(r) == ALLOWED_KEYS
        assert r["headword"].strip() == r["headword"] and r["headword"]
        assert isinstance(r["rank"], int) and r["rank"] >= 1
        assert isinstance(r["count"], int)


def test_xlsx_numeric_cells_need_no_comma_parsing(rows):
    """xlsx 숫자 셀은 이미 int 다 — csv 의 "62,384" 같은 문자열 파싱이 필요 없다."""
    assert _by_word(rows)["사람"]["count"] == 62384
    assert _to_int("1,234") == 1234, "방어적으로는 여전히 천단위 구분자 문자열도 받는다"
    assert _to_int(None) is None and _to_int("없음") is None
    assert _to_int(1234.0) == 1234, "xlrd 계열 float 셀도 받는다"


def test_headword_normalized_before_matching(rows):
    """어휘 컬럼에 동형어 번호가 붙어 있다(예 '가01') — merge.py 가 기대하는 정규화된
    표제어와 맞추려면 파서 단계에서 normalize_headword 를 적용해야 한다(02-07.merge.md
    "막히면"). '가01'(순위2)·'가02'(순위3) 는 둘 다 "가"로 정규화되고 더 좋은 순위가 남는다.
    """
    by = _by_word(rows)
    assert "가01" not in by and "가02" not in by
    assert by["가"]["rank"] == 2
    assert by["사과"]["rank"] == 30, "사과01(순위30)·사과02(순위31) 정규화 후 30만 남음"


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
    _write_xlsx(src / "freq.xlsx", [("어휘", "빈도"), ("나무", 10), ("사람", 30), ("하늘", 20)])
    rows = _run(tmp_path, monkeypatch, src)
    assert {r["headword"]: r["rank"] for r in rows} == {"사람": 1, "하늘": 2, "나무": 3}
    assert min(r["rank"] for r in rows) == 1


def test_ties_get_same_rank(tmp_path, monkeypatch):
    """동률은 같은 순위. 그 뒤 rank 가 건너뛰어도 무방하다 (02-08은 정규화만)."""
    src = tmp_path / "src"
    _write_xlsx(src / "freq.xlsx",
                [("어휘", "빈도"), ("가", 30), ("나", 20), ("다", 20), ("라", 10)])
    ranks = {r["headword"]: r["rank"] for r in _run(tmp_path, monkeypatch, src)}
    assert ranks["나"] == ranks["다"] == 2
    assert ranks == {"가": 1, "나": 2, "다": 2, "라": 4}


def test_missing_source_raises(tmp_path, monkeypatch):
    empty = tmp_path / "raw"
    empty.mkdir()
    monkeypatch.setattr(config, "RAW", empty)
    monkeypatch.setattr(config, "BUILD", tmp_path / "build")
    with pytest.raises(FileNotFoundError):
        run(use_fixtures=False)


def test_skips_rows_without_headword(tmp_path, monkeypatch):
    src = tmp_path / "src"
    _write_xlsx(src / "freq.xlsx",
                [("순위", "어휘", "빈도"), (1, "사람", 999), (2, " ", 888)])
    assert [r["headword"] for r in _run(tmp_path, monkeypatch, src)] == ["사람"]


def test_output_is_valid_jsonl_utf8(tmp_path, monkeypatch):
    _run(tmp_path, monkeypatch)
    lines = (tmp_path / "build" / OUT).read_text(encoding="utf-8").splitlines()
    assert lines and all(json.loads(line) for line in lines)
    assert "강아지" in "\n".join(lines), "한글이 이스케이프되면 안 된다"


def test_kept_and_drop_dup_are_logged(tmp_path, monkeypatch, capsys):
    _run(tmp_path, monkeypatch)
    out = capsys.readouterr().out
    assert "'kept': 8" in out and "'drop_dup': 3" in out
