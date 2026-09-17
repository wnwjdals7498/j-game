"""scored.jsonl -> build/words.sqlite (02-09).

앱에 동봉되는 **최종 산출물**을 만든다. 스키마는 `tools/schema.sql` 이 정본이고
(3단계 drift·5단계 db-swapper가 그대로 베끼는 계약), 여기서는 적용·적재·meta 기록만 한다.

재현성: 같은 입력이면 같은 파일이 나와야 05-01 의 sha256 비교가 안정적이다.
그래서 (1) 매번 새로 만들고, (2) `headword` 로 정렬해 삽입 순서를 고정한다.
`built_at` 만은 매 실행 달라지는데, 05-01 이 sha256 을 그때 계산하므로 문제되지 않는다
(02-09 "재현성").
"""
import json
import shutil
import sqlite3
from datetime import datetime, timezone

from . import config, io_util

OUT = "words.sqlite"
IN = "scored.jsonl"

SIZE_LIMIT_MB = 10          # DESIGN 6절 용량 목표. 초과하면 02-09 "막히면" 순서대로 조정

# 02-09 "meta 에 넣을 키" 표. 03-01 · 02-10 check() 가 이 6개를 그대로 요구한다.
META_KEYS = ("schema_version", "db_version", "built_at",
             "word_count", "source_versions", "license_notice")

# `docs/LICENSES.md` 는 00-01(HUMAN, 이용 신청)이 만든다. 아직 없을 때 쓰는 문구.
# DB 안에 출처 표기를 넣는 이유: 갱신(05)으로 DB만 바뀌어도 표기가 따라가야 한다 (02-09).
LICENSE_PENDING = (
    "출처 표기 미확정 (docs/LICENSES.md 없음, 00-01 이용 신청 승인 대기). "
    "사전: CC BY-SA 2.0 KR / 빈도·학습용 어휘: 공공누리 제1유형 (docs/DESIGN.md 6절)"
)


def run(use_fixtures: bool = False) -> int:
    _sync_licenses()                      # 04-06: 두 파일이 갈라지지 않게 매 빌드마다 강제

    dst = config.BUILD / OUT
    dst.parent.mkdir(parents=True, exist_ok=True)
    if dst.exists():
        dst.unlink()                      # 항상 새로 만든다 (재현성)

    schema = (config.ROOT / "tools" / "schema.sql").read_text(encoding="utf-8")
    con = sqlite3.connect(dst)
    try:
        con.executescript(schema)

        rows = list(io_util.read_jsonl(config.BUILD / IN))
        rows.sort(key=lambda r: r["headword"])    # 삽입 순서 고정 (재현성)

        con.executemany(
            "INSERT INTO word (headword, len, c1, c2, c3, c4, c5,"
            " tier, pos, freq_rank, source) VALUES (?,?,?,?,?,?,?,?,?,?,?)",
            [_word_row(r) for r in rows],
        )

        sense_rows, char_rows = [], []
        for r in rows:
            for s in r["senses"]:
                sense_rows.append((
                    s["sense_id"], r["headword"],
                    s["definition"][: config.DEFINITION_MAX_CHARS],
                    ",".join(s["synonyms"]) or None,
                    s["source"],
                ))
            # set() 로 고유 음절만. `바나나` 는 (바, 나) 2행이다 (02-09 "word_char 역색인").
            # PK 가 (ch, headword) 라 중복이 오면 그대로 터진다 — 여기서 미리 줄인다.
            for ch in set(r["syllables"]):
                char_rows.append((ch, r["headword"]))
        char_rows.sort()                  # set() 순회 순서에 기대지 않는다 (재현성)

        con.executemany(
            "INSERT INTO sense (sense_id, headword, definition, synonyms, source)"
            " VALUES (?,?,?,?,?)", sense_rows)
        con.executemany(
            "INSERT INTO word_char (ch, headword) VALUES (?,?)", char_rows)

        con.executemany(
            "INSERT INTO meta (key, value) VALUES (?,?)",
            [
                ("schema_version", str(config.SCHEMA_VERSION)),
                ("db_version", str(config.DB_VERSION)),
                ("built_at", datetime.now(timezone.utc).isoformat()),
                ("word_count", str(len(rows))),
                ("source_versions", json.dumps(_source_versions(use_fixtures),
                                               ensure_ascii=False)),
                ("license_notice", _license_notice()),
            ],
        )
        con.commit()
        # VACUUM 은 삭제 흔적을 정리해 파일을 줄이고, ANALYZE 는 인덱스 통계를 만들어
        # 기기에서 플래너가 idx_word_cN 을 고르게 한다 (03-03 EXPLAIN QUERY PLAN).
        con.execute("VACUUM")
        con.execute("ANALYZE")
        con.commit()
    finally:
        con.close()

    size_mb = dst.stat().st_size / 1024 / 1024
    print(f"    build_sqlite: {len(rows):,} words, "
          f"{len(sense_rows):,} senses, {size_mb:.1f} MB")
    # 콘솔이 cp949 일 수 있으므로 비 cp949 문자는 쓰지 않는다 (02-06/02-07 과 같은 이유).
    if size_mb > SIZE_LIMIT_MB:
        print(f"      경고: 용량 목표({SIZE_LIMIT_MB}MB) 초과. "
              f"config.DEFINITION_MAX_CHARS({config.DEFINITION_MAX_CHARS}) 조정 검토"
              " (02-09 '막히면')")
    return len(rows)


