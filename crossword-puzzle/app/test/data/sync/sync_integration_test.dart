// 05-04. 갱신 통합 테스트 — 로컬 HTTP 서버 + 실제 SyncService + 실제 DbSwapper.
//
// 05-02/05-03 단위 테스트는 각자 가짜(MockClient/주입된 swapDb)로 서로를
// 갈아 끼워 검증했다. 여기서는 처음으로 **진짜 네트워크(로컬 루프백)**와
// **진짜 DbSwapper**를 같이 돌려, 두 조각이 실제로 맞물리는지 확인한다
// (05-sync.md "테스트": "로컬 HTTP 서버로 가짜 manifest·DB 제공").
//
// "기존 DB 무손상"은 파일 존재만으로 확인하지 않는다 — 반쯤 덮인 파일도
// 존재는 한다(05-04 "기존 DB 무손상의 검증 방법"). 대신 `DriftWordRepository`
// 로 실제 쿼리가 되는지까지 확인한다(`expectDbHealthy`). 전체 퍼즐 생성까지는
// 안 한다 — 그건 이 테스트 fixture가 아니라 실 `assets/words.sqlite` +
// `GridGenerator` 조합으로 이미 다른 테스트(levels_test.dart)가 검증한다.
//
// 시나리오 15번("교체 중 크래시 시뮬레이션 → 부트스트랩이 복구")은 여기 없다
// — 그 로직(`recoverOrCopySeed`)이 `open_native.dart`에 있어
// `bootstrap_test.dart`가 이미 직접 검증한다(05-03 "구현 메모").
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:drift/native.dart';
import 'package:jgame/data/db/app_database.dart';
import 'package:jgame/data/drift_word_repository.dart';
import 'package:jgame/data/sync/db_swapper.dart';
import 'package:jgame/data/sync/sync_result.dart';
import 'package:jgame/data/sync/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:test/test.dart';

String _sha256Hex(List<int> bytes) => crypto.sha256.convert(bytes).toString();

/// 05-sync.md/05-04가 말하는 로컬 가짜 릴리스 서버. 실제 루프백 소켓을 연다
/// (`bind(..., 0)`으로 자동 포트 — 05-04 "막히면": CI 포트 충돌 방지).
class FakeReleaseServer {
  HttpServer? _server;

  Map<String, dynamic> Function() manifestJson =
      () => throw StateError('manifestJson not set');
  List<int> Function() dbBytes = () => throw StateError('dbBytes not set');
  bool manifestNotFound = false;
  bool manifestBroken = false;

  /// 정상적으로 응답을 끝내되 선언한 크기보다 적게 준다(청크 인코딩으로
  /// 깔끔하게 EOF) — `NativeSyncService`의 `received != size_bytes` 검사를
  /// 태운다. **소켓을 끊는 게 아니다** — 진짜 연결 중단은 [abortConnection].
  bool truncateResponse = false;

  /// 진짜로 소켓을 중간에 끊는다(`detachSocket` 후 `destroy`) — 클라이언트가
  /// 스트림 에러를 받는 경로(`sync_service.dart`의 `catch (_)`)를 태운다.
  /// [truncateResponse]는 이 경로를 태우지 않는다(05-04 리뷰에서 확인됨 —
  /// `HttpResponse.close()`로 짧게 주면 클라이언트는 그냥 깨끗한 EOF로 본다).
  bool abortConnection = false;

