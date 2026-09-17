// 공개 API. 조건부 import로 네이티브/웹을 분기한다 (03-02).
//
// `assets/words.sqlite` 를 쓰기 가능한 DB로 만드는 절차는 플랫폼마다 완전히
// 다르다 — 네이티브는 앱 문서 디렉터리로 파일 복사, 웹은 OPFS/IndexedDB 적재.
// 그 차이를 이 파일 뒤로 숨기고, 호출자는 `DbBootstrap.open()` 하나만 안다.
import 'app_database.dart';
import 'open_stub.dart'
    if (dart.library.io) 'open_native.dart'
    if (dart.library.js_interop) 'open_web.dart';

class DbBootstrap {
  DbBootstrap._();

  /// 앱 시작 시 1회. 시드 적재 → DB 오픈 → 스키마 버전 확인.
  static Future<AppDatabase> open() async {
    final executor = await openConnection();
    final db = AppDatabase(executor);
    await verify(db);
    return db;
  }

  /// `meta.schema_version` 과 단어 수를 검증한다.
  ///
  /// [DbBootstrap.open] 이 내부에서 호출하지만, `rootBundle`/`path_provider`
  /// 없이 임의의 [AppDatabase] 에 대해 독립적으로 테스트할 수 있도록 공개
  /// 메서드로 둔다 (`test/data/bootstrap_test.dart` 참조).
  static Future<void> verify(AppDatabase db) async {
    final v = await db.metaValue('schema_version');
    if (v != '${AppDatabase.expectedSchemaVersion}') {
      throw SchemaMismatch(expected: AppDatabase.expectedSchemaVersion,
                            actual: v);
    }
    final n = await db.wordCount;
    if (n <= 0) throw const EmptyDatabase();
  }
}

/// `meta.schema_version` 이 [expected] 와 다를 때 던진다.
///
/// v1 정책: 시드와 앱 버전은 3단계 시점에 항상 일치해야 하므로, 여기서는
/// 예외를 던지는 것으로 끝낸다. "시드로 덮어쓰기 + word_stat 보존" 재적재는
/// 05-03(db_swapper) 완료 후 연결한다 (03-02 "스키마 버전 불일치 정책" 절,
/// `open_native.dart` 의 TODO 참조).
class SchemaMismatch implements Exception {
  final int expected;
  final String? actual;

  const SchemaMismatch({required this.expected, required this.actual});

  @override
  String toString() =>
      'SchemaMismatch: meta.schema_version 기대값=$expected, 실제값=$actual';
}

/// `word` 테이블에 데이터가 하나도 없을 때 던진다 (빈 시드 DB, 손상된 복사 등).
class EmptyDatabase implements Exception {
  const EmptyDatabase();

  @override
  String toString() => 'EmptyDatabase: word 테이블에 데이터가 없다';
}
