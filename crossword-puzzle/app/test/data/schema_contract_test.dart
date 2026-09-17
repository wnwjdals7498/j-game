// sqlite3 패키지로 파일을 직접 열어 스키마만 비교 (Flutter 런타임 불필요)
import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Database db;
  late bool isFixture;

  setUpAll(() {
    db = sqlite3.open('assets/words.sqlite', mode: OpenMode.readOnly);
    // tools/report.py `_is_fixture()` 와 같은 판정: meta.source_versions.origin
    // 이 "fixtures" 면 이 DB 는 00-01(실사전 데이터) 승인 대기 중 만든 샘플이라
    // 데이터 규모(단어 수) 검사가 산술적으로 통과 불가능하다 (tools/README.md 02-10 참조).
    final rows =
        db.select("SELECT value FROM meta WHERE key = 'source_versions'");
    isFixture = false;
    if (rows.isNotEmpty) {
      try {
        final parsed = jsonDecode(rows.first['value'] as String);
        isFixture = parsed is Map && parsed['origin'] == 'fixtures';
      } catch (_) {
        isFixture = false;
      }
    }
  });
  tearDownAll(() => db.close());

  test('필수 테이블이 전부 있다', () {
    final names = db
        .select("SELECT name FROM sqlite_master WHERE type='table'")
        .map((r) => r['name'] as String)
        .toSet();
    expect(names, containsAll(
        ['word', 'sense', 'word_char', 'word_stat', 'meta']));
  });

  test('word 컬럼이 schema.sql과 일치', () {
    final cols = db.select('PRAGMA table_info(word)')
        .map((r) => r['name'] as String).toList();
    expect(cols, [
      'headword', 'len', 'c1', 'c2', 'c3', 'c4', 'c5',
      'tier', 'pos', 'freq_rank', 'source',
    ]);
  });

  test('패턴 질의 인덱스가 있다', () {
    final idx = db
        .select("SELECT name FROM sqlite_master WHERE type='index'")
        .map((r) => r['name'] as String).toSet();
    expect(idx, containsAll(
        ['idx_word_c1', 'idx_word_c2', 'idx_word_c3',
         'idx_word_c4', 'idx_word_c5', 'idx_sense_headword']));
  });

  test('meta 필수 키가 있다', () {
    final keys = db.select('SELECT key FROM meta')
        .map((r) => r['key'] as String).toSet();
    expect(keys, containsAll([
      'schema_version', 'db_version', 'built_at',
      'word_count', 'source_versions', 'license_notice',
    ]));
  });

  test('word_stat은 비어 있다', () {
    expect(db.select('SELECT COUNT(*) AS n FROM word_stat').first['n'], 0);
  });

  test('패턴 질의가 인덱스를 탄다', () {
    final plan = db.select(
      'EXPLAIN QUERY PLAN SELECT headword FROM word '
      'WHERE len=? AND tier IN (1,2) AND c2=?', [3, '가']);
    final text = plan.map((r) => r.values.join(' ')).join(' ');
    expect(text, contains('idx_word_c'), reason: '인덱스 미사용: $text');
  });

  test('데이터 sanity', () {
    final n = db.select('SELECT COUNT(*) AS n FROM word').first['n'] as int;
    if (isFixture) {
      // tools/report.py check() 와 동일한 근거로 규모 검사만 건너뛴다 — 티어·길이
      // 범위 검사는 규모와 무관하므로 fixtures 에서도 그대로 돌린다. 여기서
      // return 하지 않고 계속 진행해 아래 두 expect 는 그대로 돈다.
      markTestSkipped(
          '샘플 빌드(origin=fixtures): 단어 수 규모 검사 건너뜀 ― tools/README.md 02-10 참조');
    } else {
      expect(n, greaterThan(1000));
    }
    expect(db.select(
        'SELECT COUNT(*) AS n FROM word WHERE tier < 1 OR tier > 7')
        .first['n'], 0);
    expect(db.select(
        'SELECT COUNT(*) AS n FROM word WHERE len < 2 OR len > 5')
        .first['n'], 0);
  });
}
