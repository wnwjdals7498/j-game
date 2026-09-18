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
  ///
  /// 스키마가 안 맞으면(`SchemaMismatch`) `makeReseeder()`(네이티브만 지원 —
  /// `open_native.dart`/`open_web.dart`/`open_stub.dart` 참고)로 시드를 다시
  /// 적재한다. 재적재 자체를 지원하지 않는 플랫폼(웹)이면 원래 `SchemaMismatch`를
  /// 그대로 던진다. 재적재는 성공했는데 그 새 DB로도 여전히 검증이 실패하면
  /// (자산 자체가 잘못 빌드된 경우) **그 두 번째 검증에서 나온 새 예외**가
  /// 전파된다 — 재적재 전의 원래 예외가 아니다(03-02 "스키마 버전 불일치
  /// 정책", 05-03 "구현 메모").
  static Future<AppDatabase> open() async {
    final executor = await openConnection();
    final db = AppDatabase(executor);
    try {
      await verify(db);
      return db;
    } on SchemaMismatch {
      final reseed = await makeReseeder();
      if (reseed == null) rethrow;
      final next = await reseed(db);
      await verify(next);
      return next;
    }
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
/// `DbBootstrap.open()`이 이 예외를 잡아 "시드로 덮어쓰기 + word_stat 보존"
/// 재적재(`open_native.dart`의 `makeReseeder`, `DbSwapper.reseedFromAsset`)를
/// 시도한다(03-02 "스키마 버전 불일치 정책" 절, 05-03). 재적재를 지원하지
/// 않는 플랫폼(웹)에서는 여기까지만 오고 그대로 던져진다.
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
