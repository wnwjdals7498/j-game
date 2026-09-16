"""02-10 리포트·check 테스트.

케이스는 02-10 "테스트" 절 표 6종(리포트 렌더 · 샘플 재현성 · check 통과 ·
티어 8 · 비한글 표제어 · word_stat 행)을 그대로 옮긴 것이고, 여기에 **규모 검사**의
양방향 회귀 2종을 더했다 (`origin=fixtures` 면 건너뛰고 `raw` 면 강제한다).

정상 DB 는 **합성 1,000행**이다. 손수 만든 샘플 16행으로는 `단어 수 >= 1,000` 과
티어 비율 ±2%p 를 산술적으로 만족시킬 수 없다 (한 행이 6.25%p — README 02-08
"티어 비율 ±1% 는 16행에서 성립하지 않는다"). 02-08·02-09 가 쓴 방식과 같다.
"""
import sqlite3

import pytest

from tools import config, io_util, report
from tools.build_sqlite import IN, OUT, run

NORMAL_N = 1000          # TIER_RATIO 가 250/220/180/140/100/70/40 으로 정확히 떨어진다


def _headword(i: int, length: int) -> str:
    """i 마다 다른 완성형 한글 표제어. 앞 두 음절이 i 를 인코딩해 충돌이 없다."""
    syl = [chr(0xAC00 + i // 100), chr(0xAC00 + i % 100)]
    syl += [chr(0xAC00 + (i * 7 + j * 131) % 11172) for j in range(length - 2)]
    return "".join(syl)


def _row(headword: str, tier: int, freq_rank=None, source=config.SRC_KRDICT,
         definition="뜻풀이.", synonyms=()) -> dict:
    return {
        "headword": headword, "len": len(headword), "syllables": list(headword),
        "pos": "명사", "source": source, "freq_rank": freq_rank,
        "vocab_grade": None, "in_krdict": bool(source & config.SRC_KRDICT),
        "score": 0.5, "tier": tier,
        "senses": [{"sense_id": f"s:{headword}", "definition": definition,
                    "synonyms": list(synonyms), "source": source}],
    }


def _tiers(n: int) -> list[int]:
    """score.assign_tiers 와 같은 bounds 로 티어를 미리 배정한다."""
    out, prev, acc = [], 0, 0
    for t, ratio in enumerate(config.TIER_RATIO, 1):
        acc += ratio
        end = round(n * acc / 100)
        out += [t] * (end - prev)
        prev = end
    return out + [config.TIER_COUNT] * (n - len(out))


def _rows(n: int) -> list[dict]:
    tiers = _tiers(n)
    return [_row(_headword(i, 2 + i % 4), tiers[i],
                 freq_rank=(i + 1) if i % 2 == 0 else None,
                 source=config.SRC_KRDICT | config.SRC_STDICT if i % 3 == 0
                 else config.SRC_KRDICT,
                 synonyms=["비슷한말"] if i % 5 == 0 else ())
            for i in range(n)]


def _build(tmp_path, monkeypatch, rows, use_fixtures=False):
    build = tmp_path / "build"
    build.mkdir(parents=True, exist_ok=True)
    monkeypatch.setattr(config, "BUILD", build)
    io_util.write_jsonl(build / IN, rows)
    assert run(use_fixtures=use_fixtures) == len(rows)
    return build / OUT


@pytest.fixture
def normal_db(tmp_path, monkeypatch):
    """실데이터 규모를 흉내 낸 정상 DB (origin=raw → 규모 검사가 실제로 돈다)."""
    return _build(tmp_path, monkeypatch, _rows(NORMAL_N))


def _execute(db, sql, args=()):
    con = sqlite3.connect(db)
    try:
        con.execute(sql, args)
        con.commit()
    finally:
        con.close()


# --- 02-10 "테스트" 표 ---

def test_report_has_every_tier_row(normal_db, tmp_path):
    """리포트 렌더: 마크다운에 모든 티어 행이 있다 (분포 표 + 샘플 절)."""
    out = tmp_path / "02-db-report.md"
    report.render(db=normal_db, out=out)
    text = out.read_text(encoding="utf-8")

    for t in range(1, config.TIER_COUNT + 1):
        assert f"\n| {t} | " in text, f"티어 {t} 분포 행 없음"
        assert f"### 티어 {t}" in text, f"티어 {t} 샘플 절 없음"
    assert "## 요약" in text and "## 음절 커버리지" in text
    assert "## 눈 검수 결과 (사람이 작성)" in text
    assert "(가장 쉬움)" in text and "(가장 어려움)" in text


def test_sample_is_reproducible(normal_db, tmp_path):
    """샘플 재현성: seed 고정이라 두 번 렌더하면 같은 문서가 나온다."""
    a, b = tmp_path / "a.md", tmp_path / "b.md"
    report.render(db=normal_db, out=a)
    report.render(db=normal_db, out=b)
    assert a.read_text(encoding="utf-8") == b.read_text(encoding="utf-8")
    assert report.SEED == 20260916


def test_check_passes_on_normal_db(normal_db):
    """check 통과: 정상 DB → True (종료 코드 0)."""
    assert report.check(db=normal_db) is True


def test_check_detects_bad_tier(normal_db):
    """check 실패 탐지: 티어 8을 심은 DB → False."""
    _execute(normal_db,
             "INSERT INTO word (headword, len, c1, c2, tier, pos, source)"
             " VALUES ('가짜말', 3, '가', '짜', 8, '명사', 1)")
    assert report.check(db=normal_db) is False


def test_check_detects_non_hangul_headword(normal_db):
    """check 실패 탐지: 비한글 표제어를 심은 DB → False."""
    _execute(normal_db,
             "INSERT INTO word (headword, len, c1, c2, tier, pos, source)"
             " VALUES ('ab말', 3, 'a', 'b', 1, '명사', 1)")
    assert report.check(db=normal_db) is False


def test_check_detects_word_stat_rows(normal_db):
    """check 실패 탐지: word_stat 에 행을 심은 DB → False (ETL 은 빈 테이블만 만든다)."""
    _execute(normal_db,
             "INSERT INTO word_stat (headword, correct, wrong)"
             " SELECT headword, 1, 0 FROM word LIMIT 1")
    assert report.check(db=normal_db) is False


# --- 규모 검사 (샘플/실데이터 양방향) ---

def test_check_skips_scale_checks_on_fixture_db(tmp_path, monkeypatch):
    """샘플 빌드(origin=fixtures)는 단어 수·티어 분포를 건너뛴다."""
    db = _build(tmp_path, monkeypatch, _rows(16), use_fixtures=True)
    assert report.check(db=db) is True


def test_check_enforces_scale_checks_on_raw_db(tmp_path, monkeypatch):
    """실데이터 빌드(origin=raw)라면 같은 16행이 실패한다 — CI(06-06)가 이 쪽이다."""
    db = _build(tmp_path, monkeypatch, _rows(16))
    assert report.check(db=db) is False


def test_check_reports_missing_db(tmp_path, monkeypatch):
    """파일 존재: words.sqlite 가 없으면 False."""
    monkeypatch.setattr(config, "BUILD", tmp_path)
    assert report.check() is False


def test_check_output_encodes_to_cp949(tmp_path, monkeypatch, capsys):
    """check 가 찍는 글자는 전부 cp949 에 있어야 한다.

    CI(06-06)가 `python -m tools check` 를 cp949 콘솔에서 돌린다. 여기 벗어난 글자가
    하나라도 섞이면 stdout 이 UnicodeEncodeError 로 죽어 종료 코드가 1 이 된다
    (`—` U+2014 로 실제 터졌던 자리 — `―` U+2015 나 `×` 처럼 cp949 에 있는 글자만 쓴다).
    통과 경로(샘플 빌드의 건너뜀 안내)와 실패 경로(문제 목록)를 둘 다 훑는다.
    """
    ok_db = _build(tmp_path / "ok", monkeypatch, _rows(16), use_fixtures=True)
    assert report.check(db=ok_db) is True
    bad_db = _build(tmp_path / "bad", monkeypatch, _rows(16))
    assert report.check(db=bad_db) is False

    out = capsys.readouterr().out
    assert out.strip(), "check 가 아무것도 찍지 않았다"
    out.encode("cp949")      # 실패하면 UnicodeEncodeError 로 이 테스트가 깨진다


def test_render_requires_db(tmp_path, monkeypatch):
    """DB 가 없으면 리포트는 빈 문서를 내지 않고 멈춘다."""
    monkeypatch.setattr(config, "BUILD", tmp_path)
    with pytest.raises(FileNotFoundError):
        report.render(out=tmp_path / "r.md")
