// 앱 전역 의존성 보관 (04-01).
//
// `ChangeNotifier`가 아니다 — DB·리포지토리는 앱 시작 시 1회 생성해 트리 루트에
// `Provider.value`로 주입하고 그 뒤로 바뀌지 않는다. 화면 간 상태 변화는
// `SettingsModel`/`HomeModel`/`PuzzleModel`(ChangeNotifier)이 담당한다.
import '../../data/db/app_database.dart';
import '../../data/stat_repository.dart';
import '../../domain/generator/grid_generator.dart';
import '../../domain/repository/word_repository.dart';

/// 앱 전역 의존성. main에서 1회 만들어 트리 루트에 Provider로 넣는다.
class AppScope {
  final AppDatabase db;
  final WordRepository words;
  final StatRepository stats;
  final GridGenerator generator;

  const AppScope({
    required this.db,
    required this.words,
    required this.stats,
    required this.generator,
  });
}
