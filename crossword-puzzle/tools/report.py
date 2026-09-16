"""분포 리포트 + 기계 검사 (02-10).

`render()` 는 `docs/reports/02-db-report.md` 를 만든다 — 사람이 **눈으로** DB 를 검수하기
위한 문서다. `check()` 는 그 반대로 **기계가 판정 가능한 것만** 보고 종료 코드를 낸다
(CI, 06-06). 두 함수의 내용은 [docs/plan/02-10.report-and-review.md](
../docs/plan/02-10.report-and-review.md) "리포트 내용"·"`python -m tools check`" 표가
정한 것이고, 여기서 그대로 구현한다.

골격(02-10)은 `DB`/`OUT` 을 모듈 상수 `Path` 로 잡았지만, 그러면 import 시점에
`config.BUILD` 가 얼어붙어 `config.BUILD` 를 monkeypatch 하는 02-09 테스트 방식이 통하지
않는다. 그래서 이름만 상수로 두고 경로는 호출 시점에 만든다 (02-09 `build_sqlite` 와 같은 꼴).
"""
import json
import random
import sqlite3
from datetime import date
from pathlib import Path

from . import config
from .build_sqlite import META_KEYS, OUT as DB_NAME, SIZE_LIMIT_MB
from .hangul import is_all_hangul

REPORT_PATH = ("docs", "reports", "02-db-report.md")

SEED = 20260916          # 고정 seed. 조정 전후 비교가 가능해야 한다 (02-10 "랜덤 샘플의 재현성")
SAMPLE_PER_TIER = 30
TOP_SYLLABLES = 20

_LEN_COLS = list(range(config.MIN_LEN, config.MAX_LEN + 1))


def _db_path() -> Path:
    return config.BUILD / DB_NAME


def _out_path() -> Path:
    return config.ROOT.joinpath(*REPORT_PATH)


def _rel(p: Path) -> str:
    try:
        return p.relative_to(config.ROOT).as_posix()
    except ValueError:
        return p.as_posix()


def _meta(con: sqlite3.Connection) -> dict[str, str]:
    return dict(con.execute("SELECT key, value FROM meta").fetchall())


def _is_fixture(meta: dict[str, str]) -> bool:
    """이 DB 가 실데이터가 아니라 `tools/fixtures/` 샘플로 만들어졌는가.

    02-09 `build_sqlite._source_versions()` 가 `origin` 을 DB 안에 남긴 이유가
    "02-10 리포트와 눈 검수가 그 사실을 알아야 한다" 였다. 여기가 그 소비자다.
    """
    try:
        return json.loads(meta.get("source_versions", "{}")).get("origin") == "fixtures"
    except (json.JSONDecodeError, AttributeError):
        return False


def _one(con: sqlite3.Connection, sql: str, args=()):
    return con.execute(sql, args).fetchone()[0]


def _pct(n: int, total: int) -> float:
    return n / total * 100 if total else 0.0


def _verdict(ok: bool) -> str:
    return "✅" if ok else "❌"


# --- 리포트 -----------------------------------------------------------------

def render(db: Path | None = None, out: Path | None = None) -> None:
    """`docs/reports/02-db-report.md` 생성."""
    db = db or _db_path()
    out = out or _out_path()
    if not db.exists():
        raise FileNotFoundError(
            f"{_rel(db)} 없음. 먼저 `python -m tools build` 를 돌릴 것 (02-09)")

    con = sqlite3.connect(db)
    try:
        text = _render_text(con, db)
    finally:
        con.close()

    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(text, encoding="utf-8")
    print(f"    report: {_rel(out)}")


def _render_text(con: sqlite3.Connection, db: Path) -> str:
    meta = _meta(con)
    total = _one(con, "SELECT COUNT(*) FROM word")
    size_mb = db.stat().st_size / 1024 / 1024

    lines = [
        "# 02단계 DB 리포트",
        "",
        f"생성일: {date.today().isoformat()}",
        f"DB: {_rel(db)} ({size_mb:.1f} MB)",
        f"db_version / schema_version: "
        f"{meta.get('db_version', '?')} / {meta.get('schema_version', '?')}",
        f"built_at: {meta.get('built_at', '?')}",
        "",
    ]
    if _is_fixture(meta):
        lines += [
            "> ⚠ 이 DB 는 **손수 만든 샘플**(`tools/fixtures/`)로 만든 것이다 — 실데이터가"
            " 아니다 (00-01 이용 신청 승인 대기). 아래 숫자는 전부 샘플 기준이라 난이도·분포"
            " 판단의 근거가 되지 못한다. 실데이터가 도착하면 `--fixtures` 없이 다시 빌드하고"
            " 이 리포트를 다시 뽑는다.",
            "",
        ]

    lines += _summary(con, meta, total, size_mb)
    lines += _tier_by_length(con, total)
    lines += _syllable_coverage(con)
    lines += _samples(con)
    lines += _human_review()
    return "\n".join(lines) + "\n"


