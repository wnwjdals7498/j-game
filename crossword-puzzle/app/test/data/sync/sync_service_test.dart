// SyncService(05-02) 테스트.
//
// 로컬 HTTP 서버를 실제로 띄우는 통합 테스트(05-sync.md "테스트", "로컬 HTTP
// 서버로 가짜 manifest·DB 제공")는 05-04 몫이다. 여기서는 `http.testing.MockClient`
// 로 네트워크를, 주입 가능한 콜백으로 연결·시간·DB 교체를 대신해 05-02 자체의
// 결정 로직(스킵 조건·체크섬·sanity check)만 빠르게 검증한다.
//
// 표(05-02 "테스트")의 11종 + 성공 경로 1종(표에는 없지만 앞의 실패 경로
// 테스트들이 "정상이면 어떻게 되는가"를 전제하므로 별도로 추가했다) = 12종.
// manifest_test.dart의 6종과 합쳐 문서가 요구하는 17종을 이룬다.
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jgame/data/db/app_database.dart';
import 'package:jgame/data/sync/sync_result.dart';
import 'package:jgame/data/sync/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:test/test.dart';

const _manifestUrl = 'https://fake.test/manifest.json';
const _dbUrl = 'https://fake.test/words.sqlite';

Map<String, dynamic> _manifestJson({
  int dbVersion = 2,
  int schemaVersion = 1,
  String minAppVersion = '1.0.0',
  required List<int> dbBytes,
}) =>
    {
      'db_version': dbVersion,
      'schema_version': schemaVersion,
      'url': _dbUrl,
      'sha256': sha256.convert(dbBytes).toString(),
      'size_bytes': dbBytes.length,
      'min_app_version': minAppVersion,
      'published_at': '2027-03-01',
      'word_count': 1,
      'notes': '',
    };

/// schema.sql(단일 진실)로 유효한 words.sqlite 바이트를 만든다. 사용 후
/// 파일을 지운다 — 반환값은 메모리 바이트뿐이다.
List<int> _validDbBytes(Directory tmp, {int dbVersion = 2, int schemaVersion = 1}) {
  final path = '${tmp.path}/valid_${dbVersion}_$schemaVersion.sqlite';
  final schemaSql = File('../tools/schema.sql').readAsStringSync();
  final raw = sqlite3.sqlite3.open(path);
  raw.execute(schemaSql);
  raw.execute(
      "INSERT INTO meta(key, value) VALUES ('db_version', '$dbVersion')");
  raw.execute(
      "INSERT INTO meta(key, value) VALUES ('schema_version', '$schemaVersion')");
  raw.execute('''
    INSERT INTO word(headword, len, c1, c2, tier, pos, source)
    VALUES ('가나', 2, '가', '나', 1, 'NNG', 1)
  ''');
  raw.close();
  final bytes = File(path).readAsBytesSync();
  File(path).deleteSync();
  return bytes;
}

http.Client _fakeClient(Map<String, dynamic> Function() manifestJson,
    List<int> Function() dbBytes) {
  return MockClient.streaming((request, bodyStream) async {
    if (request.url.toString() == _manifestUrl) {
      return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(manifestJson()))), 200);
    }
    if (request.url.toString() == _dbUrl) {
      return http.StreamedResponse(Stream.value(dbBytes()), 200);
    }
    return http.StreamedResponse(const Stream.empty(), 404);
  });
}

