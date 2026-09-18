// 제출 버튼 (07-04-03.progress-and-submit-button.md). E-05 — `allFilled`
// 여부에 따라 보조(투명 배경) ↔ 기본(ink 배경) 스타일로 색만 전환한다.
// 빈칸이 있어도 눌린다 — 04-05의 기존 규칙, 이 위젯은 색만 바꾼다.
import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

class SubmitButton extends StatelessWidget {
  final bool active; // model.allFilled
  final VoidCallback onPressed; // active와 무관하게 항상 non-null

  const SubmitButton({super.key, required this.active, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final c = GameColors.of(context);
    final m = GameMotion.of(context);
    final radius = BorderRadius.circular(GameRadius.pill);
    return SizedBox(
      width: double.infinity,
      height: 52, // UI-GUIDE 2.5 버튼 높이
      child: AnimatedContainer(
        duration: m.base, curve: m.curveStandard, // E-05
        decoration: BoxDecoration(
          color: active ? c.ink : Colors.transparent,
          border: Border.all(color: active ? c.ink : c.line, width: 1.5),
          borderRadius: radius,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed, // INV-09, 빈칸이 있어도 눌린다(04-05 규칙)
            borderRadius: radius,
            child: Center(
              child: AnimatedDefaultTextStyle(
                duration: m.base,
                style: GameType.body.copyWith(
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  color: active ? c.surface : c.ink,
                ),
                child: const Text('제출'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