def _summary(con, meta, total: int, size_mb: float) -> list[str]:
    max_def = _one(con, "SELECT COALESCE(MAX(LENGTH(definition)), 0) FROM sense")
    with_syn = _one(
        con, "SELECT COUNT(DISTINCT headword) FROM sense WHERE synonyms IS NOT NULL")
    only_kr = _one(con, "SELECT COUNT(*) FROM word WHERE source = ?", (config.SRC_KRDICT,))
    only_st = _one(con, "SELECT COUNT(*) FROM word WHERE source = ?", (config.SRC_STDICT,))
    both = _one(con, "SELECT COUNT(*) FROM word WHERE source = ?",
                (config.SRC_KRDICT | config.SRC_STDICT,))
    freq = _one(con, "SELECT COUNT(*) FROM word WHERE freq_rank IS NOT NULL")
    freq_pct = _pct(freq, total)

    return [
        "## 요약",
        "",
        "| 항목 | 값 | 기준 | 판정 |",
        "|---|---|---|---|",
        f"| 총 단어 수 | {total:,} | — | — |",
        f"| 파일 용량 | {size_mb:.1f} MB | ≤ {SIZE_LIMIT_MB} MB |"
        f" {_verdict(size_mb <= SIZE_LIMIT_MB)} |",
        f"| 뜻풀이 최대 길이 | {max_def} | ≤ {config.DEFINITION_MAX_CHARS} |"
        f" {_verdict(max_def <= config.DEFINITION_MAX_CHARS)} |",
        f"| 유의어 보유 단어 | {with_syn:,} ({_pct(with_syn, total):.0f}%) | — | — |",
        f"| 기초사전만 / 표준만 / 양쪽 | {only_kr:,} / {only_st:,} / {both:,} | — | — |",
        f"| 빈도 매칭 | {freq:,} ({freq_pct:.0f}%) | ≥ {config.CHECK_MIN_FREQ_MATCH_PCT}% |"
        f" {_verdict(freq_pct >= config.CHECK_MIN_FREQ_MATCH_PCT)} |",
        f"| license_notice | {meta.get('license_notice', '?')} | — | — |",
        "",
    ]


def _tier_by_length(con, total: int) -> list[str]:
    grid = {(t, n): 0 for t in range(1, config.TIER_COUNT + 1) for n in _LEN_COLS}
    other = 0
    for tier, length, n in con.execute(
            "SELECT tier, len, COUNT(*) FROM word GROUP BY tier, len"):
        if (tier, length) in grid:
            grid[(tier, length)] += n
        else:
            other += n

    head = " | ".join(f"{n}음절" for n in _LEN_COLS)
    lines = [
        "## 티어 × 길이 분포",
        "",
        f"| 티어 | {head} | 합 | 비율 | 목표 |",
        "|---|" + "---|" * (len(_LEN_COLS) + 3),
    ]
    col_sum = {n: 0 for n in _LEN_COLS}
    for t in range(1, config.TIER_COUNT + 1):
        cells = [grid[(t, n)] for n in _LEN_COLS]
        for n, c in zip(_LEN_COLS, cells):
            col_sum[n] += c
        row_total = sum(cells)
        body = " | ".join(f"{c:,}" for c in cells)
        lines.append(f"| {t} | {body} | {row_total:,} | {_pct(row_total, total):.1f}% |"
                     f" {config.TIER_RATIO[t - 1]}% |")
    body = " | ".join(f"{col_sum[n]:,}" for n in _LEN_COLS)
    lines.append(f"| 합 | {body} | {sum(col_sum.values()):,} | 100.0% | 100% |")
    if other:
        lines.append("")
        lines.append(f"> 위 표에 들어가지 않은 행 {other:,}개 — 티어 1~{config.TIER_COUNT} 또는"
                     f" 길이 {config.MIN_LEN}~{config.MAX_LEN} 범위 밖이다."
                     " `python -m tools check` 가 실패로 잡는다.")
    lines.append("")
    return lines


