"""02-09 schema.sql · SQLite 빌드 테스트.

케이스는 02-09 "테스트" 절 표 12종을 그대로 옮긴 것이다. 입력은 손으로 만든
`scored.jsonl` 이며 **실데이터가 아니다** (00-01 승인 대기, tools/README.md 참조).
"""
import sqlite3

import pytest

from tools import config, io_util
from tools.build_sqlite import IN, META_KEYS, OUT, run

LONG_DEF = "뜻" * 200          # DEFINITION_MAX_CHARS(80) 보다 확실히 길다


def _r(headword, tier=1, freq_rank=None, source=config.SRC_KRDICT,
       definition="설명.", synonyms=(), sense_id=None) -> dict:
    """scored.jsonl 한 행 (02-08 출력 = 02-07 출력 + score/tier)."""
    return {
        "headword": headword, "len": len(headword), "syllables": list(headword),
        "pos": "명사", "source": source, "freq_rank": freq_rank,
        "vocab_grade": None, "in_krdict": bool(source & config.SRC_KRDICT),
        "score": 0.5, "tier": tier,
        "senses": [{
            "sense_id": sense_id or f"s:{headword}",
            "definition": definition,
            "synonyms": list(synonyms),
            "source": source,
        }],
    }


# 2·3·5음절, 유의어 있음/없음, 뜻풀이 길이 초과, 반복 음절(바나나)을 한 세트로 덮는다.
SAMPLE = [
    _r("사과", tier=1, freq_rank=25, source=config.SRC_KRDICT | config.SRC_STDICT,
       definition="둥글고 붉으며 단맛이 나는 과일.", synonyms=["능금"]),
    _r("도서관", tier=2, freq_rank=310, definition=LONG_DEF),
    _r("바나나", tier=3, source=config.SRC_STDICT,
       definition="길쭉하고 노란 열대 과일.", synonyms=["파초", "감초"]),
    _r("무지개다리", tier=7, source=config.SRC_STDICT, definition="무지개 모양의 다리."),
]


def _build(tmp_path, monkeypatch, rows) -> sqlite3.Connection:
    build = tmp_path / "build"
    build.mkdir(parents=True, exist_ok=True)
    monkeypatch.setattr(config, "BUILD", build)
    io_util.write_jsonl(build / IN, rows)
    assert run(use_fixtures=True) == len(rows)
    return sqlite3.connect(build / OUT)


@pytest.fixture
def db(tmp_path, monkeypatch):
    con = _build(tmp_path, monkeypatch, SAMPLE)
    yield con
    con.close()


def _names(db, kind: str) -> set[str]:
    return {r[0] for r in db.execute(
        "SELECT name FROM sqlite_master WHERE type=?", (kind,))}


# --- 02-09 "테스트" 표 ---

def test_tables_exist(db):
    """테이블 존재: word, sense, word_char, word_stat, meta (DoD 1)."""
    assert _names(db, "table") >= {"word", "sense", "word_char", "word_stat", "meta"}


def test_indexes_exist(db):
    """인덱스 존재: idx_word_c1..c5 + idx_sense_headword (DoD 1). 03-01 이 같은 이름을 본다."""
    assert _names(db, "index") >= {f"idx_word_c{i}" for i in range(1, 6)} | {
        "idx_sense_headword"}


def test_word_row_count(db):
    """word 행 수 = scored.jsonl 행 수. meta.word_count 도 같은 값이어야 한다."""
    assert db.execute("SELECT COUNT(*) FROM word").fetchone()[0] == len(SAMPLE)
    assert db.execute(
        "SELECT value FROM meta WHERE key='word_count'").fetchone()[0] == str(len(SAMPLE))


def test_syllable_columns(db):
    """c1..c5 매핑: 음절이 자리대로 들어가고 남는 자리는 NULL (02-09 'c3..c5 가 NULL인 이유')."""
    got = dict(db.execute("SELECT headword, c1 || '|' || c2 FROM word").fetchall())
    assert got["도서관"] == "도|서"
    assert db.execute(
        "SELECT c3, c4, c5 FROM word WHERE headword='도서관'").fetchone() == ("관", None, None)
    assert db.execute(
        "SELECT c3, c4, c5 FROM word WHERE headword='사과'").fetchone() == (None, None, None)
    assert db.execute(
        "SELECT c4, c5 FROM word WHERE headword='무지개다리'").fetchone() == ("다", "리")


def test_word_stat_is_empty(db):
    """word_stat 빈 테이블: ETL 은 만들기만 한다. 채우는 건 앱이고 갱신 때 보존한다 (05-03)."""
    assert db.execute("SELECT COUNT(*) FROM word_stat").fetchone()[0] == 0


