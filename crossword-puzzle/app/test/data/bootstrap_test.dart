// db_bootstrap(03-02) 테스트. 네이티브 경로만 다룬다 — 웹(drift wasm)은
// 브라우저 API에 의존해 자동 테스트가 어렵고, 03-02 "수동 검증" 절대로
// Chrome에서 사람이 확인한다.
//
// `rootBundle`/`path_provider` 는 여기서 모킹하지 않는다. 대신 복사 로직
// (`copySeedIfAbsent`/`copySeedFile`, open_native.dart)을 File 두 개를 받는
// 순수 함수로 분리해 직접 호출한다 — 03-02 "테스트" 절이 이 방식을 "간단하다"
// 며 권장한다.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:jgame/data/db/app_database.dart';
import 'package:jgame/data/db/db_bootstrap.dart';
import 'package:jgame/data/db/open_native.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('bootstrap_test_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('원자적 복사 (copySeedIfAbsent / copySeedFile)', () {
    test('첫 실행 복사: 대상 파일이 없으면 생성됨', () async {
      final source = File('${tmp.path}/seed.sqlite')
        ..writeAsStringSync('seed-bytes');
      final target = File('${tmp.path}/words.sqlite');

      expect(target.existsSync(), isFalse);
      await copySeedIfAbsent(source, target);

      expect(target.existsSync(), isTrue);
      expect(target.readAsStringSync(), 'seed-bytes');
    });

    test('재실행: 이미 있으면 복사 안 함 (mtime 변화 없음)', () async {
      final source = File('${tmp.path}/seed.sqlite')
        ..writeAsStringSync('new-bytes-that-must-not-land');
      final target = File('${tmp.path}/words.sqlite')
        ..writeAsStringSync('old-bytes');
      final before = target.statSync().modified;

      await copySeedIfAbsent(source, target);

      expect(target.readAsStringSync(), 'old-bytes', reason: '복사되면 안 된다');
      expect(target.statSync().modified, before);
    });

    test('원자적 복사: .tmp 파일이 남지 않음', () async {
      final source = File('${tmp.path}/seed.sqlite')
        ..writeAsStringSync('seed-bytes');
      final target = File('${tmp.path}/words.sqlite');
      final leftoverTmp = File('${target.path}.tmp');

      await copySeedFile(source, target);

      expect(target.existsSync(), isTrue);
      expect(leftoverTmp.existsSync(), isFalse);
    });

    test('앱 삭제→재설치: 디렉터리를 지운 뒤 open → 정상 복사', () async {
      final source = File('${tmp.path}/seed.sqlite')
        ..writeAsStringSync('seed-bytes');
      final target = File('${tmp.path}/words.sqlite');

      await copySeedIfAbsent(source, target);
      expect(target.existsSync(), isTrue);

      // "앱 삭제"를 흉내낸다: 문서 디렉터리에서 DB 파일만 사라진 상태.
      target.deleteSync();
      expect(target.existsSync(), isFalse);

      await copySeedIfAbsent(source, target);

      expect(target.existsSync(), isTrue);
      expect(target.readAsStringSync(), 'seed-bytes');
    });
  });

  group('.bak 복구 (recoverOrCopySeed, 05-03)', () {
    // 05-03의 원자 교체(db_swapper.dart)가 rename 사이에 죽으면 words.sqlite가
    // 없고 .bak만 남는다 — 다음 부트스트랩이 이걸 복구해야 한다(05-03 "백업
    // 파일" 절, 03-02에 역으로 반영).
    test('words.sqlite 없고 .bak만 있으면 .bak을 복구', () async {
      final file = File('${tmp.path}/words.sqlite');
      File('${file.path}.bak').writeAsStringSync('backed-up-bytes');
      var seedCopied = false;

      await recoverOrCopySeed(file, (f) async {
        seedCopied = true;
      });

      expect(file.readAsStringSync(), 'backed-up-bytes');
      expect(File('${file.path}.bak').existsSync(), isFalse,
          reason: '복구 후 .bak은 rename으로 사라져야 한다');
      expect(seedCopied, isFalse, reason: '.bak이 있으면 시드를 다시 복사하지 않는다');
    });

    test('words.sqlite도 .bak도 없으면 시드를 복사', () async {
      final file = File('${tmp.path}/words.sqlite');
      var seedCopied = false;

      await recoverOrCopySeed(file, (f) async {
        seedCopied = true;
        f.writeAsStringSync('seed-bytes');
      });

      expect(seedCopied, isTrue);
      expect(file.readAsStringSync(), 'seed-bytes');
    });

    test('words.sqlite가 이미 있고 정상 열리면 오래된 .bak을 정리', () async {
      final file = File('${tmp.path}/words.sqlite');
      // "정상 열림" 확인(recoverOrCopySeed의 _opensCleanly)을 통과하려면
      // 진짜 sqlite 파일이어야 한다 — word 테이블까지 있어야 한다.
      final raw = sqlite3.open(file.path);
      raw.execute(
          "CREATE TABLE word (headword TEXT PRIMARY KEY); "
          "INSERT INTO word VALUES ('가나')");
      raw.close();
      final backup = File('${file.path}.bak')..writeAsStringSync('stale-backup');
      var called = false;

      await recoverOrCopySeed(file, (f) async {
        called = true;
      });

      expect(called, isFalse, reason: '이미 정상 파일이 있으면 시드로 덮어쓰지 않는다');
      expect(backup.existsSync(), isFalse,
          reason: '정상 파일과 .bak이 동시에 있는 유일한 경우는 교체가 이미 끝난 뒤 '
              '.bak 삭제만 실패한 것뿐이라(05-03 "막히면") 정리해도 안전하다');
    });

    test('words.sqlite가 있지만 손상됐으면 .bak을 지우지 않는다', () async {
      // "교체 롤백조차 실패해 살아있는 파일이 망가진" 상태를 흉내낸다 —
      // 이때 .bak을 지우면 유저 통계의 유일한 사본을 영구히 잃는다
      // (05-03 리뷰에서 발견된 경로). 시드로 덮어쓰지도 않는다 — 그것도
      // 사람 확인 없이 통계를 지우는 길이다.
      final file = File('${tmp.path}/words.sqlite')
        ..writeAsStringSync('이건 SQLite 파일이 아니다');
      final backup = File('${file.path}.bak')..writeAsStringSync('real-user-stats');
      var called = false;

      await recoverOrCopySeed(file, (f) async {
        called = true;
      });

      expect(called, isFalse);
      expect(backup.existsSync(), isTrue,
          reason: '살아있는 파일이 손상됐으면 유일한 복구 수단인 .bak을 지키고 있어야 한다');
    });

    test('words.sqlite가 있고 .bak이 없으면 그대로 아무 것도 안 함', () async {
      final file = File('${tmp.path}/words.sqlite')
        ..writeAsStringSync('existing-bytes');
      var called = false;

      await recoverOrCopySeed(file, (f) async {
        called = true;
      });

      expect(called, isFalse);
      expect(file.readAsStringSync(), 'existing-bytes');
    });
  });

  group('스키마 검증 (DbBootstrap.verify)', () {
    late String schemaSql;

    setUpAll(() {
      // tools/schema.sql(02-09)이 단일 진실이다. 여기서도 그대로 재사용해
      // fixture DB를 만든다 — 계약이 바뀌면 이 테스트도 자동으로 따라간다.
      schemaSql = File('../tools/schema.sql').readAsStringSync();
    });

    /// [schemaVersion] 을 meta에 넣고(생략하면 아예 안 넣는다 → 불일치),
    /// [withWord] 가 true면 word row를 하나 채워 fixture DB를 만든다.
    AppDatabase openFixture(
      String path, {
      String? schemaVersion = '${AppDatabase.expectedSchemaVersion}',
      bool withWord = true,
    }) {
      final raw = sqlite3.open(path);
      raw.execute(schemaSql);
      if (schemaVersion != null) {
        raw.execute(
            "INSERT INTO meta(key, value) VALUES ('schema_version', '$schemaVersion')");
      }
      if (withWord) {
        raw.execute('''
          INSERT INTO word(headword, len, c1, c2, tier, pos, source)
          VALUES ('가나', 2, '가', '나', 1, 'NNG', 1)
        ''');
      }
      raw.close();
      return AppDatabase(NativeDatabase(File(path)));
    }

    test('스키마 버전 확인: 일치하면 통과', () async {
      final db = openFixture('${tmp.path}/ok.sqlite');
      addTearDown(db.close);

      await DbBootstrap.verify(db); // 예외 없이 끝나야 통과
    });

    test('스키마 불일치: SchemaMismatch 예외', () async {
      final db = openFixture('${tmp.path}/mismatch.sqlite',
          schemaVersion: '999');
      addTearDown(db.close);

      await expectLater(
          DbBootstrap.verify(db), throwsA(isA<SchemaMismatch>()));
    });

    test('빈 DB: EmptyDatabase 예외', () async {
      final db =
          openFixture('${tmp.path}/empty.sqlite', withWord: false);
      addTearDown(db.close);

      await expectLater(
          DbBootstrap.verify(db), throwsA(isA<EmptyDatabase>()));
    });
  });
}
