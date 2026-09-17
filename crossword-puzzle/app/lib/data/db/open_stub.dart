// 조건부 import의 기본값(fallback)이다.
//
// `db_bootstrap.dart` 는 `dart.library.io`(네이티브)나 `dart.library.js_interop`(웹)
// 조건에 매칭되지 않는 플랫폼에서 이 파일을 대신 쓴다. 실제로 그런 플랫폼에서
// `openConnection()` 이 호출되는 일은 없어야 하지만, 조건부 import 문법 자체가
// 이 파일 없이는 컴파일되지 않는다 — 이 파일이 없으면
// "if (dart.library.io) ... if (dart.library.js_interop) ..." 뒤에 매칭되는
// 라이브러리가 하나도 없을 때 참조할 기본 라이브러리가 없어 빌드가 실패한다.
import 'package:drift/drift.dart';

Future<QueryExecutor> openConnection() {
  throw UnsupportedError(
    'DbBootstrap.open()이 지원하지 않는 플랫폼에서 호출되었다 '
    '(dart:io도 dart:js_interop도 없음).',
  );
}
