// 구획 헤더 (07-07-03). `settings_page.dart`의 `_SectionHeader`를 여기로
// 옮기고 스타일만 UI-GUIDE 2.4 `label`로 바꾼다. `colorScheme.primary`
// (= `ink`)가 아니라 `inkMuted`를 쓴다 — 구획 제목이 본문보다 눈에 덜
// 띄어야 한다(UI-GUIDE 1절 "타이포가 장식").
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(GameSpace.l, GameSpace.xl, GameSpace.l, GameSpace.xs),
        child: Text(title, style: Theme.of(context).textTheme.labelLarge
            ?.copyWith(color: GameColors.of(context).inkMuted)));
}
