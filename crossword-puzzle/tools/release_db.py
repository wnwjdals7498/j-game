"""words.sqlite -> manifest.json 생성 (+ 선택: GitHub 릴리스 업로드).

manifest.json 은 05-02(SyncService)·06-05(릴리스 절차)가 그대로 읽는 계약이다
(docs/plan/05-01.manifest-and-release-script.md). `python tools/release_db.py`로
직접 실행하는 독립 스크립트라 tools 패키지를 import하지 않는다(sys.path에 저장소
루트가 없어 `from tools import ...`가 깨진다) — 그래서 REPO 등은 여기 자체 상수다.

사용법:
  python tools/release_db.py --db tools/build/words.sqlite --out tools/build/release
  python tools/release_db.py ... --upload        # gh CLI로 릴리스 생성·업로드
"""
import argparse
import hashlib
import json
import shutil
import sqlite3
import subprocess
import sys
from datetime import date
from pathlib import Path

# DB 릴리스를 올리는 저장소. 앱과 같은 저장소를 쓰기로 결정했다(docs/DESIGN.md 6절) —
# 대신 앱 버전으로 GitHub Release를 만드는 일이 생기면 항상 pre-release로 표시해
# releases/latest 가 DB 릴리스를 계속 가리키게 유지한다(06-03·06-05에 한 줄씩 남겨 뒀다).
REPO = "wnwjdals7498/j-game"
MIN_APP_VERSION = "1.0.0"

REQUIRED_TABLES = ("word", "sense", "word_char", "word_stat", "meta", "puzzle_log")
# ETL은 빈 테이블만 만든다. 갱신 때 05-03이 보존하는 대상이라, 시드 DB에 값이 남아
# 있으면 개발자 데이터가 전 사용자에게 오염으로 퍼진다 (docs/plan/05-03.db-swapper.md).
APP_WRITTEN_TABLES = ("word_stat", "puzzle_log")
MIN_WORD_COUNT = 1000
MAX_SIZE_BYTES = 50 * 1024 * 1024