  Future<String> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    unawaited(_server!.forEach(_handle));
    return 'http://127.0.0.1:${_server!.port}';
  }

  Future<void> _handle(HttpRequest req) async {
    if (req.uri.path.endsWith('manifest.json')) {
      if (manifestNotFound) {
        req.response.statusCode = HttpStatus.notFound;
      } else if (manifestBroken) {
        req.response.headers.contentType = ContentType.json;
        req.response.write('{ 이건 JSON이 아니다');
      } else {
        req.response.headers.contentType = ContentType.json;
        req.response.write(jsonEncode(manifestJson()));
      }
      await req.response.close();
      return;
    }
    if (req.uri.path.endsWith('.sqlite')) {
      final bytes = dbBytes();
      if (abortConnection) {
        final socket = await req.response.detachSocket();
        socket.add(bytes.sublist(0, bytes.length ~/ 2));
        await socket.flush();
        await socket.close();
        return; // 소켓을 이미 떼어냈다 — response.close()를 부르면 안 된다.
      }
      req.response
          .add(truncateResponse ? bytes.sublist(0, bytes.length ~/ 2) : bytes);
      await req.response.close();
      return;
    }
    req.response.statusCode = HttpStatus.notFound;
    await req.response.close();
  }

  Future<void> stop() async {
    await _server?.close(force: true);
  }
}

