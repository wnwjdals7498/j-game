// 홈 화면 (04-06 "홈 화면"). 누적 통계 + 레벨 목록(잠금/해제/클리어).
//
// 레벨 목록은 [HomeModel.load]가 `StatRepository.bestScores()`(단일 쿼리)로
// 전체 레벨의 최고 점수를 한 번에 가져와 만든다 — N+1 없음 (04-06 DoD).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/sync/sync_result.dart' show pendingSyncNoticePrefsKey;
import '../../domain/model/level_spec.dart';
import '../common/empty_state.dart';
import '../common/loading_view.dart';
import '../puzzle/puzzle_page.dart';
import '../state/app_scope.dart';
import '../state/home_model.dart';
import '../state/puzzle_model.dart';
import '../theme/fade_through_route.dart';
import '../theme/tokens.dart';
import 'hero_card.dart';
import 'level_card.dart';
import 'stats_row.dart';

/// 본문 최대 폭. 태블릿·웹에서 좌우로 늘어지지 않게 가운데 정렬한다
/// (UI-GUIDE 4절 "본문 최대 폭": 560).
const double _maxBodyWidth = 560;

/// 레벨 진입(04-05: 홈이 레벨과 새 seed를 정해 직접 push). 돌아오면 해제·통계가
/// 달라졌을 수 있어 다시 읽는다 — `ChangeNotifierProvider(create: ...load())`는
/// 홈 위젯이 살아 있는 동안 재로드하지 않는다.
void _openLevel(BuildContext context, LevelSpec spec) {
  final model = context.read<HomeModel>();
  Navigator.of(context)
      .push(GameRoute(
        builder: (_) => PuzzlePage(spec: spec, seed: newSeed()),
      ))
      .then((_) {
    if (context.mounted) model.load(); // 홈이 이미 사라졌으면 notifyListeners 금지
  });
}

/// 레벨 카드 탭(07-05-03). 잠긴 카드도 받아 스낵바 안내를 보여준다(기존 동작 유지).
void _onCardTap(BuildContext context, LevelStatus s) {
  if (!s.unlocked) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('이전 레벨을 클리어해야 열립니다')), // INV-09, 글자 무변경
    );
    return;
  }
  _openLevel(context, s.spec);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // 앱 시작 시 자동 갱신(main.dart)이 성공했으면 여기서 한 번 안내한다 —
    // 그 시점엔 위젯 트리가 없어 스낵바를 못 띄웠다(05-04 리뷰 CRITICAL:
    // `AppScope.db`가 이미 닫혔는데 아무 설명이 없던 문제). 프레임이 그려진
    // 뒤로 미룬다 — `ScaffoldMessenger`는 build 도중엔 못 쓴다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowSyncNotice());
  }

  Future<void> _maybeShowSyncNotice() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(pendingSyncNoticePrefsKey) != true) return;
    await prefs.setBool(pendingSyncNoticePrefsKey, false); // 한 번만 보여준다
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('단어 사전이 갱신되었습니다. 반영하려면 앱을 다시 시작해 주세요.'),
        duration: Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<HomeModel>(
      create: (context) => HomeModel(context.read<AppScope>())..load(),
      child: const _HomeBody(),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody();

  @override
  Widget build(BuildContext context) {
    final model = context.watch<HomeModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('J Crossword Puzzle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '설정',
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: model.loading && model.statuses.isEmpty
          ? const GameLoadingView()
          : model.error != null
              ? const GameEmptyState(
                  title: '단어 데이터를 불러오지 못했습니다.',
                  message: '앱을 다시 시작해 주세요.',
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: _maxBodyWidth),
                    child: ListView(
                      padding: const EdgeInsets.all(GameSpace.l),
                      children: [
                        if (model.nextLevel != null)
                          HeroCard(
                            status: model.nextLevel!,
                            allCleared: model.allCleared,
                            onStart: () =>
                                _openLevel(context, model.nextLevel!.spec),
                          ),
                        const SizedBox(height: GameSpace.xl),
                        StatsRow(summary: model.summary),
                        const SizedBox(height: GameSpace.l),
                        const Divider(height: 1),
                        const SizedBox(height: GameSpace.l),
                        GridView.count(
                          crossAxisCount: 2,
                          childAspectRatio: 1.15,
                          mainAxisSpacing: GameSpace.m,
                          crossAxisSpacing: GameSpace.m,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(), // 바깥 ListView가 스크롤한다
                          children: [
                            for (final s in model.statuses)
                              LevelCard(
                                status: s,
                                justUnlocked: s.spec.id == model.justUnlockedId,
                                onTap: () => _onCardTap(context, s),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}

