// 공통 빈 상태·오류 표시 (07-07-02, UI-GUIDE 4절 "빈 상태·오류"): 아이콘
// 없이 heading 한 줄 + body 한 줄(+ 선택적 caption 한 줄).
//
// loading_view.dart와 같은 이유로 `Theme.of(context)`만 읽는다 —
// `GameColors.of(context)!`를 쓰지 않는다(테마 없는 `MaterialApp`에서도
// 떠야 하는 화면들이 이 위젯을 쓴다).
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 본문 최대 폭 (UI-GUIDE 4절 "본문 최대 폭": 560).
const double _maxBodyWidth = 560;

/// UI-GUIDE 4절 빈 상태·오류 공통 레이아웃. 아이콘 없음.
class GameEmptyState extends StatelessWidget {
  final String title; // heading 1줄
  final String? message; // body 1줄
  final String? hint; // caption 1줄
  const GameEmptyState({super.key, required this.title, this.message, this.hint});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GameSpace.xl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxBodyWidth),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: t.textTheme.titleMedium
                    ?.copyWith(color: t.colorScheme.onSurface),
              ),
              if (message != null) ...[
                const SizedBox(height: GameSpace.s),
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: t.textTheme.bodyLarge
                      ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                ),
              ],
              if (hint != null) ...[
                const SizedBox(height: GameSpace.s),
                Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: t.textTheme.bodySmall
                      ?.copyWith(color: t.colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
