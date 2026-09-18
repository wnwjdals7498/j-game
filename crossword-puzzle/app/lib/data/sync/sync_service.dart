// 6개월마다 새 DB를 내려받는 흐름 (05-02, 05-sync.md "동작"). 실패는 어느
// 단계든 **조용히 중단**하고 기존 DB를 그대로 쓴다 — 사용자 흐름을 막지 않는다.
//
// 네이티브 전용이다. 웹은 1차 범위 밖(REVIEW 4.2 (a)) — 이 파일은 dart:io를
// 직접 써서 웹에서 컴파일되지 않는다. 그래서 `SyncService`(추상 인터페이스,
// sync_result.dart)와 이 파일의 `NativeSyncService`(구현)를 분리했다 —
// `AppScope`(ui/state)는 `SyncService?` 타입만 알면 되고, 이 파일은 아무도
// 웹 빌드에서 import하지 않는다. 실제로 만드는 곳은
// `data/db/open_native.dart`의 `makeSyncService`(05-04) — 웹/스텁의 같은
// 이름 함수는 `null`을 돌려준다.
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../db/app_database.dart';
import 'manifest.dart';
import 'sync_result.dart';

/// 05-03(`DbSwapper.swap`)이 채워 넣는 주입 지점. 05-03 문서의
/// `DbSwapper.swap(AppDatabase current, File newDb)`와 시그니처를 맞춰
/// 뒀다 — 실제 연결은 `swapDb: DbSwapper(...).swap`처럼 메서드 티어오프
/// 하나로 끝나야 한다. 테스트에서는 가짜 함수로 갈아 끼운다.
typedef DbSwap = Future<AppDatabase> Function(AppDatabase current, File newDb);

/// GitHub Releases의 고정 URL 하나 (05-01 "배포처"). `tools/release_db.py`의
/// `REPO` 상수와 같은 저장소를 가리켜야 한다.
const defaultManifestUrl =
    'https://github.com/wnwjdals7498/j-game/releases/latest/download/manifest.json';

/// `tools/release_db.py`의 `MAX_SIZE_BYTES`와 같은 값(05-01). manifest가
/// 선언한 `size_bytes`가 이보다 크면 다운로드 자체를 시작하지 않는다 —
/// `size_bytes`는 서버(또는 하이재킹된 리다이렉트)가 주장하는 값일 뿐이라
/// 그대로 믿고 기기 저장공간을 무제한으로 쓰면 안 된다.
const _maxSizeBytes = 50 * 1024 * 1024;

class NativeSyncService implements SyncService {
  NativeSyncService({
    required this.db,
    required this.prefs,
    required this.swapDb,
    this.manifestUrl = defaultManifestUrl,
    this.appVersion = '1.0.0',
    this.intervalDays = 180,
    this.onProgress,
    http.Client? httpClient,
    Future<List<ConnectivityResult>> Function()? connectivity,
    Future<Directory> Function()? downloadDir,
  })  : _httpClient = httpClient ?? http.Client(),
        _connectivity = connectivity ?? Connectivity().checkConnectivity,
        _downloadDir = downloadDir ?? getApplicationDocumentsDirectory;

  /// 마지막으로 성공한 교체 결과로 갱신된다. 교체 성공 시 05-03이 반환한 새
  /// `AppDatabase`로 다시 대입하지 않으면 두 번째 `sync()` 호출이 이미 닫힌
  /// DB에 질의하게 된다(교체 후 기존 연결은 05-03이 닫는다) — 그래서
  /// `final`이 아니다. 05-04는 성공 후 이 값을 다시 주입하거나(재구독), 더
  /// 단순하게 "앱을 다시 시작해 주세요"로 안내할 수 있다(05-04 "막히면"이
  /// 후자를 1차 범위로 골랐다).
  AppDatabase db;

  final SharedPreferences prefs;

  /// 05-03이 구현할 실제 교체 로직. 이 서비스는 "언제 교체할지"만 안다.
  final DbSwap swapDb;

  final String manifestUrl;

  /// 현재 앱 버전. `settings_page.dart`의 `_appVersionName`처럼
  /// pubspec.yaml `version`과 수동으로 맞춰야 하는 상수다 — `package_info_plus`
  /// 를 새로 넣지 않는 1차 범위 결정(04-06과 같은 이유)을 그대로 따른다.
  /// **이 값이 실제 버전보다 낮아지면 모든 갱신이 `skippedAppTooOld`로
  /// 막힌다** — pubspec.yaml을 올릴 때 반드시 같이 맞춘다.
  final String appVersion;

