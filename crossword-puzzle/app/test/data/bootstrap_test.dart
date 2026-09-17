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
