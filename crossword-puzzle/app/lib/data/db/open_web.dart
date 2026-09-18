// 웹(drift wasm) 전용 연결 구현.
//
// 웹은 파일 시스템 복사가 없다. `assets/words.sqlite` 바이트를 OPFS나
// IndexedDB에 적재하는 방식이다 (03-02 "왜 복사하는가" / REVIEW 4.2 (a)).
//
// 1차 범위 한계 (03-02 "웹의 범위 한계" 참조):
// - 갱신(5단계)은 웹에서 1차 범위 제외
// - 10MB 자산 로딩이 느릴 수 있다 — 웹은 배포 대상이 아니라 개발용 빠른
//   확인 용도이므로 허용한다.
import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'app_database.dart';

/// `initializeDatabase` 는 이 이름의 DB가 브라우저 저장소(OPFS/IndexedDB)에
/// 아직 없을 때만 호출된다. 재실행 시에는 저장된 것을 그대로 쓴다.
Future<QueryExecutor> openConnection() async {
  final result = await WasmDatabase.open(
    databaseName: 'jgame',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
    initializeDatabase: () async {
      final bytes = await rootBundle.load('assets/words.sqlite');
      return bytes.buffer.asUint8List(
          bytes.offsetInBytes, bytes.lengthInBytes);
    },
  );

  if (result.missingFeatures.isNotEmpty) {
    // OPFS 불가 → IndexedDB 폴백. 웹은 테스트 용도라 성능은 무관하다
    // (03-data-layer B절, 03-02 "웹의 범위 한계").
    // ignore: avoid_print
    print('drift wasm 폴백: ${result.missingFeatures}');
  }
  return result.resolvedExecutor;
}

/// 웹은 갱신(5단계)이 1차 범위 밖이라 재적재를 지원하지 않는다 —
/// `open_native.dart`의 같은 이름 함수 참고.
Future<Future<AppDatabase> Function(AppDatabase)?> makeReseeder() async =>
    null;