def _word_row(r: dict):
    """음절을 c1..c5 로 펼친다. 2음절이면 c3..c5 가 NULL (02-09 'c3..c5 가 NULL인 이유')."""
    s = r["syllables"] + [None] * (5 - len(r["syllables"]))
    return (r["headword"], r["len"], s[0], s[1], s[2], s[3], s[4],
            r["tier"], r["pos"], r.get("freq_rank"), r["source"])


def _source_versions(use_fixtures: bool) -> dict:
    """원본 자료의 파일명·크기·수정일 (02-09 meta 표 "원본 자료 버전/날짜 JSON").

    `origin` 이 `fixtures` 면 이 DB 는 **실데이터가 아니다** — 손으로 만든 샘플로 만든
    것이다 (00-01 승인 대기). 02-10 리포트와 눈 검수가 그 사실을 알아야 한다.
    """
    src = config.FIXTURES if use_fixtures else config.RAW
    files = {}
    if src.exists():
        for p in sorted(src.rglob("*")):
            if p.is_file():
                st = p.stat()
                files[p.relative_to(src).as_posix()] = {
                    "bytes": st.st_size,
                    "mtime": datetime.fromtimestamp(
                        st.st_mtime, timezone.utc).isoformat(),
                }
    return {"origin": "fixtures" if use_fixtures else "raw", "files": files}


def _sync_licenses() -> None:
    """`docs/LICENSES.md` -> `app/assets/LICENSES.md` 자동 복사 (04-06 "복사를
    자동화한다" — 두 파일이 갈라지면 CC BY-SA 2.0 KR 표기 의무 위반이다).

    04-06 "막히면": "복사를 `python -m tools build` 에 넣어 강제한다" — 이 함수가
    `run()` 맨 앞에서 항상 불려 별도 스크립트 실행을 잊는 경로가 없게 한다.
    `docs/LICENSES.md` 가 아직 없으면(00-01 승인 대기) 조용히 건너뛴다 —
    `_license_notice()`가 이미 그 경우의 `LICENSE_PENDING` 문구를 처리한다.
    """
    src = config.ROOT / "docs" / "LICENSES.md"
    if not src.exists():
        return
    config.APP_ASSETS.mkdir(parents=True, exist_ok=True)
    shutil.copy(src, config.APP_ASSETS / "LICENSES.md")


def _license_notice() -> str:
    """`docs/LICENSES.md` 요약 — 자료 제목(`## `)과 라이선스 줄만 모은다.

    04-06 출처 표기 화면은 긴 전문을 `app/assets/LICENSES.md` 에서 읽는다.
    여기 들어가는 건 갱신된 DB 만으로도 출처를 말할 수 있게 하는 **요약**이다.
    """
    p = config.ROOT / "docs" / "LICENSES.md"
    if not p.exists():
        return LICENSE_PENDING

    title, parts = None, []
    for line in p.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line.startswith("## "):
            title = line[3:].strip()
        elif line.startswith("- 라이선스:") and title:
            parts.append(f"{title}: {line.split(':', 1)[1].strip()}")
            title = None
    return " / ".join(parts) if parts else LICENSE_PENDING