  final int intervalDays;

  /// 다운로드 진행률 콜백(받은 바이트, 전체 바이트). 05-04가 설정 화면의
  /// 진행률 표시에 연결한다. 05-02 자체는 쓰지 않는다.
  final void Function(int received, int total)? onProgress;

  final http.Client _httpClient;
  final Future<List<ConnectivityResult>> Function() _connectivity;

  /// 다운로드 임시 파일을 놓을 디렉터리. **05-03의 `rename`이 원자적이려면
  /// 최종 DB 파일과 같은 파일시스템 안이어야 한다** — 그래서 기본값은
  /// `Directory.systemTemp`가 아니라 앱 문서 디렉터리다(다른 파티션일 수
  /// 있는 시스템 임시 폴더를 쓰면 05-03의 rename이 복사+삭제로 바뀐다).
  final Future<Directory> Function() _downloadDir;

  /// 진행 중인 `sync()` 호출 (05-04 리뷰에서 발견: 재진입 방지가 없으면
  /// 앱 시작 시 자동 갱신과 "지금 갱신" 버튼이 같은 임시 파일
  /// (`words.sqlite.download`)·같은 `words.sqlite`/`.bak`을 동시에 건드릴 수
  /// 있다). 진행 중에 또 불리면 새로 시작하지 않고 **같은 결과에 합류**한다
  /// — 두 번째 호출자가 `force`/`wifiOnly`를 다르게 줬어도 첫 호출이 이미
  /// 정한 조건으로 끝난 결과를 같이 받는다(둘 다 새로 던지는 것보다 안전한
  /// 절충).
  Future<SyncResult>? _inFlight;

  /// [force]는 설정의 "지금 갱신" 버튼용 — 주기·네트워크 조건을 건너뛴다.
  /// [wifiOnly]는 호출 시점의 `SettingsModel.wifiOnlySync` 값을 그대로
  /// 넘겨받는다 — data 계층이 ui/state를 몰라도 되게 하려고 bool 하나로
  /// 전달받는다(이 서비스가 SettingsModel을 직접 참조하지 않는 이유).
  @override
  Future<SyncResult> sync({bool force = false, bool wifiOnly = true}) {
    final existing = _inFlight;
    if (existing != null) return existing;
    final future = _syncOnce(force: force, wifiOnly: wifiOnly);
    _inFlight = future;
    future.whenComplete(() => _inFlight = null);
    return future;
  }

  Future<SyncResult> _syncOnce({required bool force, required bool wifiOnly}) async {
    File? tmp;
    try {
      if (!force && !_isDue()) {
        return const SyncResult(SyncOutcome.skippedNotDue);
      }
      if (!await _hasNetwork(requireWifi: !force && wifiOnly)) {
        return const SyncResult(SyncOutcome.skippedOffline);
      }

      final manifest = await _fetchManifest();

      final currentVersion =
          int.tryParse(await db.metaValue('db_version') ?? '0') ?? 0;
      if (manifest.dbVersion <= currentVersion) {
        await _recordSyncAttempt();
        return const SyncResult(SyncOutcome.skippedUpToDate);
      }
      if (manifest.schemaVersion != AppDatabase.expectedSchemaVersion) {
        // 스키마가 안 맞으면 다음 실행에서도 안 맞을 가능성이 높다(앱을
        // 올려야 풀린다) — skippedUpToDate와 같은 이유로 기록해 매 실행마다
        // manifest를 다시 받지 않게 한다. "지금 갱신"(force)은 이 주기를
        // 무시하므로 사용자가 즉시 재확인할 수 있다.
        await _recordSyncAttempt();
        return const SyncResult(SyncOutcome.skippedSchemaIncompatible);
      }
      if (!versionAtLeast(appVersion, manifest.minAppVersion)) {
        await _recordSyncAttempt();
        return const SyncResult(SyncOutcome.skippedAppTooOld);
      }

      tmp = await _download(manifest);
      if (tmp == null) return const SyncResult(SyncOutcome.failedDownload);

      if (!await _verifyChecksum(tmp, manifest.sha256)) {
        await _deleteIfExists(tmp);
        return const SyncResult(SyncOutcome.failedChecksum);
      }
      if (!await _sanityCheck(tmp, manifest)) {
        await _deleteIfExists(tmp);
        return const SyncResult(SyncOutcome.failedSanity);
      }

      try {
        db = await swapDb(db, tmp);
      } catch (e) {
        await _deleteIfExists(tmp);
        return SyncResult(SyncOutcome.failedSwap, error: e);
      }

      // 교체는 이미 끝났다 — 여기서부터 실패해도 success를 덮으면 안 된다
      // (last_sync_at 기록 실패 정도로 방금 끝난 갱신을 무효로 만들지 않는다).
      await _recordSyncAttempt();
      return SyncResult(SyncOutcome.success,
          newDbVersion: manifest.dbVersion, wordCount: manifest.wordCount);
    } catch (e) {
      // 어떤 실패도 게임을 막지 않는다 (05-02 "실패는 조용히 중단") —
      // 정리(_deleteIfExists)조차 실패해도 이 밖으로 예외가 새어 나가면 안
      // 된다(그 함수 자체가 실패를 삼킨다).
      if (tmp != null) await _deleteIfExists(tmp);
      return SyncResult(SyncOutcome.failedDownload, error: e);
    }
  }

