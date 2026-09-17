"""05-01 manifest.json 계약 · release_db.py 테스트.

docs/plan/05-01.manifest-and-release-script.md "테스트" 절 표 11종 중 10종(마지막
"앱 파서와 형식 일치"는 Dart 쪽 05-02)을 옮기고, 표에 없던 분기·요구를 추가로 덮는다:
verify()의 용량 초과 분기, puzzle_log 검사, word_count 교차 검증, db_version 미증가·역행
경고, previous_manifest()의 손상 파일 내성, main()의 성공/실패 종료 코드, 두 fixture
사본의 바이트 동일성(문서가 "CI에서 검사한다"고 남긴 것).
"""
import hashlib
import json
import sqlite3
from pathlib import Path

import pytest

from tools import release_db as rdb

REQUIRED_FIELDS = {
    "db_version": int, "schema_version": int, "url": str, "sha256": str,
    "size_bytes": int, "min_app_version": str, "published_at": str,
    "word_count": int, "notes": str,
}

TOOLS_FIXTURE = Path(__file__).resolve().parent.parent / "fixtures" / "manifest_sample.json"
APP_FIXTURE = (Path(__file__).resolve().parent.parent.parent
               / "app" / "test" / "fixtures" / "manifest_sample.json")


def _make_db(path, *, tables=rdb.REQUIRED_TABLES, word_count=1200,
             stat_rows=0, puzzle_log_rows=0, db_version=3, schema_version=1) -> None:
    con = sqlite3.connect(path)
    try:
        if "meta" in tables:
            con.execute("CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL)")
            con.executemany("INSERT INTO meta VALUES (?,?)", [
                ("db_version", str(db_version)),
                ("schema_version", str(schema_version)),
                ("word_count", str(word_count)),
            ])
        if "word" in tables:
            con.execute("CREATE TABLE word (headword TEXT PRIMARY KEY)")
            con.executemany("INSERT INTO word (headword) VALUES (?)",
                             [(f"단어{i}",) for i in range(word_count)])
        if "sense" in tables:
            con.execute("CREATE TABLE sense (sense_id TEXT PRIMARY KEY)")
        if "word_char" in tables:
            con.execute("CREATE TABLE word_char (ch TEXT, headword TEXT)")
        if "word_stat" in tables:
            con.execute(
                "CREATE TABLE word_stat (headword TEXT PRIMARY KEY, "
                "correct INTEGER NOT NULL DEFAULT 0, wrong INTEGER NOT NULL DEFAULT 0, "
                "last_seen INTEGER)")
            for i in range(stat_rows):
                con.execute("INSERT INTO word_stat (headword) VALUES (?)", (f"통계{i}",))
        if "puzzle_log" in tables:
            con.execute(
                "CREATE TABLE puzzle_log (level_id INTEGER NOT NULL, seed INTEGER NOT NULL, "
                "first_score INTEGER NOT NULL, submitted_at INTEGER NOT NULL, "
                "PRIMARY KEY (level_id, seed))")
            for i in range(puzzle_log_rows):
                con.execute("INSERT INTO puzzle_log VALUES (?,?,?,?)", (1, i, 100, 0))
        con.commit()
    finally:
        con.close()


@pytest.fixture
def db(tmp_path):
    path = tmp_path / "words.sqlite"
    _make_db(path)
    return path


# --- manifest 필드 / sha256 / size / URL / meta 읽기 ---

def test_manifest_has_all_required_fields(db, tmp_path):
    manifest = rdb.build_manifest(db, tmp_path / "release")
    assert set(manifest) == set(REQUIRED_FIELDS)
    for key, typ in REQUIRED_FIELDS.items():
        assert isinstance(manifest[key], typ), f"{key}: {type(manifest[key])}"


def test_sha256_matches_asset_file(db, tmp_path):
    out = tmp_path / "release"
    manifest = rdb.build_manifest(db, out)
    asset = rdb.asset_path(out, manifest["db_version"])
    assert manifest["sha256"] == hashlib.sha256(asset.read_bytes()).hexdigest()


def test_size_bytes_matches_asset_file(db, tmp_path):
    out = tmp_path / "release"
    manifest = rdb.build_manifest(db, out)
    asset = rdb.asset_path(out, manifest["db_version"])
    assert manifest["size_bytes"] == asset.stat().st_size


