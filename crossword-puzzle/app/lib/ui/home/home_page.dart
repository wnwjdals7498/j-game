// 홈 화면 (04-06 "홈 화면"). 누적 통계 + 레벨 목록(잠금/해제/클리어).
//
// 레벨 목록은 [HomeModel.load]가 `StatRepository.bestScores()`(단일 쿼리)로
// 전체 레벨의 최고 점수를 한 번에 가져와 만든다 — N+1 없음 (04-06 DoD).
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../puzzle/puzzle_page.dart';
import '../state/app_scope.dart';
import '../state/home_model.dart';
import '../state/puzzle_model.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
        title: const Text('단어 연상 퀴즈'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '설정',
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
          ),
        ],
      ),
      body: model.loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _SummaryHeader(summary: model.summary),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: model.statuses.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) => _LevelRow(status: model.statuses[i]),
                  ),
                ),
              ],
            ),
    );
  }
}

/// 누적 정답률·푼 단어 수 (04-06 "홈 화면" 표 — `StatRepository.summary()`).
class _SummaryHeader extends StatelessWidget {
  final ({int correct, int wrong, int words})? summary;

  const _SummaryHeader({required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final total = (s?.correct ?? 0) + (s?.wrong ?? 0);
    // 제출 기록이 아예 없으면(분모 0) 퍼센트가 정의되지 않는다 — '-'로 표시.
    final rateText = total == 0 ? '-' : '${(s!.correct / total * 100).round()}%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatItem(label: '누적 정답률', value: rateText),
          _StatItem(label: '푼 단어', value: '${s?.words ?? 0}개'),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.headlineSmall),
      ],
    );
  }
}

/// 레벨 한 줄. 잠금(🔒)/해제-미클리어(─)/클리어(★ + 점수) 3가지 상태
/// (04-06 "홈 화면" 도식).
class _LevelRow extends StatelessWidget {
  final LevelStatus status;

  const _LevelRow({required this.status});

  @override
  Widget build(BuildContext context) {
    final spec = status.spec;
    final colors = Theme.of(context).colorScheme;
    final titleColor = status.unlocked ? null : colors.onSurfaceVariant;

    return ListTile(
      leading: CircleAvatar(child: Text('${spec.id}')),
      title: Text(spec.name, style: TextStyle(color: titleColor)),
      trailing: _Trailing(status: status),
      // 잠긴 레벨도 탭은 받는다 — 스낵바 안내를 보여줘야 하므로
      // `enabled: false`(InkWell 자체를 죽임)를 쓰지 않는다.
      onTap: () => _onTap(context),
    );
  }

  void _onTap(BuildContext context) {
    if (!status.unlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('이전 레벨을 클리어해야 열립니다')),
      );
      return;
    }
    // 새 seed로 퍼즐 화면 진입 (04-05 puzzle_page.dart "실제 진입은 홈이
    // 레벨과 새 seed를 정해 이 위젯을 직접 생성해 Navigator.push한다").
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PuzzlePage(spec: status.spec, seed: newSeed()),
    ));
  }
}

class _Trailing extends StatelessWidget {
  final LevelStatus status;

  const _Trailing({required this.status});

  @override
  Widget build(BuildContext context) {
    if (!status.unlocked) {
      return const Icon(Icons.lock, semanticLabel: '잠김');
    }
    if (status.cleared) {
      final score = status.bestScore!;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star, color: Colors.amber),
          const SizedBox(width: 4),
          Text('${score >= 0 ? '+' : ''}$score'),
        ],
      );
    }
    return const Text('─'); // 해제됐으나 미클리어
  }
}
