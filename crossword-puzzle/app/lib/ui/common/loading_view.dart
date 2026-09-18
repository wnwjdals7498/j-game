// 선형 로딩 표시 (07-07-02, UI-GUIDE 3.3 E-11). 원형 스피너 5개를 전부
// 이 위젯으로 대체한다.
//
// `Theme.of(context)`만 읽는다 — `GameColors.of(context)!`를 쓰면 안 된다.
// 부트스트랩 로딩·오류 화면(shell_test.dart)과 라이선스 화면
// (home_settings_test.dart)이 **테마 없는 `MaterialApp`**으로 이 화면들을
// 띄우므로 확장이 없어 null 역참조로 죽는다. UI-GUIDE 2.2 매핑
// (`onSurface = ink`, `onSurfaceVariant = inkMuted`)과 2.4 매핑
// (`titleMedium = heading`, `bodyLarge = body`, `bodySmall = caption`)이
// 테마가 있을 때 같은 값을 주므로 손해가 없다.
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 상단 2dp 선형 진행 표시 (UI-GUIDE 3.3 E-11). [message]가 있으면 그 아래
/// 가운데에 안내 문구를 보여준다.
///
/// [child]는 중앙 영역을 완전히 대신 그려야 할 때 쓴다(예: 부트스트랩
/// 로딩 화면의 "앱 이름 + 안내" 두 줄) — 그래도 상단 선형 표시는 이
/// 위젯을 통해서만 만든다(E-11 정의가 한 곳에 있어야 한다). [message]와
/// 함께 쓰지 않는다.
class GameLoadingView extends StatelessWidget {
  final String? message;
  final Widget? child;
  const GameLoadingView({super.key, this.message, this.child});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(children: [
      const LinearProgressIndicator(minHeight: 2), // UI-GUIDE 3.3 E-11
      Expanded(child: Center(
        child: child ?? (message == null ? const SizedBox.shrink() : Padding(
          padding: const EdgeInsets.all(GameSpace.l),
          child: Text(message!, textAlign: TextAlign.center,
              style: t.textTheme.bodyLarge?.copyWith(color: t.colorScheme.onSurfaceVariant)),
        )),
      )),
    ]);
  }
}
