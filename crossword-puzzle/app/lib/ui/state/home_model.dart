// 홈 화면 상태 (04-06). `levels`(01-09/03-06)와 `StatRepository`(03-04)를 읽어
// 레벨별 잠금/해제·클리어 표시와 누적 통계를 채운다.
import 'package:flutter/foundation.dart';

import '../../domain/levels.dart';
import '../../domain/model/level_spec.dart';
import 'app_scope.dart';

/// 레벨 1개의 화면 표시 상태 (04-06 "홈 화면" 표).
class LevelStatus {
  final LevelSpec spec;

  /// 이전 레벨을 클리어했는가. 레벨 1은 항상 true(03-06 해제 규칙,
  /// DESIGN 5절 8번: "이전 레벨 1회 클리어").
  final bool unlocked;

  /// `bestScore >= spec.clearScore` 인가.
  final bool cleared;

  /// 이 레벨로 제출한 적 있는 최고 점수. 제출 기록이 없으면 null.
  final int? bestScore;

  const LevelStatus(
    this.spec, {
    required this.unlocked,
    required this.cleared,
    required this.bestScore,
  });
}

/// 홈 화면 상태: 레벨 목록 + 해제 상태 + 누적 통계.
class HomeModel extends ChangeNotifier {
  final AppScope scope;

  List<LevelStatus> statuses = [];
  ({int correct, int wrong, int words})? summary;

  bool loading = true;

  /// 갱신(05-04)으로 `AppScope.db`가 닫힌 뒤 조회하면 여기 담긴다 — 재시작
  /// 전까지 DB 전체가 못 쓰게 되므로(05-03 `swap()`이 기존 연결을 닫는다),
  /// 무한 로딩 스피너 대신 안내 문구를 보여준다(`home_page.dart`).
  Object? error;

  HomeModel(this.scope);

  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      summary = await scope.stats.summary();

      // `bestScores()`로 전체 레벨을 한 번에 가져온다 — 레벨마다 `bestScore`를
      // 따로 부르면 N+1(레벨 수만큼 DB 조회)이 된다 (04-06 "레벨마다 DB 조회
      // 1회 → 12회. 홈 진입마다 도는 건 낭비다").
      final best = await scope.stats.bestScores();

      final out = <LevelStatus>[];
      var prevCleared = true; // 레벨 1은 항상 해제
      for (final spec in levels) {
        final bestScore = best[spec.id];
        final cleared = bestScore != null && bestScore >= spec.clearScore;
        out.add(LevelStatus(
          spec,
          unlocked: prevCleared,
          cleared: cleared,
          bestScore: bestScore,
        ));
        prevCleared = cleared;
      }
      statuses = out;
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