def _syllable_coverage(con) -> list[str]:
    """3단계 격자 생성 실패율의 선행 지표 (02-10 "음절 커버리지를 재는 이유")."""
    uniq = _one(con, "SELECT COUNT(DISTINCT ch) FROM word_char")
    top = con.execute(
        "SELECT ch, COUNT(*) AS n FROM word_char GROUP BY ch"
        " ORDER BY n DESC, ch LIMIT ?", (TOP_SYLLABLES,)).fetchall()
    once = _one(con, "SELECT COUNT(*) FROM (SELECT ch FROM word_char"
                     " GROUP BY ch HAVING COUNT(*) = 1)")
    low_tier = _one(con, "SELECT COUNT(DISTINCT ch) FROM word_char JOIN word"
                         " USING (headword) WHERE tier <= 3")

    return [
        "## 음절 커버리지 (격자 생성 난이도의 선행 지표)",
        "",
        "| 항목 | 값 |",
        "|---|---|",
        f"| 고유 음절 수 | {uniq:,} |",
        f"| 가장 흔한 음절 {TOP_SYLLABLES}개 | "
        + (", ".join(f"{ch}({n:,})" for ch, n in top) or "—") + " |",
        f"| 한 번만 등장하는 음절 | {once:,}개 |",
        f"| 티어 1~3 단어의 고유 음절 수 | {low_tier:,} |",
        "",
        f"한 번만 등장하는 음절이 많을수록 그 음절이 격자에 들어가는 순간 교차가 막힌다"
        f" (REVIEW 4.3). 03-05 실측 결과를 여기 숫자와 나란히 놓고 볼 것.",
        "",
    ]


def _samples(con) -> list[str]:
    """티어별 랜덤 샘플. seed 고정이라 조정 전후를 비교할 수 있다."""
    rnd = random.Random(SEED)
    lines = [f"## 티어별 랜덤 샘플 {SAMPLE_PER_TIER}개", ""]
    labels = {1: " (가장 쉬움)", config.TIER_COUNT: " (가장 어려움)"}
    for t in range(1, config.TIER_COUNT + 1):
        pool = [r[0] for r in con.execute(
            "SELECT headword FROM word WHERE tier = ? ORDER BY headword", (t,))]
        lines.append(f"### 티어 {t}{labels.get(t, '')}")
        if not pool:
            lines += ["", "(없음)", ""]
            continue
        if len(pool) > SAMPLE_PER_TIER:
            picked = rnd.sample(pool, SAMPLE_PER_TIER)
            note = ""
        else:
            picked = pool
            note = f" (티어 전체 {len(pool)}개)"
        lines += ["", ", ".join(picked) + note, ""]
    return lines


def _human_review() -> list[str]:
    """02-10 "리포트 내용" 의 체크리스트. **답은 사람이 적는다** — 비워 둔 채로 낸다."""
    return [
        "## 눈 검수 결과 (사람이 작성)",
        "",
        "- [ ] 1티어에 어려운 단어가 있는가? →",
        "- [ ] 7티어에 쉬운 단어가 있는가? →",
        "- [ ] 고유명사가 섞여 있는가? →",
        "- [ ] 방언·옛말·전문어가 섞여 있는가? →",
        "- [ ] 뜻풀이가 잘려서 뜻이 안 통하는 게 있는가? →",
        "- [ ] 게임에 쓰기 부적절한 단어(비속어·혐오·성적 표현)가 있는가? →",
        "",
        "### 조치",
        "",
        "(산식 조정이 필요하면 여기에 기록하고 config.py 수정 → 재빌드."
        " 손잡이와 재실행 범위는 02-10 \"눈 검수 절차\" 표에 있다.)",
        "",
        "> 이 절은 사람이 쓴다. `python -m tools report` 를 다시 돌리면 지워지므로,"
        " 재생성 후에는 다시 채워 넣는다.",
    ]


# --- 기계 검사 ---------------------------------------------------------------

def check(db: Path | None = None) -> bool:
    """`python -m tools check` — 실패 건수를 찍고 종료 코드용 bool 을 돌려준다."""
    db = db or _db_path()
    if not db.exists():
        return _report_problems([f"words.sqlite 없음: {_rel(db)}"])

    con = sqlite3.connect(db)
    try:
        problems = _problems(con, db)
    finally:
        con.close()
    return _report_problems(problems)


def _report_problems(problems: list[str]) -> bool:
    # 골격은 `✗` 를 쓰지만 cp949 콘솔에서 인코딩이 터진다. cp949 에 있는 `×` 로 바꾼다
    # (02-06·02-07·02-09 에서 이미 같은 이유로 정해 둔 규칙).
    for p in problems:
        print(f"  × {p}")
    print("check: OK" if not problems else f"check: {len(problems)}건 실패")
    return not problems


