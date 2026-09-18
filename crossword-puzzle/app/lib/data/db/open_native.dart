// Android/데스크톱(네이티브) 전용 연결 구현.
//
// `assets/words.sqlite` 는 읽기 전용 자산이다. `word_stat` 에 쓰려면 쓰기 가능한
// 위치(앱 문서 디렉터리)로 옮겨야 한다 — 03-02 "왜 복사하는가" 참조.
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import 'app_database.dart';
import '../sync/db_swapper.dart';

const _dbFileName = 'words.sqlite';
const _asset = 'assets/words.sqlite';

/// 앱 시작 시 1회 호출된다. 문서 디렉터리에 DB가 없으면(첫 실행, 앱
/// 삭제→재설치 후, 또는 05-03의 원자 교체 도중 죽은 직후) 복구하거나
/// assets의 시드를 복사한 뒤 연다. 있으면 그대로 연다.
Future<QueryExecutor> openConnection() async {
  final file = await _dbFile();
  await recoverOrCopySeed(file, _copySeedFromBundle);
  return NativeDatabase(file);
}

/// `db_bootstrap.dart`의 `DbBootstrap.open()`이 `SchemaMismatch`를 잡으면
/// 이 함수가 만든 재적재 함수를 호출한다(03-02 "스키마 버전 불일치 정책").
/// 네이티브에서는 항상 값이 있다 — 웹/스텁의 같은 이름 함수는 `null`을
/// 반환해 그 플랫폼엔 재적재 기능이 없음을 나타낸다(05-sync: 갱신은 1차
/// 범위에서 웹 제외).
Future<Future<AppDatabase> Function(AppDatabase)?> makeReseeder() async {
  final file = await _dbFile();
  final swapper = DbSwapper(
    open: (f) => AppDatabase(NativeDatabase(f)),
    currentFile: file,
  );
  return swapper.reseedFromAsset;
}

Future<File> _dbFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/$_dbFileName');
}

/// [file] 이 있으면 [file] 이 정상적으로 열릴 때만 오래된 `.bak`을 정리하고
/// 끝낸다. [file] 이 없으면 `.bak`(05-03의 원자 교체가 `rename` 사이에
/// 죽으면 남는 흔적 — `db_swapper.dart` "백업 파일" 참고)을 되돌리거나,
/// 그것도 없으면 [copySeed] 로 시드를 채운다.
///
/// **`.bak`을 [file]이 있다는 이유만으로 지우지 않는다.** "성공한 교체
/// 이후 `.bak` 삭제 단계만 실패한" 정상적인 경우와 "교체 중 뭔가 실패해
/// `words.sqlite`가 손상된 채로 남은" 비정상적인 경우를 [file]의 존재
/// 여부만으로는 구분할 수 없다 — 후자에서 지우면 유저 통계가 든 유일한
/// 사본을 영구히 잃는다(05-03 리뷰에서 실제로 발견된 경로). 그래서 [file]
/// 이 최소한 열리고 `word` 테이블을 읽을 수 있는지 가볍게 확인한 뒤에만
/// 지운다 — 05-03 "막히면"의 "`.bak`이 계속 쌓임" 권고를 안전하게 실행한다.
///
/// `rootBundle`/`path_provider` 에 기대지 않는 순수 함수라 테스트가 쉽다
/// (03-02 "테스트" 절과 같은 이유) — `test/data/bootstrap_test.dart` 가 가짜
/// [copySeed] 콜백으로 직접 검증한다.
Future<void> recoverOrCopySeed(
    File file, Future<void> Function(File target) copySeed) async {
  final backup = File('${file.path}.bak');

  if (await file.exists()) {
    if (await backup.exists() && _opensCleanly(file)) {
      try {
        await backup.delete();
      } catch (_) {}
    }
    return;
  }

  if (await backup.exists()) {
    await backup.rename(file.path);
    return;
  }
  await copySeed(file);
}

/// [file] 이 최소한의 sqlite 파일로 열리고 `word` 테이블을 읽을 수 있는가.
/// `.bak` 정리를 안전할 때만 하기 위한 가벼운 확인이다 — `DbBootstrap.verify`
/// 만큼 엄격하지 않다(schema_version까지는 안 본다).
bool _opensCleanly(File file) {
  try {
    final db = sqlite3.sqlite3.open(file.path, mode: sqlite3.OpenMode.readOnly);
    try {
      db.select('SELECT 1 FROM word LIMIT 1');
      return true;
    } finally {
      db.close();
    }
  } catch (_) {
    return false;
  }
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