def test_meta_has_required_keys(db):
    """meta 필수 6키 (02-09 'meta 에 넣을 키' 표). 03-01·02-10 check() 가 그대로 요구한다."""
    meta = dict(db.execute("SELECT key, value FROM meta").fetchall())
    assert set(meta) >= set(META_KEYS)
    assert all(meta[k] for k in META_KEYS), meta
    assert meta["schema_version"] == str(config.SCHEMA_VERSION)
    assert meta["db_version"] == str(config.DB_VERSION)
    # 실데이터가 아니라 fixtures 로 만든 DB 라는 사실이 DB 안에 남는다 (00-01 승인 대기).
    assert '"origin": "fixtures"' in meta["source_versions"]


def test_definition_is_truncated(db):
    """뜻풀이 길이 컷: 전부 DEFINITION_MAX_CHARS 이하. 용량 목표 10MB 의 주 손잡이다."""
    lens = [n for (n,) in db.execute("SELECT LENGTH(definition) FROM sense")]
    assert lens and max(lens) <= config.DEFINITION_MAX_CHARS
    assert db.execute(
        "SELECT LENGTH(definition) FROM sense WHERE headword='도서관'"
    ).fetchone()[0] == config.DEFINITION_MAX_CHARS


def test_synonyms_serialization(db):
    """유의어 직렬화: 쉼표 구분 한 문자열, 없으면 NULL (빈 문자열이 아니다)."""
    syn = dict(db.execute("SELECT headword, synonyms FROM sense").fetchall())
    assert syn["바나나"] == "파초,감초"
    assert syn["사과"] == "능금"
    assert syn["도서관"] is None


def test_word_char_inverted_index(db):
    """word_char 역색인: 단어의 **고유** 음절마다 1행. `바나나` 는 (바, 나) 2행이다."""
    got = {}
    for ch, hw in db.execute("SELECT ch, headword FROM word_char"):
        got.setdefault(hw, set()).add(ch)
    assert got["바나나"] == {"바", "나"}
    assert got["무지개다리"] == {"무", "지", "개", "다", "리"}
    assert db.execute("SELECT COUNT(*) FROM word_char").fetchone()[0] == sum(
        len(set(r["syllables"])) for r in SAMPLE)


def test_foreign_key_integrity(db):
    """FK 무결성: 모든 sense.headword 가 word 에 있다. SQLite 는 기본적으로 FK 를
    강제하지 않으므로 (02-09 '막히면') 테스트로 직접 확인한다."""
    assert db.execute(
        "SELECT COUNT(*) FROM sense WHERE headword NOT IN (SELECT headword FROM word)"
    ).fetchone()[0] == 0
    assert db.execute("PRAGMA foreign_key_check").fetchall() == []


def test_rebuild_replaces_file(tmp_path, monkeypatch):
    """재실행: 기존 파일을 지우고 새로 만든다. 행 수는 그대로 (02-09 '재현성')."""
    con = _build(tmp_path, monkeypatch, SAMPLE)
    con.close()
    dst = config.BUILD / OUT
    before = dst.stat().st_size
    dst.write_bytes(b"garbage")           # 이전 실행의 찌꺼기를 흉내 낸다

    con = _build(tmp_path, monkeypatch, SAMPLE)
    try:
        assert dst.stat().st_size == before
        assert con.execute("SELECT COUNT(*) FROM word").fetchone()[0] == len(SAMPLE)
    finally:
        con.close()


def test_pattern_query_uses_index(tmp_path, monkeypatch):
    """패턴 질의 인덱스 사용: `EXPLAIN QUERY PLAN` 에 idx_word_c2 가 나온다.

    3단계 격자 탐색 성능의 선행 검증이다. 행이 몇십 개뿐인 fixture 에서는 플래너가
    full scan 을 고르는 게 정상이므로 (02-09 '막히면') 수천 행 합성 입력으로 돌린다.
    """
    rows = [_r(chr(0xAC00 + i % 400) + chr(0xAC00 + (i * 7 + 3) % 3000)
               + chr(0xAC00 + (i * 13 + 5) % 500), tier=i % 7 + 1)
            for i in range(3000)]
    rows = list({r["headword"]: r for r in rows}.values())     # PK 중복 제거
    con = _build(tmp_path, monkeypatch, rows)
    try:
        plan = con.execute(
            "EXPLAIN QUERY PLAN "
            "SELECT headword FROM word WHERE len=? AND tier IN (1,2) AND c2=?",
            (3, "가")).fetchall()
    finally:
        con.close()
    text = " ".join(str(r) for r in plan)
    assert "idx_word_c2" in text, f"인덱스 미사용: {text}"
