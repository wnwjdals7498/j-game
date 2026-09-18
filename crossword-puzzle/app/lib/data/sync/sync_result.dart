// SyncService의 공개 인터페이스와 결과 타입 (05-02, 05-04).
//
// 이 파일은 dart:io/http/connectivity_plus를 쓰지 않는다 — 일부러다.
// `AppScope`(ui/state, 네이티브·웹 양쪽에서 컴파일된다)가 `SyncService?`
// 필드를 가지려면 그 타입 자체가 웹에서도 해석 가능해야 한다. 실제 구현체
// (`sync_service.dart`의 `NativeSyncService`)는 dart:io를 직접 써서 네이티브
// 전용이지만, 이 추상 인터페이스만 참조하면 UI 코드는 플랫폼을 몰라도 된다 —
// `data/db/open_native.dart`/`open_web.dart`/`open_stub.dart`의 `makeSyncService`가
// 각 플랫폼에서 이 타입의 인스턴스(또는 웹/스텁에서는 `null`)를 만든다.
/// `shared_preferences` 키. **`meta` 테이블에 넣지 않는다** — DB 교체(05-03)로
/// `meta`가 새 DB 것으로 통째로 갈아엎이므로 갱신 시각이 사라진다(05-02
/// "`last_sync_at` 저장 위치"). epoch milliseconds로 저장한다. `NativeSyncService`
/// 의 주기 계산과 설정 화면(05-04)의 "마지막 갱신" 표시가 같은 키를 공유한다
/// — UI 코드가 쓸 수 있어야 해서 (네이티브 전용인 sync_service.dart가 아니라)
/// 여기 둔다.
const lastSyncAtPrefsKey = 'last_sync_at';

/// 앱 시작 시 자동 갱신(`main.dart`)이 성공하면 `true`로 세운다. 자동 갱신은
/// 위젯 트리가 없을 때 끝날 수 있어 그 자리에서 스낵바를 못 띄운다 —
/// `HomePage`가 다음 진입 때 이 값을 보고 한 번 안내한 뒤 지운다. 안 그러면
/// `AppScope.db`가 이미 닫힌 채로(05-03 `DbSwapper.swap`) 사용자가 아무
/// 설명 없이 갑자기 오류 화면을 보게 된다(05-04 리뷰에서 CRITICAL로 지적됨).
const pendingSyncNoticePrefsKey = 'pending_sync_notice';

abstract class SyncService {
  /// [force]는 설정의 "지금 갱신" 버튼용 — 주기·네트워크 조건을 건너뛴다.
  /// [wifiOnly]는 호출 시점의 `SettingsModel.wifiOnlySync` 값을 그대로
  /// 넘겨받는다(이 인터페이스가 ui/state를 몰라도 되게 하기 위함).
  Future<SyncResult> sync({bool force = false, bool wifiOnly = true});

  /// 기본 생성된 리소스(예: `http.Client`)를 정리한다. 웹/스텁 구현은
  /// 아무것도 안 해도 된다.
  void dispose();
}

enum SyncOutcome {
  skippedNotDue,
  skippedOffline,
  skippedUpToDate,
  skippedSchemaIncompatible,
  skippedAppTooOld,
  failedDownload,
  failedChecksum,
  failedSanity,
  failedSwap,
  success,
}

class SyncResult {
  final SyncOutcome outcome;
  final int? newDbVersion;
  final int? wordCount;
  final Object? error;

  const SyncResult(this.outcome, {this.newDbVersion, this.wordCount, this.error});

  @override
  String toString() =>
      'SyncResult($outcome, newDbVersion: $newDbVersion, '
      'wordCount: $wordCount, error: $error)';
}