  bool _isDue() {
    final last = prefs.getInt(lastSyncAtPrefsKey) ?? 0;
    final days = (DateTime.now().millisecondsSinceEpoch - last) / 86400000;
    return days >= intervalDays;
  }

  /// 확인만 하고 갱신이 없어도(예: skippedUpToDate) 호출한다 — 안 그러면
  /// 매 실행마다 manifest를 받는다(05-02). 기록 자체가 실패해도(디스크 꽉 참
  /// 등) 이미 끝난 갱신/확인 결과를 뒤집지 않는다 — 다음 실행에서 다시
  /// 시도될 뿐이다.
  Future<void> _recordSyncAttempt() async {
    try {
      await prefs.setInt(
          lastSyncAtPrefsKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<bool> _hasNetwork({required bool requireWifi}) async {
    final results = await _connectivity();
    if (results.isEmpty || results.every((r) => r == ConnectivityResult.none)) {
      return false;
    }
    if (!requireWifi) return true;
    // ethernet도 Wi-Fi처럼 종량제가 아닌 연결로 본다 (05-02는 Wi-Fi/모바일만
    // 언급하지만, 유선 연결을 모바일 데이터 취급해 막을 이유가 없다).
    //
    // iOS/macOS 참고: VPN이 켜져 있으면(Wi-Fi 위에서도) connectivity_plus가
    // `other`만 돌려주는 플랫폼 특성이 있다 — 그런 기기는 자동 갱신이
    // 조용히 계속 스킵된다. "지금 갱신"(force: true)은 이 검사 자체를
    // 건너뛰므로 그 경우에도 수동 갱신은 된다.
    return results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
  }

  Future<Manifest> _fetchManifest() async {
    final res = await _httpClient
        .get(Uri.parse(manifestUrl))
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw ManifestError('manifest 다운로드 실패: HTTP ${res.statusCode}');
    }
    // res.body는 헤더가 없거나 application/octet-stream이면 latin1로 디코드
    // 된다(package:http 기본값) — GitHub Releases 자산은 실제로 그렇게
    // 온다. UTF-8 텍스트인 notes 등이 깨지지 않도록 bodyBytes를 직접
    // UTF-8로 디코드한다.
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return Manifest.fromJson(json);
  }

  /// 스트리밍으로 받는다 — 10MB를 메모리에 다 올리지 않는다(05-02). 재개
  /// (resume)는 1차 범위 밖.
  Future<File?> _download(Manifest m) async {
    if (m.sizeBytes <= 0 || m.sizeBytes > _maxSizeBytes) return null;

    final dir = await _downloadDir();
    final tmp = File('${dir.path}/words.sqlite.download');
    await _deleteIfExists(tmp);

    try {
      final req = http.Request('GET', Uri.parse(m.url));
      final res =
          await _httpClient.send(req).timeout(const Duration(minutes: 5));
      if (res.statusCode != 200) return null;

      final sink = tmp.openWrite();
      var received = 0;
      try {
        await res.stream.forEach((chunk) {
          received += chunk.length;
          // manifest가 선언한 크기를 넘으면 즉시 중단한다 — 하이재킹된
          // 리다이렉트나 손상된 응답이 기기 저장공간을 무제한으로 채우는
          // 것을 막는다.
          if (received > m.sizeBytes) {
            throw const ManifestError('선언된 크기(size_bytes)를 초과함');
          }
          sink.add(chunk);
          onProgress?.call(received, m.sizeBytes);
        });
      } finally {
        // 스트림이 중간에 끊겨도 반드시 닫는다 — 안 닫으면 쓰기 핸들이 열린
        // 채로 남아 바로 아래 삭제가 Windows에서 공유 위반으로 실패한다.
        await sink.close();
      }

      if (received != m.sizeBytes) {
        await _deleteIfExists(tmp);
        return null;
      }
      return tmp;
    } catch (_) {
      await _deleteIfExists(tmp);
      return null;
    }
  }

  /// 이미 다운로드가 끝난(≤50MB) 파일이라 통째로 메모리에 올려 해시한다 —
  /// 위 `_download`의 스트리밍은 네트워크 수신 중 버퍼링을 막기 위한
  /// 것이라 이 단계와는 별개다.
  Future<bool> _verifyChecksum(File f, String expectedSha256) async {
    final bytes = await f.readAsBytes();
    return sha256.convert(bytes).toString() == expectedSha256;
  }

  static const _requiredTables = [
    'word', 'sense', 'word_char', 'word_stat', 'meta', 'puzzle_log',
  ];

  /// `package:sqlite3`로 직접 연다(drift `AppDatabase`가 아니다) — 이유
  /// 둘: (1) 진짜 DB(`db`)와 별개의 `AppDatabase` 인스턴스를 또 만들면
  /// drift가 "같은 QueryExecutor를 여러 DB 인스턴스가 쓰면 손상될 수
  /// 있다"는 경고를 매번 찍는다(서로 다른 파일이라 실제로는 안전한
  /// 오탐이지만, DB 손상이 진짜 리스크인 기능에서 그런 경고가 콘솔에
  /// 반복되는 건 나쁘다). (2) 이 파일을 열어보기만 하는 용도라 drift
  /// 마이그레이션 레이어가 필요 없다.
  Future<bool> _sanityCheck(File f, Manifest m) async {
    sqlite3.Database? probe;
    try {
      probe = sqlite3.sqlite3.open(f.path, mode: sqlite3.OpenMode.readOnly);

      final wordCount =
          probe.select('SELECT COUNT(*) AS n FROM word').first['n'] as int;
      if (wordCount <= 0) return false;

      final metaRows =
          probe.select("SELECT value FROM meta WHERE key = 'db_version'");
      if (metaRows.isEmpty || metaRows.first['value'] != '${m.dbVersion}') {
        return false;
      }

      final tables = probe
          .select("SELECT name FROM sqlite_master WHERE type='table'")
          .map((r) => r['name'] as String)
          .toSet();
      for (final t in _requiredTables) {
        if (!tables.contains(t)) return false;
      }
      return true;
    } catch (_) {
      // 유효한 SQLite 파일이 아니거나(HTML 오류 페이지 등) 필수 테이블/컬럼이
      // 없으면 sqlite3가 예외를 던진다 — sanity 실패로 취급한다.
      return false;
    } finally {
      // 반드시 닫는다 — 열린 채로 두면 05-03의 파일 교체가 Windows/일부
      // 안드로이드에서 실패한다(05-02). close 자체의 실패까지 삼켜서 이
      // 정리 실패가 failedSanity를 다른 결과로 뒤바꾸지 않게 한다.
      try {
        probe?.close();
      } catch (_) {}
    }
  }

  Future<void> _deleteIfExists(File f) async {
    // 정리 실패(파일이 일시적으로 잠김 등)가 방금 판정한 SyncResult를
    // 삼켜서 예외로 새어 나가면 안 된다 — 어차피 다음 실행이 다시 지운다.
    try {
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// 기본 생성된 `http.Client`(주입하지 않았을 때)를 정리한다. `httpClient`를
  /// 직접 주입했다면(테스트의 `MockClient` 등) 그 클라이언트의 수명은
  /// 호출자 책임이므로 이 메서드가 그것까지 닫는다는 점에 유의한다 — 이
  /// 서비스를 재사용할 계획이면 `dispose()`를 부르지 않는다.
  @override
  void dispose() => _httpClient.close();
}