def test_url_format(db, tmp_path):
    manifest = rdb.build_manifest(db, tmp_path / "release")
    assert manifest["url"] == (
        f"https://github.com/{rdb.REPO}/releases/download/"
        f"db-v{manifest['db_version']}/words-v{manifest['db_version']}.sqlite")


def test_reads_versions_from_meta(tmp_path):
    path = tmp_path / "words.sqlite"
    _make_db(path, db_version=7, schema_version=2, word_count=5000)
    manifest = rdb.build_manifest(path, tmp_path / "release")
    assert manifest["db_version"] == 7
    assert manifest["schema_version"] == 2
    assert manifest["word_count"] == 5000


# --- verify() ---

def test_verify_ok_db_has_no_errors(db, tmp_path):
    out = tmp_path / "release"
    manifest = rdb.build_manifest(db, out)
    asset = rdb.asset_path(out, manifest["db_version"])
    assert rdb.verify(asset, manifest) == []


def test_verify_low_word_count_is_an_error(tmp_path):
    path = tmp_path / "words.sqlite"
    _make_db(path, word_count=10)
    manifest = {"word_count": 10, "size_bytes": 1000}
    errors = rdb.verify(path, manifest)
    assert any("단어 수가 너무 적음" in e for e in errors)


def test_verify_word_count_mismatch_is_an_error(db):
    """meta.word_count가 word 테이블 실제 행 수와 다르면 잡는다 (자기 자신과 비교 금지)."""
    manifest = {"word_count": 999999, "size_bytes": 1000}
    errors = rdb.verify(db, manifest)
    assert any("word 테이블 행 수" in e for e in errors)


def test_verify_oversized_file_is_an_error(db):
    manifest = {"word_count": 1200, "size_bytes": rdb.MAX_SIZE_BYTES + 1}
    errors = rdb.verify(db, manifest)
    assert any("파일이 너무 큼" in e for e in errors)


def test_verify_polluted_word_stat_is_an_error(tmp_path):
    path = tmp_path / "words.sqlite"
    _make_db(path, stat_rows=5)
    manifest = {"word_count": 1200, "size_bytes": 1000}
    errors = rdb.verify(path, manifest)
    assert any("word_stat" in e for e in errors)


def test_verify_polluted_puzzle_log_is_an_error(tmp_path):
    path = tmp_path / "words.sqlite"
    _make_db(path, puzzle_log_rows=3)
    manifest = {"word_count": 1200, "size_bytes": 1000}
    errors = rdb.verify(path, manifest)
    assert any("puzzle_log" in e for e in errors)


def test_verify_missing_table_is_an_error(tmp_path):
    path = tmp_path / "words.sqlite"
    tables = tuple(t for t in rdb.REQUIRED_TABLES if t != "word_char")
    _make_db(path, tables=tables)
    manifest = {"word_count": 1200, "size_bytes": 1000}
    errors = rdb.verify(path, manifest)
    assert any("word_char" in e for e in errors)


def test_verify_missing_puzzle_log_is_an_error(tmp_path):
    """03-04에서 뒤늦게 추가된 테이블 — 05-03이 빠뜨리기 쉽다고 경고하는 바로 그것."""
    path = tmp_path / "words.sqlite"
    tables = tuple(t for t in rdb.REQUIRED_TABLES if t != "puzzle_log")
    _make_db(path, tables=tables)
    manifest = {"word_count": 1200, "size_bytes": 1000}
    errors = rdb.verify(path, manifest)
    assert any("puzzle_log" in e for e in errors)


# --- 재현성 ---

def test_manifest_is_deterministic_except_published_at(db, tmp_path):
    m1 = rdb.build_manifest(db, tmp_path / "out1")
    m2 = rdb.build_manifest(db, tmp_path / "out2")
    for key in REQUIRED_FIELDS:
        if key == "published_at":
            continue
        assert m1[key] == m2[key], key


def test_written_manifest_roundtrips_korean_notes(db, tmp_path):
    out = tmp_path / "release"
    manifest = rdb.build_manifest(db, out, notes="2027년 3월 사전 갱신")
    rdb.write_manifest(manifest, out)
    raw = (out / "manifest.json").read_bytes()
    assert raw.endswith(b"\n")
    assert "2027년 3월 사전 갱신".encode("utf-8") in raw   # ensure_ascii=False
    assert json.loads(raw.decode("utf-8")) == manifest


# --- db_version 미증가/역행 경고 · previous_manifest 내성 ---

