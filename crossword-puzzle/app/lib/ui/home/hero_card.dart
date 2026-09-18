// 홈 화면 "이어하기" 히어로 (07-05-02). 다음에 풀 레벨을 크게 보여준다.
//
// 레벨 이름의 정확한 단어 수는 생성 전에는 확정값이 없다 —
// `LevelSpec.minWordCount`(coreCount + fillQuotas 최솟값)만 읽을 수 있어
// "개 이상"으로 적는다 (docs/plan/07-05-02.hero-and-stats.md).
import 'package:flutter/material.dart';

import '../../domain/model/level_spec.dart';
import '../state/home_model.dart';
import '../theme/tokens.dart';

class HeroCard extends StatelessWidget {
  final LevelStatus status;
  final bool allCleared; // 라벨만 바꾼다 — 규칙 추가 아님(N-04)
  final VoidCallback onStart;

  const HeroCard({
    super.key,
    required this.status,
    required this.allCleared,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.of(context);
    final LevelSpec spec = status.spec;
    final label = allCleared ? '다시 도전' : '이어하기';
    final subtitle =
        '레벨 ${spec.id} · ${spec.width}×${spec.height} · 단어 ${spec.minWordCount}개 이상';

    return Container(
      padding: const EdgeInsets.all(GameSpace.xl),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(GameRadius.panel),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GameType.label.copyWith(color: colors.inkMuted)),
          const SizedBox(height: GameSpace.s),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              spec.name,
              style: GameType.display.copyWith(color: colors.ink),
            ),
          ),
          const SizedBox(height: GameSpace.xs),
          Text(subtitle, style: GameType.caption.copyWith(color: colors.inkMuted)),
          const SizedBox(height: GameSpace.l),
          FilledButton(onPressed: onStart, child: const Text('시작')),
        ],
      ),
    );
  }
}
