// Android/데스크톱(네이티브) 전용 연결 구현.
//
// `assets/words.sqlite` 는 읽기 전용 자산이다. `word_stat` 에 쓰려면 쓰기 가능한
// 위치(앱 문서 디렉터리)로 옮겨야 한다 — 03-02 "왜 복사하는가" 참조.
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

const _dbFileName = 'words.sqlite';
const _asset = 'assets/words.sqlite';

/// 앱 시작 시 1회 호출된다. 문서 디렉터리에 DB가 없으면(첫 실행, 또는
/// 앱 삭제→재설치 후) assets의 시드를 복사한 뒤 연다. 있으면 그대로 연다.
Future<QueryExecutor> openConnection() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$_dbFileName');

  if (!await file.exists()) {
    await _copySeedFromBundle(file);
  }
  return NativeDatabase(file);
}

Future<void> _copySeedFromBundle(File target) async {
  final bytes = await rootBundle.load(_asset);
  await _atomicWrite(
    bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    target,
  );
}

/// [target] 이 이미 있으면 아무 것도 하지 않는다. 없으면 [source] 를
/// 원자적으로 복사한다.
///
/// `rootBundle`/`path_provider` 에 기대지 않는 순수 함수라 테스트가 쉽다
/// (03-02 "테스트" 절: `TestDefaultBinaryMessengerBinding` 모킹 대신 이 방식을
/// 쓴다). [openConnection] 의 "첫 실행에만 복사" 로직과 같은 알고리즘이며,
/// `test/data/bootstrap_test.dart` 가 이 함수를 직접 호출해 검증한다.
Future<void> copySeedIfAbsent(File source, File target) async {
  if (await target.exists()) return;
  await copySeedFile(source, target);
}

/// 존재 여부를 확인하지 않고 [source] 를 [target] 에 원자적으로 복사한다.
Future<void> copySeedFile(File source, File target) async {
  await _atomicWrite(await source.readAsBytes(), target);
}

/// 원자적 복사의 핵심.
///
/// `.tmp` 파일에 먼저 쓴 뒤 `rename` 으로 최종 경로로 옮긴다. `rename` 은 같은
/// 파일시스템 안에서 원자적이므로, 10MB 복사 도중 앱이 강제 종료돼도 최종
/// 경로에는 반쪽짜리 파일이 남지 않는다 — 다음 실행에서 "파일이 있으니 복사
/// 안 함" → 깨진 DB로 크래시하는 상황을 막는다. 05-03의 DB 교체도 같은 패턴.
Future<void> _atomicWrite(Uint8List bytes, File target) async {
  final tmp = File('${target.path}.tmp');
  await tmp.writeAsBytes(bytes, flush: true);
  await tmp.rename(target.path);
}

// TODO(05-03): schema_version 불일치 시 정책은 "시드로 덮어쓰기 + word_stat
// 보존" 한 가지뿐이다 (03-02 "스키마 버전 불일치 정책" 절). 이 재적재
// (reseedPreservingStats) 는 05-03의 db_swapper와 구현이 거의 같으므로 여기서
// 새로 만들지 않고 05-03에서 만든 것을 재사용한다. 3단계 시점에는 시드와 앱
// 버전이 항상 일치하므로, 지금은 DbBootstrap.verify가 SchemaMismatch를 던지는
// 것으로 충분하다. 05-03 완료 후 이 TODO를 해소하고 openConnection()에서
// SchemaMismatch를 잡아 재적재를 호출하도록 연결한다.
