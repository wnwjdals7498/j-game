// DbSwapper(05-03) 테스트.
//
// `tools/schema.sql`(단일 진실)로 기존/새 DB fixture를 만든다 — bootstrap_test.dart
// (03-02)·stat_repository_test.dart(03-04)와 같은 패턴이라 계약이 바뀌면 이
// 테스트도 자동으로 따라간다.
//
// `.bak` 복구(문서 "테스트" 표 11번째 행)는 이 파일이 아니라
// `bootstrap_test.dart`에 있다 — 그 로직(`recoverOrCopySeed`)이
// `open_native.dart`(data/db)에 있어서다. `reseedFromAsset`은 `rootBundle`이
// 필요해 `flutter_test` 없이는 못 부르므로(수동 검증만 가능), 여기서는 그
// 뼈대인 `swap()`만 단위 테스트한다 — `reseedFromAsset`은 `swap()`을 그대로
// 호출하므로 `swap()`이 맞으면 로직은 검증된 것이다.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:jgame/data/db/app_database.dart';
import 'package:jgame/data/sync/db_swapper.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

late final String _schemaSql;

void main() {
  late Directory tmp;

  setUpAll(() {
    _schemaSql = File('../tools/schema.sql').readAsStringSync();
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('db_swapper_test_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  AppDatabase open(File f) => AppDatabase(NativeDatabase(f));

  /// [dbVersion]·단어들로 유효한 words.sqlite를 만든다. [tables]로 특정
  /// 테이블을 아예 뺄 수 있다(구 버전 DB 흉내).
  File makeDb(
    String name, {
    int dbVersion = 1,
    List<String> words = const ['가나'],
    List<({String headword, int correct, int wrong})> statRows = const [],
    List<({int levelId, int seed, int firstScore})> puzzleLogRows = const [],
    bool includePuzzleLog = true,
  }) {
    final path = '${tmp.path}/$name.sqlite';
    final raw = sqlite3.open(path);
    final schema = includePuzzleLog
        ? _schemaSql
        : _schemaSql.replaceAll(
            RegExp(r'CREATE TABLE puzzle_log[\s\S]*?\);'), '');
    raw.execute(schema);
    raw.execute(
        "INSERT INTO meta(key, value) VALUES ('db_version', '$dbVersion')");
    raw.execute(
        "INSERT INTO meta(key, value) VALUES ('schema_version', '1')");
    for (final w in words) {
      raw.execute('''
        INSERT INTO word(headword, len, c1, c2, tier, pos, source)
        VALUES ('$w', 2, '${w[0]}', '${w[1]}', 1, 'NNG', 1)
      ''');
    }
    for (final s in statRows) {
      raw.execute(
          'INSERT INTO word_stat(headword, correct, wrong) VALUES (?,?,?)',
          [s.headword, s.correct, s.wrong]);
    }
    if (includePuzzleLog) {
      for (final p in puzzleLogRows) {
        raw.execute(
            'INSERT INTO puzzle_log(level_id, seed, first_score, submitted_at) '
            'VALUES (?,?,?,0)',
            [p.levelId, p.seed, p.firstScore]);
      }
    }
    raw.close();
    return File(path);
  }

  DbSwapper swapper(File currentFile) =>
      DbSwapper(open: open, currentFile: currentFile);

  test('word_stat 보존: 행 수·값 동일', () async {
    final currentFile = makeDb('current', statRows: [
      (headword: '가나', correct: 3, wrong: 1),
      (headword: '다라', correct: 0, wrong: 2),
    ]);
    final current = AppDatabase(NativeDatabase(currentFile));
    final newDb = makeDb('new', dbVersion: 2);

    final next = await swapper(currentFile).swap(current, newDb);
    addTearDown(next.close);

    final rows = await (next.select(next.wordStats)
          ..orderBy([(t) => OrderingTerm(expression: t.headword)]))
        .get();
    expect(rows.map((r) => (r.headword, r.correct, r.wrong)), [
      ('가나', 3, 1),
      ('다라', 0, 2),
    ]);
  });

  test('puzzle_log 보존: 행 수·값 동일', () async {
    final currentFile = makeDb('current', puzzleLogRows: [
      (levelId: 1, seed: 10, firstScore: 5),
      (levelId: 2, seed: 20, firstScore: -1),
    ]);
    final current = AppDatabase(NativeDatabase(currentFile));
    final newDb = makeDb('new', dbVersion: 2);

    final next = await swapper(currentFile).swap(current, newDb);
    addTearDown(next.close);

    final rows = await (next.select(next.puzzleLogs)
          ..orderBy([(t) => OrderingTerm(expression: t.levelId)]))
        .get();
    expect(rows.map((r) => (r.levelId, r.seed, r.firstScore)), [
      (1, 10, 5),
      (2, 20, -1),
    ]);
  });

  test('새 DB에 없는 단어의 stat도 보존됨', () async {
    final currentFile =
        makeDb('current', words: const ['옛단어'], statRows: [
      (headword: '옛단어', correct: 1, wrong: 0),
    ]);
    final current = AppDatabase(NativeDatabase(currentFile));
    // 새 DB에는 '옛단어'가 없다 — 사전 갱신으로 표제어가 빠진 경우.
    final newDb = makeDb('new', dbVersion: 2, words: const ['새단어']);

    final next = await swapper(currentFile).swap(current, newDb);
    addTearDown(next.close);

    final stat = await (next.select(next.wordStats)
          ..where((t) => t.headword.equals('옛단어')))
        .getSingle();
    expect(stat.correct, 1);
    final words = await next.select(next.words).get();
    expect(words.map((w) => w.headword), ['새단어'],
        reason: 'word 테이블은 새 DB 것만 있어야 한다 — 옛단어는 word_stat에만 남는다');
  });

  test('새 DB 내용 반영: word 행이 새 DB 것', () async {
    final currentFile = makeDb('current', words: const ['옛단어']);
    final current = AppDatabase(NativeDatabase(currentFile));
    final newDb = makeDb('new', dbVersion: 2, words: const ['새단어1', '새단어2']);

    final next = await swapper(currentFile).swap(current, newDb);
    addTearDown(next.close);

    final words = await next.select(next.words).get();
    expect(words.map((w) => w.headword).toSet(), {'새단어1', '새단어2'});
  });

  test('meta는 새 것: db_version이 새 값', () async {
    final currentFile = makeDb('current', dbVersion: 1);
    final current = AppDatabase(NativeDatabase(currentFile));
    final newDb = makeDb('new', dbVersion: 7);

    final next = await swapper(currentFile).swap(current, newDb);
    addTearDown(next.close);

    expect(await next.metaValue('db_version'), '7');
  });

  test('원자 교체: 교체 후 words.sqlite(currentFile)가 새 DB 내용', () async {
    final currentFile = makeDb('current', dbVersion: 1);
    final current = AppDatabase(NativeDatabase(currentFile));
    final newDb = makeDb('new', dbVersion: 9, words: const ['확인단어']);

    final next = await swapper(currentFile).swap(current, newDb);
    addTearDown(next.close);

    // currentFile 경로 자체를 다시 열어도 새 내용이어야 한다 (rename 확인).
    final reopened = AppDatabase(NativeDatabase(currentFile));
    addTearDown(reopened.close);
    expect(await reopened.metaValue('db_version'), '9');
  });

  test('임시 파일 정리: 성공 후 .bak이 남지 않음', () async {
    final currentFile = makeDb('current');
    final current = AppDatabase(NativeDatabase(currentFile));
    final newDb = makeDb('new', dbVersion: 2);

    final next = await swapper(currentFile).swap(current, newDb);
    addTearDown(next.close);

    expect(File('${currentFile.path}.bak').existsSync(), isFalse);
  });

  test('교체 실패 롤백: rename 실패 시 기존 DB 무손상', () async {
    final currentFile = makeDb('current', dbVersion: 1, statRows: [
      (headword: '가나', correct: 5, wrong: 0),
    ]);
    final current = AppDatabase(NativeDatabase(currentFile));
    final newDb = makeDb('new', dbVersion: 2);
    // newDb를 배타적으로 열어 둔 채로 rename을 시도한다 — Windows에서는 열린
    // 파일을 rename할 수 없어 반드시 실패한다(존재하지 않는 파일을 주면
    // _copyPreservedTables 단계에서 먼저 죽어, 이 테스트가 검증하려는
    // rename/롤백 코드 자체에 도달하지 못한다). POSIX는 열린 파일도 rename할
    // 수 있어 이 트릭이 안 통한다 — 이 저장소는 Windows 개발 환경 기준이라
    // 지금은 여기서만 돈다.
    final lock = newDb.openSync(mode: FileMode.append);
    addTearDown(lock.closeSync);

    await expectLater(
      swapper(currentFile).swap(current, newDb),
      throwsA(anything),
    );

    // 기존 DB는 백업에서 복구돼 그대로 살아 있어야 한다.
    expect(File('${currentFile.path}.bak').existsSync(), isFalse,
        reason: '롤백되면 백업은 원래 자리로 돌아가 사라진다');
    final reopened = AppDatabase(NativeDatabase(currentFile));
    addTearDown(reopened.close);
    expect(await reopened.metaValue('db_version'), '1');
    final stat = await (reopened.select(reopened.wordStats)
          ..where((t) => t.headword.equals('가나')))
        .getSingle();
    expect(stat.correct, 5);
  }, skip: !Platform.isWindows);

  test('새 DB를 연 뒤 wordCount 확인 실패 → 롤백 (close 누락 회귀 방지)',
      () async {
    final currentFile = makeDb('current', dbVersion: 1, statRows: [
      (headword: '가나', correct: 9, wrong: 0),
    ]);
    final current = AppDatabase(NativeDatabase(currentFile));
    final newDb = makeDb('new', dbVersion: 2);

    // rename까지는 정상 진행시키고, "새로 연 DB가 정상인지 확인"(6단계)
    // 단계에서만 실패를 유도한다 — currentFile을 열 때만 SQLite가 아닌
    // 파일을 대신 열게 한다. 롤백이 next를 close()하지 않으면(회귀) 그
    // 다음 currentFile.delete()/backup.rename()이 Windows에서 조용히
    // 실패해 이 테스트가 잡아낸다.
    final garbage = File('${tmp.path}/garbage.sqlite')
      ..writeAsStringSync('이건 SQLite 파일이 아니다');
    AppDatabase poisonedOpen(File f) => AppDatabase(NativeDatabase(
        f.path == currentFile.path ? garbage : f));
    final swapper = DbSwapper(open: poisonedOpen, currentFile: currentFile);

    await expectLater(
      swapper.swap(current, newDb),
      throwsA(anything),
    );

    expect(File('${currentFile.path}.bak').existsSync(), isFalse,
        reason: '롤백되면 백업은 원래 자리로 돌아가 사라진다');
    final reopened = AppDatabase(NativeDatabase(currentFile));
    addTearDown(reopened.close);
    expect(await reopened.metaValue('db_version'), '1');
    final stat = await (reopened.select(reopened.wordStats)
          ..where((t) => t.headword.equals('가나')))
        .getSingle();
    expect(stat.correct, 9);
  });

  test('기존 DB에 puzzle_log 없음(구 버전) → 예외 없이 진행', () async {
    final currentFile = makeDb('current', includePuzzleLog: false);
    final current = AppDatabase(NativeDatabase(currentFile));
    final newDb = makeDb('new', dbVersion: 2);

    final next = await swapper(currentFile).swap(current, newDb);
    addTearDown(next.close);

    expect(await next.wordCount, greaterThan(0));
  });

  test('복사 중 실패: 기존 DB 무손상, 새 DB 파일은 삭제 가능한 상태로 남음',
      () async {
    final currentFile = makeDb('current', dbVersion: 1);
    final current = AppDatabase(NativeDatabase(currentFile));
    // "테이블 있음" 확인은 old(=기존 DB currentFile)의 sqlite_master만 본다 —
    // 새 DB(main) 쪽은 확인하지 않는다. 그래서 word_stat 테이블 자체가 없는
    // "새 DB"를 주면: ATTACH는 성공하고, old.word_stat이 있으니 존재 확인도
    // 통과하지만, 그 다음 `DELETE FROM main.word_stat`이 main(새 DB)에
    // word_stat이 없어서 실패한다 — INSERT까지는 가지 않는다.
    final brokenNewPath = '${tmp.path}/broken.sqlite';
    final raw = sqlite3.open(brokenNewPath);
    raw.execute("CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT)");
    raw.execute("INSERT INTO meta VALUES ('db_version', '2')");
    raw.close();
    final brokenNewDb = File(brokenNewPath);

    await expectLater(
      swapper(currentFile).swap(current, brokenNewDb),
      throwsA(anything),
    );

    // 기존 DB(살아있는 연결)는 건드려지지 않았어야 한다 — 아직 열려 있다.
    expect(await current.wordCount, greaterThan(0));
    addTearDown(current.close);
    // 새 DB 파일은 (내부에서 연결을 열었다 닫았으므로) 삭제할 수 있어야 한다.
    expect(() => brokenNewDb.deleteSync(), returnsNormally);
  });

  test('컬럼 명시: word_stat 컬럼 순서가 달라도 정확히 복사', () async {
    // 기존 DB의 word_stat을 스키마와 다른 컬럼 순서로 다시 만든다.
    final currentPath = '${tmp.path}/current_reordered.sqlite';
    final raw = sqlite3.open(currentPath);
    raw.execute(_schemaSql);
    raw.execute("INSERT INTO meta(key, value) VALUES ('db_version', '1')");
    raw.execute("INSERT INTO meta(key, value) VALUES ('schema_version', '1')");
    raw.execute('DROP TABLE word_stat');
    // 컬럼 순서를 뒤집어 다시 만든다: last_seen, wrong, correct, headword.
    raw.execute('''
      CREATE TABLE word_stat (
        last_seen INTEGER,
        wrong INTEGER NOT NULL DEFAULT 0,
        correct INTEGER NOT NULL DEFAULT 0,
        headword TEXT PRIMARY KEY
      )
    ''');
    raw.execute(
        "INSERT INTO word_stat (last_seen, wrong, correct, headword) "
        "VALUES (999, 2, 7, '가나')");
    raw.close();
    final currentFile = File(currentPath);
    final current = AppDatabase(NativeDatabase(currentFile));
    final newDb = makeDb('new', dbVersion: 2);

    final next = await swapper(currentFile).swap(current, newDb);
    addTearDown(next.close);

    final stat = await (next.select(next.wordStats)
          ..where((t) => t.headword.equals('가나')))
        .getSingle();
    // SELECT *였다면 컬럼이 뒤섞여 headword 자리에 999(last_seen 값)가 들어가는
    // 등 완전히 틀린 값이 들어왔을 것이다. 컬럼을 명시했으므로 정확하다.
    expect(stat.correct, 7);
    expect(stat.wrong, 2);
    expect(stat.lastSeen, 999);
  });

  test('컬럼 목록 카나리아: db_swapper.dart의 하드코딩된 컬럼이 schema.sql과 일치',
      () {
    // db_swapper.dart._insertPreserved의 INSERT 문에 박아 둔 컬럼 목록은
    // 코드로 schema.sql을 읽지 않는다 — 스키마가 바뀌어도 컴파일도 테스트도
    // 조용히 통과하고 새 컬럼만 복사가 누락된다(같은 값으로 기본값이 채워질
    // 뿐이라 실패가 안 보인다). 이 테스트가 그 침묵을 깬다: schema.sql의
    // 실제 컬럼과 여기 하드코딩한 기대값이 어긋나면 여기서 먼저 빨갛게
    // 터진다 — db_swapper.dart의 두 INSERT문도 같이 고치라는 신호다.
    final path = '${tmp.path}/schema_columns.sqlite';
    final raw = sqlite3.open(path);
    addTearDown(raw.close); // expect가 먼저 터져도 핸들이 새지 않게 한다

    raw.execute(_schemaSql);

    List<String> columnsOf(String table) => raw
        .select('PRAGMA table_info($table)')
        .map((r) => r['name'] as String)
        .toList();

    expect(columnsOf('word_stat'), ['headword', 'correct', 'wrong', 'last_seen']);
    expect(columnsOf('puzzle_log'),
        ['level_id', 'seed', 'first_score', 'submitted_at']);
  });
}