void main() {
  late Directory tmp;
  late String schemaSql;
  late FakeReleaseServer server;
  late String baseUrl;

  setUpAll(() {
    schemaSql = File('../tools/schema.sql').readAsStringSync();
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('sync_integration_test_');
    server = FakeReleaseServer();
    baseUrl = await server.start();
  });

  tearDown(() async {
    await server.stop();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// [dbVersion]·단어·통계로 유효한 words.sqlite를 만든다 — db_swapper_test.dart
  /// 의 `makeDb`와 같은 패턴.
  File makeDb(
    String name, {
    int dbVersion = 1,
    int schemaVersion = AppDatabase.expectedSchemaVersion,
    List<String> words = const ['가나', '다라'],
    List<({String headword, int correct, int wrong})> statRows = const [],
  }) {
    final path = '${tmp.path}/$name.sqlite';
    final raw = sqlite3.sqlite3.open(path);
    try {
      raw.execute(schemaSql);
      raw.execute(
          "INSERT INTO meta(key, value) VALUES ('db_version', '$dbVersion')");
      raw.execute(
          "INSERT INTO meta(key, value) VALUES ('schema_version', '$schemaVersion')");
      for (final w in words) {
        raw.execute(
            'INSERT INTO word(headword, len, c1, c2, tier, pos, source) '
            'VALUES (?, 2, ?, ?, 1, ?, 1)',
            [w, w[0], w[1], 'NNG']);
      }
      for (final s in statRows) {
        raw.execute(
            'INSERT INTO word_stat(headword, correct, wrong) VALUES (?,?,?)',
            [s.headword, s.correct, s.wrong]);
      }
    } finally {
      raw.close();
    }
    return File(path);
  }

  /// [dbFile]의 실제 바이트를 기준으로 유효한 manifest를 만든다.
  /// [sha256Override]를 주면 일부러 틀린 값을 넣을 수 있다(체크섬 조작 테스트).
  Map<String, dynamic> manifestFor(
    File dbFile, {
    required int dbVersion,
    int schemaVersion = AppDatabase.expectedSchemaVersion,
    String minAppVersion = '1.0.0',
    String? sha256Override,
  }) {
    final bytes = dbFile.readAsBytesSync();
    return {
      'db_version': dbVersion,
      'schema_version': schemaVersion,
      'url': '$baseUrl/words-v$dbVersion.sqlite',
      'sha256': sha256Override ?? _sha256Hex(bytes),
      'size_bytes': bytes.length,
      'min_app_version': minAppVersion,
      'published_at': '2027-03-01',
      'word_count': 1,
      'notes': '',
    };
  }

  /// 실제 서비스를 진짜 [DbSwapper]와 함께 조립한다 — 여기가 05-02/05-03을
  /// 실제로 이어 붙이는 지점이다.
  ///
  /// `NativeSyncService.db`를 여기서 대신 닫아 준다 — 실패/스킵 경로는
  /// `swap()`(그 안에서 `current.close()`를 부른다)까지 가지 않으므로, 이
  /// 헬퍼가 만든 최초 연결이 테스트가 끝나도 열린 채로 남는다. 그 상태로
  /// `tearDown`이 `tmp`를 지우려 하면 Windows가 공유 위반으로 거부한다.
  Future<NativeSyncService> service({required File currentFile}) async {
    final prefs = await SharedPreferences.getInstance();
    final swapper = DbSwapper(
      open: (f) => AppDatabase(NativeDatabase(f)),
      currentFile: currentFile,
    );
    final svc = NativeSyncService(
      db: AppDatabase(NativeDatabase(currentFile)),
      prefs: prefs,
      swapDb: swapper.swap,
      manifestUrl: '$baseUrl/manifest.json',
      downloadDir: () async => tmp,
      // 기본값(Connectivity().checkConnectivity)은 실제 플랫폼 채널을 쓰는데
      // 이 파일은 flutter_test가 아니라 순수 package:test라 Flutter 바인딩이
      // 없다 — 그대로 두면 모든 테스트가 "Binding has not yet been
      // initialized" 예외로 failedDownload가 된다(05-02 sync_service_test.dart
      // 와 같은 이유로 가짜를 주입한다).
      connectivity: () async => const [ConnectivityResult.wifi],
    );
    addTearDown(() async {
      try {
        await svc.db.close();
      } catch (_) {}
    });
    return svc;
  }

  Future<void> expectDbHealthy(File file) async {
    final db = AppDatabase(NativeDatabase(file));
    try {
      expect(await db.wordCount, greaterThan(0));
      // 파일 존재만으로는 부족하다 — 실제 쿼리 엔진까지 살아있는지 확인한다
      // (05-04 "기존 DB 무손상의 검증 방법").
      final results =
          await DriftWordRepository(db).findByPattern(length: 2, limit: 5);
      expect(results, isNotEmpty);
    } finally {
      await db.close();
    }
  }

  // --- 필수 4종 (05-sync.md "테스트" 절) ---

  test('1. 정상 갱신: word_stat 보존, word는 새 DB 것, db_version 갱신',
      () async {
    final currentFile = makeDb('current', dbVersion: 1, statRows: [
      (headword: '가나', correct: 3, wrong: 1),
    ]);
    final newDbFile = makeDb('new', dbVersion: 2, words: const ['마바']);
    server.manifestJson = () => manifestFor(newDbFile, dbVersion: 2);
    server.dbBytes = () => newDbFile.readAsBytesSync();

    final svc = await service(currentFile: currentFile);
    final result = await svc.sync(force: true);

    expect(result.outcome, SyncOutcome.success);

    final next = AppDatabase(NativeDatabase(currentFile));
    addTearDown(next.close);
    expect(await next.metaValue('db_version'), '2');
    final words = await next.select(next.words).get();
    expect(words.map((w) => w.headword), ['마바']);
    final stat = await (next.select(next.wordStats)
          ..where((t) => t.headword.equals('가나')))
        .getSingle();
    expect(stat.correct, 3);
    expect(stat.wrong, 1);
  });

  test('2. 다운로드 중단(서버 끊기): failedDownload, 기존 DB 무손상, 임시 파일 삭제',
      () async {
    final currentFile = makeDb('current', dbVersion: 1);
    final newDbFile = makeDb('new', dbVersion: 2);
    server.manifestJson = () => manifestFor(newDbFile, dbVersion: 2);
    server.dbBytes = () => newDbFile.readAsBytesSync();
    // 소켓을 실제로 끊는다 — `truncateResponse`(짧지만 깨끗하게 끝나는
    // 응답)와 달리, 이건 스트림 에러 경로(`sync_service.dart`의 `catch (_)`)
    // 를 태운다(05-04 리뷰에서 둘이 서로 다른 경로임이 확인됐다).
    server.abortConnection = true;

    final svc = await service(currentFile: currentFile);
    final result = await svc.sync(force: true);

    expect(result.outcome, SyncOutcome.failedDownload);
    expect(File('${tmp.path}/words.sqlite.download').existsSync(), isFalse);
    await expectDbHealthy(currentFile);
  });

  test('3. sha256 조작: failedChecksum, 거부, 기존 DB 무손상', () async {
    final currentFile = makeDb('current', dbVersion: 1);
    final newDbFile = makeDb('new', dbVersion: 2);
    server.manifestJson = () =>
        manifestFor(newDbFile, dbVersion: 2, sha256Override: '0' * 64);
    server.dbBytes = () => newDbFile.readAsBytesSync();

    final svc = await service(currentFile: currentFile);
    final result = await svc.sync(force: true);

    expect(result.outcome, SyncOutcome.failedChecksum);
    await expectDbHealthy(currentFile);
  });

  test('4. schema_version 불일치: skippedSchemaIncompatible, 다운로드조차 안 함',
      () async {
    final currentFile = makeDb('current', dbVersion: 1);
    final newDbFile = makeDb('new', dbVersion: 2, schemaVersion: 999);
    server.manifestJson =
        () => manifestFor(newDbFile, dbVersion: 2, schemaVersion: 999);
    server.dbBytes = () =>
        throw StateError('schema 불일치는 다운로드 전에 걸러져야 한다');

    final svc = await service(currentFile: currentFile);
    final result = await svc.sync(force: true);

    expect(result.outcome, SyncOutcome.skippedSchemaIncompatible);
    await expectDbHealthy(currentFile);
  });

  // --- 추가 시나리오 ---

  test('5. manifest 404: 조용히 실패, 예외 전파 없음', () async {
    final currentFile = makeDb('current', dbVersion: 1);
    server.manifestNotFound = true;

    final svc = await service(currentFile: currentFile);
    final result = await svc.sync(force: true);

    expect(result.outcome, SyncOutcome.failedDownload);
    await expectDbHealthy(currentFile);
  });

  test('6. manifest JSON 깨짐: 조용히 실패', () async {
    final currentFile = makeDb('current', dbVersion: 1);
    server.manifestBroken = true;

    final svc = await service(currentFile: currentFile);
    final result = await svc.sync(force: true);

    expect(result.outcome, SyncOutcome.failedDownload);
    await expectDbHealthy(currentFile);
  });

  test('7. db_version이 현재와 같음: skippedUpToDate, last_sync_at 갱신',
      () async {
    final currentFile = makeDb('current', dbVersion: 3);
    final newDbFile = makeDb('new', dbVersion: 3);
    server.manifestJson = () => manifestFor(newDbFile, dbVersion: 3);
    server.dbBytes = () => newDbFile.readAsBytesSync();

    final svc = await service(currentFile: currentFile);
    final result = await svc.sync(force: true);
    final prefs = await SharedPreferences.getInstance();

    expect(result.outcome, SyncOutcome.skippedUpToDate);
    expect(prefs.getInt(lastSyncAtPrefsKey), isNotNull);
  });

  test('8. db_version이 현재보다 낮음: skippedUpToDate', () async {
    final currentFile = makeDb('current', dbVersion: 5);
    final newDbFile = makeDb('new', dbVersion: 3);
    server.manifestJson = () => manifestFor(newDbFile, dbVersion: 3);
    server.dbBytes = () => newDbFile.readAsBytesSync();

    final svc = await service(currentFile: currentFile);
    final result = await svc.sync(force: true);

    expect(result.outcome, SyncOutcome.skippedUpToDate);
  });

  test('9. min_app_version이 앱보다 높음: skippedAppTooOld', () async {
    final currentFile = makeDb('current', dbVersion: 1);
    final newDbFile = makeDb('new', dbVersion: 2);
    server.manifestJson = () =>
        manifestFor(newDbFile, dbVersion: 2, minAppVersion: '99.0.0');
    server.dbBytes = () => newDbFile.readAsBytesSync();

    final svc = await service(currentFile: currentFile);
    final result = await svc.sync(force: true);

    expect(result.outcome, SyncOutcome.skippedAppTooOld);
  });

  test('10. 다운로드 파일이 SQLite가 아님: failedSanity, 기존 DB 무손상',
      () async {
    final currentFile = makeDb('current', dbVersion: 1);
    final garbage = utf8.encode('이건 SQLite 파일이 아니다');
    server.manifestJson = () => {
          'db_version': 2,
          'schema_version': AppDatabase.expectedSchemaVersion,
          'url': '$baseUrl/words-v2.sqlite',
          'sha256': _sha256Hex(garbage),
          'size_bytes': garbage.length,
          'min_app_version': '1.0.0',
          'published_at': '2027-03-01',
          'word_count': 1,
          'notes': '',
        };
    server.dbBytes = () => garbage;

    final svc = await service(currentFile: currentFile);
    final result = await svc.sync(force: true);

    expect(result.outcome, SyncOutcome.failedSanity);
    await expectDbHealthy(currentFile);
  });

  test('11. 새 DB의 word가 0행: failedSanity', () async {
    final currentFile = makeDb('current', dbVersion: 1);
    final emptyDb = makeDb('empty', dbVersion: 2, words: const []);
    server.manifestJson = () => manifestFor(emptyDb, dbVersion: 2);
    server.dbBytes = () => emptyDb.readAsBytesSync();

    final svc = await service(currentFile: currentFile);
    final result = await svc.sync(force: true);

    expect(result.outcome, SyncOutcome.failedSanity);
  });

  test('12. 새 DB의 meta.db_version이 manifest와 불일치: failedSanity',
      () async {
    final currentFile = makeDb('current', dbVersion: 1);
    // manifest는 db_version 2라고 주장하지만, 실제 파일은 db_version 4.
    final mismatchedDb = makeDb('mismatched', dbVersion: 4);
    server.manifestJson = () => manifestFor(mismatchedDb, dbVersion: 2);
    server.dbBytes = () => mismatchedDb.readAsBytesSync();

    final svc = await service(currentFile: currentFile);
    final result = await svc.sync(force: true);

    expect(result.outcome, SyncOutcome.failedSanity);
  });

  test('13. 갱신 2회 연속: 두 번째는 skippedUpToDate', () async {
    final currentFile = makeDb('current', dbVersion: 1);
    final newDbFile = makeDb('new', dbVersion: 2);
    server.manifestJson = () => manifestFor(newDbFile, dbVersion: 2);
    server.dbBytes = () => newDbFile.readAsBytesSync();

    final svc = await service(currentFile: currentFile);
    final first = await svc.sync(force: true);
    expect(first.outcome, SyncOutcome.success);

    // 첫 갱신으로 svc.db는 새 연결을 가리킨다(NativeSyncService.db 재대입,
    // 05-02 "구현은 골격에서 벗어난다" 4번) — 그래서 같은 인스턴스로 바로
    // 두 번째 sync를 불러도 닫힌 연결에 질의하지 않는다.
    final second = await svc.sync(force: true);
    expect(second.outcome, SyncOutcome.skippedUpToDate);
  });

  test('14. 갱신 후 재시작 시뮬레이션: 새 DB가 열리고 통계 유지', () async {
    final currentFile = makeDb('current', dbVersion: 1, statRows: [
      (headword: '가나', correct: 7, wrong: 2),
    ]);
    final newDbFile = makeDb('new', dbVersion: 2, words: const ['사바']);
    server.manifestJson = () => manifestFor(newDbFile, dbVersion: 2);
    server.dbBytes = () => newDbFile.readAsBytesSync();

    final svc = await service(currentFile: currentFile);
    final result = await svc.sync(force: true);
    expect(result.outcome, SyncOutcome.success);

    // "재시작"은 currentFile 경로를 처음부터 다시 여는 것으로 흉내낸다 —
    // 05-04 "막히면"이 고른 1차 범위(AppScope 재구독 대신 재시작 안내)와
    // 같은 전제다.
    final restarted = AppDatabase(NativeDatabase(currentFile));
    addTearDown(restarted.close);
    expect(await restarted.metaValue('db_version'), '2');
    final stat = await (restarted.select(restarted.wordStats)
          ..where((t) => t.headword.equals('가나')))
        .getSingle();
    expect(stat.correct, 7);
    expect(stat.wrong, 2);
  });
}
