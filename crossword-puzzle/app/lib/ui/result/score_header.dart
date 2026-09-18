// lib/ui/result/score_header.dart
//
// 07-06-01 "산출물": 결과 화면 상단 점수 헤더 — 카운트업(E-06)과 정답 링.
// `result_page.dart`의 옛 헤더 `Text` 두 줄(비율/점수)을 대체한다.
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

// 링 지름 56 / 두께 4는 07-06 부모 문서 도식이 정한 이펙트 내부 상수다.
// 색·시간·타입 스케일만 UI-GUIDE 토큰에서 가져온다(2.2, 2.4, 3.1).
const double _ringSize = 56;
const double _ringStroke = GameSpace.xs; // 4

/// 결과 헤더: 점수 카운트업(E-06) + 정답 링 + (있으면) 해제 배지·재제출 안내.
///
/// 해제 배지·재제출 안내는 애니메이션 대상이 아니다 — 첫 프레임부터 최종
/// 상태로 보인다(`submit_test.dart`가 `pump()` 한 번으로 통과해야 한다).
/// 둘은 동시에 나타날 수 없다(`justUnlocked`는 `isFirstSubmit`을 전제한다).
class ScoreHeader extends StatelessWidget {
  final int score, correct, total;
  final bool isFirstSubmit, justUnlocked;
  final int? unlockedLevelId;
  const ScoreHeader({
    super.key,
    required this.score,
    required this.correct,
    required this.total,
    required this.isFirstSubmit,
    required this.justUnlocked,
    this.unlockedLevelId,
  });

  @override
  Widget build(BuildContext context) {
    final c = GameColors.of(context);
    final motion = GameMotion.of(context);
    final ratio = total == 0 ? 0.0 : correct / total; // total == 0 → 링 진행 0

    return Semantics(
      // 카운트업 중간값이 스크린리더에 흘러나가지 않게 헤더 전체를 하나의
      // 라벨로 감싼다 — 안의 Text는 ExcludeSemantics로 가린다.
      container: true,
      label: '점수 $score, $correct / $total 정답',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            GameSpace.l, GameSpace.m, GameSpace.l, GameSpace.m),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: motion.celebrate, // 900ms, 감소 모션이면 0
            curve: motion.curveStandard, // easeOutCubic — 1을 넘지 않는다
            builder: (context, t, _) {
              final shown = (score * t).round();
              return Row(children: [
                ExcludeSemantics(
                  // 매 프레임 바뀌는 숫자를 읽지 않게.
                  child: Text('${shown >= 0 ? '+' : ''}$shown',
                      style: GameType.display.copyWith(color: c.ink)),
                ),
                const SizedBox(width: GameSpace.xl),
                SizedBox.square(
                  dimension: _ringSize,
                  child: CustomPaint(
                      painter: _RingPainter(
                          progress: ratio * t, track: c.line, fill: c.success)),
                ),
                const SizedBox(width: GameSpace.m),
                Text('$correct / $total 정답',
                    style: GameType.label.copyWith(color: c.inkMuted)),
              ]);
            },
          ),
          if (justUnlocked && unlockedLevelId != null)
            _UnlockBadge(levelId: unlockedLevelId!),
          if (!isFirstSubmit) const _ResubmitNote(),
        ]),
      ),
    );
  }
}

/// 해제 배지: `레벨 N이 열렸습니다`.
/// `accent` 배경 + `GameRadius.pill` + 글자 `GameType.label` 색
/// `cellInkOnAccent` — 다크에서 `ink`는 거의 흰색이라 노랑 위 대비가
/// 무너진다. 2.3 대비 계약이 검증하는 쌍이 `cellInkOnAccent / accent`다
/// (라이트에서는 `ink`와 값이 같다).
class _UnlockBadge extends StatelessWidget {
  final int levelId;
  const _UnlockBadge({required this.levelId});

  @override
  Widget build(BuildContext context) {
    final c = GameColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: GameSpace.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: GameSpace.m, vertical: GameSpace.xs),
        decoration: BoxDecoration(
          color: c.accent,
          borderRadius: BorderRadius.circular(GameRadius.pill),
        ),
        child: Text('레벨 $levelId이 열렸습니다',
            style: GameType.label.copyWith(color: c.cellInkOnAccent)),
      ),
    );
  }
}

/// 재제출 안내: `Icons.info_outline` 16 + `GameType.caption` 색 `inkMuted`.
/// INV-09 목록의 문구를 글자 하나도 바꾸지 않는다.
class _ResubmitNote extends StatelessWidget {
  const _ResubmitNote();

  @override
  Widget build(BuildContext context) {
    final c = GameColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: GameSpace.xs),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.info_outline, size: 16, color: c.inkMuted),
        const SizedBox(width: GameSpace.xs),
        Text('재제출이라 기록에 반영되지 않았습니다',
            style: GameType.caption.copyWith(color: c.inkMuted)),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color track, fill;
  const _RingPainter(
      {required this.progress, required this.track, required this.fill});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - _ringStroke) / 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _ringStroke;
    canvas.drawCircle(center, radius, base..color = track);
    if (progress <= 0) return;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2,
        2 * pi * progress, false, base..color = fill..strokeCap = StrokeCap.butt);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.fill != fill;
}