def sha256_of(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def read_meta(db: Path) -> dict:
    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    try:
        return dict(con.execute("SELECT key, value FROM meta").fetchall())
    finally:
        con.close()


def asset_path(out_dir: Path, db_version: int) -> Path:
    return out_dir / f"words-v{db_version}.sqlite"


def build_manifest(db: Path, out_dir: Path, notes: str = "") -> dict:
    """DB 사본을 만들고 manifest dict를 계산한다.

    **`manifest.json`은 여기서 쓰지 않는다** — `verify()` 통과 후 `write_manifest()`가
    쓴다. 실패한 릴리스가 `out_dir`에 유효해 보이는 `manifest.json`을 남기면, 같은
    `db_version`으로 다시 시도할 때 `check_version_bump`가 거짓 경고를 낸다.
    """
    meta = read_meta(db)
    db_version = int(meta["db_version"])
    schema_version = int(meta["schema_version"])

    out_dir.mkdir(parents=True, exist_ok=True)
    asset = asset_path(out_dir, db_version)
    if asset.resolve() != Path(db).resolve():
        shutil.copy(db, asset)

    return {
        "db_version": db_version,
        "schema_version": schema_version,
        "url": f"https://github.com/{REPO}/releases/download/"
               f"db-v{db_version}/{asset.name}",
        "sha256": sha256_of(asset),
        "size_bytes": asset.stat().st_size,
        "min_app_version": MIN_APP_VERSION,
        "published_at": date.today().isoformat(),
        "word_count": int(meta.get("word_count", 0)),
        "notes": notes,
    }


def write_manifest(manifest: dict, out_dir: Path) -> Path:
    path = out_dir / "manifest.json"
    path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8")
    return path


def previous_manifest(out_dir: Path) -> dict | None:
    """out_dir에 남아 있는 직전 manifest.json (없거나 읽을 수 없으면 None).

    db_version 미증가/역행 경고(check_version_bump)의 로컬 근사 — 네트워크 없이
    직전 실행 결과와만 비교한다. 06-05가 GitHub의 실제 릴리스 목록을 조회하는
    `latest_released_version()`으로 `prev`를 대체할 예정이다.
    """
    path = out_dir / "manifest.json"
    if not path.exists():
        return None
    try:
        # JSONDecodeError·UnicodeDecodeError 모두 ValueError의 하위 클래스다.
        data = json.loads(path.read_text(encoding="utf-8"))
    except (ValueError, OSError):
        return None
    return data if isinstance(data, dict) else None


def check_version_bump(prev: dict | None, manifest: dict) -> str | None:
    if prev is None:
        return None
    prev_version = prev.get("db_version")
    if not isinstance(prev_version, int):
        return None
    if manifest["db_version"] == prev_version:
        return (f"db_version이 이전 릴리스와 같습니다({manifest['db_version']}). "
                f"config.DB_VERSION을 올리세요.")
    if manifest["db_version"] < prev_version:
        return (f"db_version이 이전 릴리스({prev_version})보다 낮습니다"
                f"({manifest['db_version']}). 내려가는 릴리스는 만들 수 없습니다.")
    return None


def verify(db: Path, manifest: dict) -> list[str]:
    errors = []
    if manifest["size_bytes"] > MAX_SIZE_BYTES:
        errors.append(f"파일이 너무 큼: {manifest['size_bytes']}")

    con = sqlite3.connect(f"file:{db}?mode=ro", uri=True)
    try:
        tables = {r[0] for r in con.execute(
            "SELECT name FROM sqlite_master WHERE type='table'")}
        for t in REQUIRED_TABLES:
            if t not in tables:
                errors.append(f"테이블 없음: {t}")

        # manifest["word_count"](= meta.word_count)와만 비교하면 자기 자신과 비교하는
        # 꼴이라 word 테이블이 잘려도 못 잡는다 — 실제 행 수를 기준으로 삼는다.
        word_count = manifest["word_count"]
        if "word" in tables:
            word_count = con.execute("SELECT COUNT(*) FROM word").fetchone()[0]
            if word_count != manifest["word_count"]:
                errors.append(
                    f"meta.word_count({manifest['word_count']}) != "
                    f"word 테이블 행 수({word_count})")
        if word_count < MIN_WORD_COUNT:
            errors.append(f"단어 수가 너무 적음: {word_count}")

        for t in APP_WRITTEN_TABLES:
            if t in tables:
                n = con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0]
                if n != 0:
                    errors.append(f"{t} 테이블이 비어 있지 않음: {n}행")
    finally:
        con.close()
    return errors


def upload(manifest: dict, out_dir: Path) -> None:
    tag = f"db-v{manifest['db_version']}"
    subprocess.run([
        "gh", "release", "create", tag,
        str(asset_path(out_dir, manifest["db_version"])),
        str(out_dir / "manifest.json"),
        "--repo", REPO,
        "--title", f"단어 DB v{manifest['db_version']}",
        "--notes", manifest["notes"] or f"db_version {manifest['db_version']}",
    ], check=True)


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--db", required=True, type=Path)
    p.add_argument("--out", required=True, type=Path)
    p.add_argument("--notes", default="")
    p.add_argument("--upload", action="store_true",
                    help="gh CLI로 릴리스 생성·업로드")
    a = p.parse_args(argv)

    try:
        prev = previous_manifest(a.out)
        manifest = build_manifest(a.db, a.out, a.notes)

        warning = check_version_bump(prev, manifest)
        if warning:
            print(f"[경고] {warning}", file=sys.stderr)

        errors = verify(asset_path(a.out, manifest["db_version"]), manifest)
        for e in errors:
            print(f"오류: {e}", file=sys.stderr)
        if errors:
            return 1

        write_manifest(manifest, a.out)
        print(json.dumps(manifest, ensure_ascii=False, indent=2))

        if a.upload:
            upload(manifest, a.out)
    except (KeyError, ValueError, sqlite3.Error, OSError,
            subprocess.CalledProcessError, FileNotFoundError) as e:
        print(f"오류: {e}", file=sys.stderr)
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