def test_check_version_bump_none_when_no_previous(db, tmp_path):
    manifest = rdb.build_manifest(db, tmp_path / "release")
    assert rdb.check_version_bump(None, manifest) is None


def test_check_version_bump_warns_on_same_version(db, tmp_path):
    out = tmp_path / "release"
    m1 = rdb.build_manifest(db, out)
    rdb.write_manifest(m1, out)
    prev = rdb.previous_manifest(out)

    m2 = rdb.build_manifest(db, out)
    warning = rdb.check_version_bump(prev, m2)
    assert warning is not None
    assert "같습니다" in warning


def test_check_version_bump_flags_downgrade(tmp_path):
    out = tmp_path / "release"
    path_v4 = tmp_path / "words_v4.sqlite"
    _make_db(path_v4, db_version=4)
    m4 = rdb.build_manifest(path_v4, out)
    rdb.write_manifest(m4, out)
    prev = rdb.previous_manifest(out)

    path_v3 = tmp_path / "words_v3.sqlite"
    _make_db(path_v3, db_version=3)
    m3 = rdb.build_manifest(path_v3, out)
    warning = rdb.check_version_bump(prev, m3)
    assert warning is not None
    assert "낮습니다" in warning


def test_check_version_bump_silent_on_new_version(tmp_path):
    out = tmp_path / "release"
    path_v3 = tmp_path / "words_v3.sqlite"
    _make_db(path_v3, db_version=3)
    m3 = rdb.build_manifest(path_v3, out)
    rdb.write_manifest(m3, out)
    prev = rdb.previous_manifest(out)

    path_v4 = tmp_path / "words_v4.sqlite"
    _make_db(path_v4, db_version=4)
    m4 = rdb.build_manifest(path_v4, out)
    assert rdb.check_version_bump(prev, m4) is None


def test_previous_manifest_none_when_absent(tmp_path):
    assert rdb.previous_manifest(tmp_path / "release") is None


def test_previous_manifest_ignores_corrupt_file(tmp_path):
    out = tmp_path / "release"
    out.mkdir()
    (out / "manifest.json").write_bytes(b"\xff\xfe not valid utf-8 or json")
    assert rdb.previous_manifest(out) is None


def test_previous_manifest_ignores_non_object_json(tmp_path):
    out = tmp_path / "release"
    out.mkdir()
    (out / "manifest.json").write_text("[1, 2, 3]", encoding="utf-8")
    assert rdb.previous_manifest(out) is None


# --- main() ---

def test_main_success_writes_manifest_and_returns_zero(db, tmp_path):
    out = tmp_path / "release"
    rc = rdb.main(["--db", str(db), "--out", str(out)])
    assert rc == 0
    assert (out / "manifest.json").exists()


def test_main_verify_failure_does_not_write_manifest(tmp_path):
    path = tmp_path / "words.sqlite"
    _make_db(path, word_count=10)          # 단어 수 부족 -> verify 실패
    out = tmp_path / "release"
    rc = rdb.main(["--db", str(path), "--out", str(out)])
    assert rc == 1
    assert not (out / "manifest.json").exists()


def test_main_failed_run_does_not_cause_false_bump_warning(tmp_path, capsys):
    """검증 실패한 실행은 manifest.json을 안 남기므로, 다음 실행이 같은 db_version이어도
    '이전 릴리스와 같음' 경고가 뜨면 안 된다 (실제로는 이전 릴리스 자체가 없다)."""
    path = tmp_path / "words.sqlite"
    _make_db(path, word_count=10, db_version=5)
    out = tmp_path / "release"
    assert rdb.main(["--db", str(path), "--out", str(out)]) == 1
    capsys.readouterr()

    assert rdb.main(["--db", str(path), "--out", str(out)]) == 1
    err = capsys.readouterr().err
    assert "이전 릴리스와 같습니다" not in err


# --- fixture 계약 ---

def test_sample_fixture_matches_contract():
    manifest = json.loads(TOOLS_FIXTURE.read_text(encoding="utf-8"))
    assert set(manifest) == set(REQUIRED_FIELDS)
    for key, typ in REQUIRED_FIELDS.items():
        assert isinstance(manifest[key], typ)
    sha = manifest["sha256"]
    assert len(sha) == 64 and all(c in "0123456789abcdef" for c in sha)


def test_fixture_copies_are_byte_identical():
    assert TOOLS_FIXTURE.read_bytes() == APP_FIXTURE.read_bytes()