def _problems(con: sqlite3.Connection, db: Path) -> list[str]:
    """02-10 "`python -m tools check`" 표의 검사 목록. 순서도 표 그대로."""
    out: list[str] = []
    meta = _meta(con)
    total = _one(con, "SELECT COUNT(*) FROM word")

    size_mb = db.stat().st_size / 1024 / 1024
    if size_mb > SIZE_LIMIT_MB:
        out.append(f"용량 {size_mb:.1f} MB > {SIZE_LIMIT_MB} MB")

    # 단어 수·티어 분포는 **규모에 딸린 검사**다. 샘플 16행에서는 한 행이 6.25%p 라
    # 산술적으로 통과가 불가능하고, 1,000행이면 정확히 떨어진다 (README 02-08
    # "티어 비율 ±1% 는 16행에서 성립하지 않는다"). 그래서 02-08·02-09 가 이미 쓴 방식을
    # 그대로 따른다 — 합성 1,000행 테스트로 강제하고, 샘플 빌드에서는 건너뛴다.
    # 건너뛰는 조건은 DB 안 `meta.source_versions.origin == "fixtures"` 뿐이라
    # 실데이터 빌드(CI, 06-06)에서는 언제나 검사한다.
    if _is_fixture(meta):
        # 대시는 `—`(U+2014) 가 아니라 `―`(U+2015) 다. U+2014 는 cp949 에 없어서 CI(06-06)
        # 처럼 콘솔이 cp949 인 곳에서 이 print 가 UnicodeEncodeError 로 죽는다
        # (`_report_problems` 가 `✗` 대신 `×` 를 쓰는 것과 같은 이유).
        print("  - 샘플 빌드(origin=fixtures): 규모 검사(단어 수·티어 분포) 건너뜀"
              " ― tools/README.md 02-10 참조")
    else:
        if total < config.CHECK_MIN_WORDS:
            out.append(f"단어 수 {total:,} < {config.CHECK_MIN_WORDS:,}")
        out += _tier_ratio_problems(con, total)

    bad_tier = _one(con, "SELECT COUNT(*) FROM word WHERE tier NOT BETWEEN 1 AND ?",
                    (config.TIER_COUNT,))
    if bad_tier:
        out.append(f"티어 범위 밖 {bad_tier:,}행 (1~{config.TIER_COUNT})")

    bad_len = _one(con, "SELECT COUNT(*) FROM word WHERE len NOT BETWEEN ? AND ?",
                   (config.MIN_LEN, config.MAX_LEN))
    if bad_len:
        out.append(f"길이 범위 밖 {bad_len:,}행 ({config.MIN_LEN}~{config.MAX_LEN})")

    bad_hw = [hw for (hw,) in con.execute("SELECT headword FROM word")
              if not is_all_hangul(hw)]
    if bad_hw:
        out.append(f"완성형 한글이 아닌 표제어 {len(bad_hw):,}개: "
                   + ", ".join(bad_hw[:3]))

    orphan = _one(con, "SELECT COUNT(*) FROM sense"
                       " WHERE headword NOT IN (SELECT headword FROM word)")
    if orphan:
        out.append(f"word 에 없는 sense.headword {orphan:,}행 (FK)")

    stat = _one(con, "SELECT COUNT(*) FROM word_stat")
    if stat:
        out.append(f"word_stat 이 비어 있지 않음 {stat:,}행 (앱이 채운다, ETL 아님)")

    missing = [k for k in META_KEYS if not meta.get(k)]
    if missing:
        out.append("meta 누락: " + ", ".join(missing))

    bad_def = _one(con, "SELECT COUNT(*) FROM sense"
                        " WHERE LENGTH(definition) > ? OR TRIM(definition) = ''",
                   (config.DEFINITION_MAX_CHARS,))
    if bad_def:
        out.append(f"뜻풀이 길이 컷 초과 또는 빈 문자열 {bad_def:,}행"
                   f" (컷 {config.DEFINITION_MAX_CHARS})")
    return out


def _tier_ratio_problems(con, total: int) -> list[str]:
    counts = dict(con.execute("SELECT tier, COUNT(*) FROM word GROUP BY tier"))
    out = []
    for t, target in enumerate(config.TIER_RATIO, 1):
        pct = _pct(counts.get(t, 0), total)
        if abs(pct - target) > config.CHECK_TIER_TOLERANCE_PP:
            out.append(f"티어 {t} 비율 {pct:.1f}% (목표 {target}%,"
                       f" 허용 ±{config.CHECK_TIER_TOLERANCE_PP}%p)")
    return out
