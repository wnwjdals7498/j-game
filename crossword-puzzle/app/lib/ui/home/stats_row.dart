// 홈 화면 통계 한 줄 (07-05-02). `_SummaryHeader`의 계산을 그대로 옮긴다 —
// 값 형식('-', '75%', '1개')이 곧 테스트 계약이다.
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class StatsRow extends StatelessWidget {
  final ({int correct, int wrong, int words})? summary;

  const StatsRow({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.of(context);
    final s = summary;
    final total = (s?.correct ?? 0) + (s?.wrong ?? 0);
    // 제출 기록이 아예 없으면(분모 0) 퍼센트가 정의되지 않는다 — '-'로 표시.
    final rateText = total == 0 ? '-' : '${(s!.correct / total * 100).round()}%';

    Widget label(String text) =>
        Text(text, style: GameType.label.copyWith(color: colors.inkMuted));
    Widget value(String text) =>
        Text(text, style: GameType.heading.copyWith(color: colors.ink));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        label('누적 정답률'),
        const SizedBox(width: GameSpace.s),
        value(rateText),
        const SizedBox(width: GameSpace.l),
        label('·'),
        const SizedBox(width: GameSpace.l),
        label('푼 단어'),
        const SizedBox(width: GameSpace.s),
        value('${s?.words ?? 0}개'),
      ],
    );
  }
}
