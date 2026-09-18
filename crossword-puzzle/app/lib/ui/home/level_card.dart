// 레벨 카드 3상태(잠금·해제·클리어)와 해제 직후 자물쇠→번호 플립(E-10).
// (07-05-03, 계약: docs/UI-GUIDE.md 2.2·2.5·3.3(E-10)).
import 'dart:math';

import 'package:flutter/material.dart';

import '../state/home_model.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

class LevelCard extends StatefulWidget {
  final LevelStatus status;

  /// E-10 대상 카드 1장만 true — 이번 [HomeModel.load]에서 새로 해제된 카드.
  final bool justUnlocked;

  /// 잠긴 카드도 탭을 받는다 — 스낵바 안내를 보여줘야 하므로.
  final VoidCallback onTap;

  const LevelCard({
    super.key,
    required this.status,
    required this.justUnlocked,
    required this.onTap,
  });

  @override
  State<LevelCard> createState() => _LevelCardState();
}

class _LevelCardState extends State<LevelCard> {
  late bool _showLock = widget.justUnlocked;

  @override
  void initState() {
    super.initState();
    if (_showLock) _scheduleFlip();
  }

  @override
  void didUpdateWidget(covariant LevelCard old) {
    // 재로드로 같은 Element가 갱신된 경우 (같은 그리드 위치 → 같은 State).
    super.didUpdateWidget(old);
    if (widget.justUnlocked && !old.justUnlocked) {
      _showLock = true;
      _scheduleFlip();
    }
  }

  void _scheduleFlip() => WidgetsBinding.instance
      .addPostFrameCallback((_) { if (mounted) setState(() => _showLock = false); });

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.of(context);
    final motion = GameMotion.of(context);
    final status = widget.status;
    final spec = status.spec;
    final unlocked = status.unlocked;
    final cleared = status.cleared;

    // 감소 모션을 먼저 걸러 낸다 — 시간이 0이면 자물쇠 단계를 아예 건너뛴다(3.2).
    // 그래야 테스트가 첫 프레임에서 확정된다.
    final showLock = !unlocked || (_showLock && motion.base != Duration.zero);

    final nameColor = unlocked ? colors.ink : colors.inkMuted;
    final Border? border = cleared
        ? null
        : Border.all(
            color: unlocked ? colors.ink : colors.line,
            width: unlocked ? GameRadius.outlineButton : GameRadius.hairline,
          );

    return InkWell(
      borderRadius: BorderRadius.circular(GameRadius.panel),
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.all(GameSpace.l),
        decoration: BoxDecoration(
          color: cleared ? colors.surfaceAlt : colors.surface,
          borderRadius: BorderRadius.circular(GameRadius.panel),
          border: border,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AnimatedSwitcher(
                  duration: motion.base,
                  // 세로축 회전(pi는 dart:math). 나가는 자식도 같은 빌더를 거꾸로 탄다.
                  transitionBuilder: (child, anim) => AnimatedBuilder(
                    animation: anim,
                    child: child,
                    builder: (_, c) => Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(
                            (1 - motion.curveStandard.transform(anim.value)) * pi / 2),
                      child: c,
                    ),
                  ),
                  child: SizedBox(
                    key: ValueKey(showLock),
                    width: 24,
                    height: 24,
                    child: Center(
                      child: showLock
                          ? Icon(Icons.lock,
                              semanticLabel: '잠김', color: colors.inkMuted)
                          : Text('${spec.id}',
                              style: GameType.heading.copyWith(color: colors.ink)),
                    ),
                  ),
                ),
                if (cleared) ...[
                  const SizedBox(width: GameSpace.s),
                  Icon(Icons.star, color: colors.accent),
                  const SizedBox(width: GameSpace.xs),
                  Text(
                    '${status.bestScore! >= 0 ? '+' : ''}${status.bestScore}',
                    style: GameType.label.copyWith(color: colors.ink),
                  ),
                ],
              ],
            ),
            const Spacer(),
            Text(
              spec.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GameType.heading.copyWith(color: nameColor),
            ),
          ],
        ),
      ),
    );
  }
}