void main() {
  late Directory tmp;
  late AppDatabase currentDb;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    tmp = Directory.systemTemp.createTempSync('sync_service_test_');

    final schemaSql = File('../tools/schema.sql').readAsStringSync();
    final currentPath = '${tmp.path}/current.sqlite';
    final raw = sqlite3.sqlite3.open(currentPath);
    raw.execute(schemaSql);
    raw.execute("INSERT INTO meta(key, value) VALUES ('db_version', '1')");
    raw.execute(
        "INSERT INTO meta(key, value) VALUES ('schema_version', '1')");
    raw.close();
    currentDb = AppDatabase(NativeDatabase(File(currentPath)));
  });

  tearDown(() async {
    await currentDb.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  /// 공통 조립. 개별 테스트가 필요한 것만 오버라이드한다.
  Future<SyncService> service({
    Map<String, dynamic> Function()? manifestJson,
    List<int> Function()? dbBytes,
    List<ConnectivityResult> connectivity = const [ConnectivityResult.wifi],
    DbSwap? swapDb,
    Directory? downloadDir,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    // 한 번만 만든다 — sha256/size_bytes 계산과 실제로 서빙되는 바이트가
    // 서로 다른 호출에서 나오면(SQLite 파일을 두 번 새로 만들면) 이론상
    // 바이트가 달라질 수 있다(결정론에 기대는 대신 값 자체를 고정한다).
    final resolvedBytes = dbBytes?.call() ?? _validDbBytes(tmp);
    List<int> bytes() => resolvedBytes;
    return NativeSyncService(
      db: currentDb,
      prefs: prefs,
      swapDb: swapDb ?? (current, newDb) async => current,
      manifestUrl: _manifestUrl,
      httpClient: _fakeClient(
          manifestJson ?? () => _manifestJson(dbBytes: bytes()), bytes),
      connectivity: () async => connectivity,
      downloadDir: () async => downloadDir ?? tmp,
    );
  }

  test('주기 미도래 → skippedNotDue', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        lastSyncAtPrefsKey, DateTime.now().millisecondsSinceEpoch);
    final svc = await service();

    final result = await svc.sync();

    expect(result.outcome, SyncOutcome.skippedNotDue);
  });

  test('force는 주기 무시 → 진행됨 (skippedNotDue가 아님)', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        lastSyncAtPrefsKey, DateTime.now().millisecondsSinceEpoch);
    final svc = await service(connectivity: const [ConnectivityResult.none]);

    final result = await svc.sync(force: true);

    expect(result.outcome, isNot(SyncOutcome.skippedNotDue));
    expect(result.outcome, SyncOutcome.skippedOffline);
  });

  test('오프라인 → skippedOffline', () async {
    final svc = await service(connectivity: const [ConnectivityResult.none]);

    final result = await svc.sync();

    expect(result.outcome, SyncOutcome.skippedOffline);
  });

  test('Wi-Fi 전용 + 모바일 데이터 → skippedOffline', () async {
    final svc = await service(connectivity: const [ConnectivityResult.mobile]);

    final result = await svc.sync(wifiOnly: true);

    expect(result.outcome, SyncOutcome.skippedOffline);
  });

  test('이미 최신 (db_version <= 현재) → skippedUpToDate, last_sync_at 갱신됨',
      () async {
    final svc = await service(
        manifestJson: () => _manifestJson(dbVersion: 1, dbBytes: const []));
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(lastSyncAtPrefsKey), isNull);

    final result = await svc.sync();

    expect(result.outcome, SyncOutcome.skippedUpToDate);
    expect(prefs.getInt(lastSyncAtPrefsKey), isNotNull);
  });

  test('schema_version 불일치 → skippedSchemaIncompatible', () async {
    final svc = await service(
        manifestJson: () =>
            _manifestJson(dbVersion: 2, schemaVersion: 999, dbBytes: const []));

    final result = await svc.sync();

    expect(result.outcome, SyncOutcome.skippedSchemaIncompatible);
  });

  test('min_app_version이 앱보다 높음 → skippedAppTooOld', () async {
    final svc = await service(
        manifestJson: () =>
            _manifestJson(minAppVersion: '99.0.0', dbBytes: const []));

    final result = await svc.sync();

    expect(result.outcome, SyncOutcome.skippedAppTooOld);
  });

  test('다운로드 크기 불일치 → failedDownload, 임시 파일 삭제됨', () async {
    final real = _validDbBytes(tmp);
    final svc = await service(
      manifestJson: () => _manifestJson(dbBytes: real), // size_bytes는 real 기준
      dbBytes: () => real.sublist(0, real.length - 1), // 실제로는 1바이트 모자라게 옴
    );

    final result = await svc.sync();

    expect(result.outcome, SyncOutcome.failedDownload);
    expect(File('${tmp.path}/words.sqlite.download').existsSync(), isFalse);
  });

  test('sha256 불일치 → failedChecksum, 임시 파일 삭제됨', () async {
    final real = _validDbBytes(tmp);
    // sha256은 다른 내용 기준으로 계산하되, size_bytes는 실제로 오는 바이트
    // 길이와 맞춘다 — 그래야 크기 검증(다운로드 단계)을 통과해 체크섬
    // 단계까지 도달한다. 즉, "크기는 맞는데 내용이 바뀐" 상황을 재현한다.
    final svc = await service(
      manifestJson: () => {
        ..._manifestJson(dbBytes: utf8.encode('다른 내용')),
        'size_bytes': real.length,
      },
      dbBytes: () => real,
    );

    final result = await svc.sync();

    expect(result.outcome, SyncOutcome.failedChecksum);
    expect(File('${tmp.path}/words.sqlite.download').existsSync(), isFalse);
  });

  test('sanity 실패 (SQLite 형식이 아님) → failedSanity, 임시 파일 삭제됨', () async {
    final garbage = utf8.encode('이건 SQLite 파일이 아니다');
    final svc = await service(
      manifestJson: () => _manifestJson(dbBytes: garbage),
      dbBytes: () => garbage,
    );

    final result = await svc.sync();

    expect(result.outcome, SyncOutcome.failedSanity);
    expect(File('${tmp.path}/words.sqlite.download').existsSync(), isFalse);
  });

  test('어떤 실패도 예외를 던지지 않는다 (manifest 호출 자체가 실패)', () async {
    final prefs = await SharedPreferences.getInstance();
    final svc = NativeSyncService(
      db: currentDb,
      prefs: prefs,
      swapDb: (current, newDb) async => current,
      manifestUrl: _manifestUrl,
      httpClient: MockClient((request) async => throw const SocketException('no route')),
      connectivity: () async => const [ConnectivityResult.wifi],
      downloadDir: () async => tmp,
    );

    final result = await svc.sync();

    expect(result.outcome, SyncOutcome.failedDownload);
    expect(result.error, isNotNull);
  });

  test('정상 흐름: 체크섬·sanity 통과 → swapDb 호출, success 반환', () async {
    File? swappedWith;
    final svc = await service(
      swapDb: (current, newDb) async {
        swappedWith = newDb;
        return current;
      },
    );
    final prefs = await SharedPreferences.getInstance();

    final result = await svc.sync();

    expect(result.outcome, SyncOutcome.success);
    expect(result.newDbVersion, 2);
    expect(swappedWith, isNotNull);
    expect(swappedWith!.existsSync(), isTrue,
        reason: 'swapDb가 파일 자체를 옮기지 않는 한 임시 파일은 그대로 남는다');
    expect(prefs.getInt(lastSyncAtPrefsKey), isNotNull);
  });

  test('swapDb가 예외를 던지면 → failedSwap (failedDownload로 뭉개지지 않음), '
      '임시 파일 삭제됨', () async {
    final svc = await service(
      swapDb: (current, newDb) async => throw StateError('교체 실패'),
    );

    final result = await svc.sync();

    expect(result.outcome, SyncOutcome.failedSwap);
    expect(result.error, isA<StateError>());
    expect(File('${tmp.path}/words.sqlite.download').existsSync(), isFalse);
  });
}
