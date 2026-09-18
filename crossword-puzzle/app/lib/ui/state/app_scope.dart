// 앱 전역 의존성 보관 (04-01).
//
// `ChangeNotifier`가 아니다 — DB·리포지토리는 앱 시작 시 1회 생성해 트리 루트에
// `Provider.value`로 주입하고 그 뒤로 바뀌지 않는다. 화면 간 상태 변화는
// `SettingsModel`/`HomeModel`/`PuzzleModel`(ChangeNotifier)이 담당한다.
import '../../data/db/app_database.dart';
import '../../data/hint_repository.dart';
import '../../data/stat_repository.dart';
import '../../data/sync/sync_result.dart' show SyncService;
import '../../domain/generator/grid_generator.dart';
import '../../domain/repository/word_repository.dart';

/// 앱 전역 의존성. main에서 1회 만들어 트리 루트에 Provider로 넣는다.
class AppScope {
  final AppDatabase db;
  final WordRepository words;
  final StatRepository stats;
  final GridGenerator generator;

  /// 힌트(뜻풀이·유의어) 조회 (04-03). `PuzzleModel.load`가 퍼즐 생성 직후
  /// 한 번에 읽어 캐시한다.
  final HintRepository hints;

  /// 갱신(05-02~05-04). 웹에서는 `null`(1차 범위 밖) — 설정 화면이 이 값의
  /// null 여부로 "지금 갱신" UI를 보일지 정한다. 갱신 성공 후 `db`는 갱신되지
  /// 않는다 — `SyncService`가 내부적으로 새 `AppDatabase`를 들고 있게 되지만
  /// (교체 후 기존 연결은 닫힌다), 이 `AppScope.db`는 그 시점의 연결을 그대로
  /// 가리킨다. 그래서 갱신 성공 시 "앱을 다시 시작해 주세요"로 안내한다
  /// (05-04 "막히면" — `AppScope`를 재구독 가능하게 바꾸는 대신 고른 1차
  /// 범위 결정).
  final SyncService? syncService;

  const AppScope({
    required this.db,
    required this.words,
    required this.stats,
    required this.generator,
    required this.hints,
    this.syncService,
  });
}
