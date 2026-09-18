// lib/ui/theme/motion.dart
//
// UI-GUIDE.md 3.1·3.2. `Duration(milliseconds: …)` 리터럴은 이 파일에만 있다(INV-12).
import 'package:flutter/material.dart';

@immutable
class GameMotion extends ThemeExtension<GameMotion> {
  final Duration instant, fast, base, slow, celebrate;
  final Curve curveStandard, curveEmphasized, curvePop;

  const GameMotion({
    required this.instant,
    required this.fast,
    required this.base,
    required this.slow,
    required this.celebrate,
    required this.curveStandard,
    required this.curveEmphasized,
    required this.curvePop,
  });

  /// 화면 코드는 **반드시** 이 함수로만 Duration을 얻는다 (UI-GUIDE 3.2, INV-12).
  static GameMotion of(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context)
          ? none
          : Theme.of(context).extension<GameMotion>() ?? standard;

  // UI-GUIDE 3.1 표.
  static const standard = GameMotion(
    instant: Duration(milliseconds: 80),
    fast: Duration(milliseconds: 150),
    base: Duration(milliseconds: 240),
    slow: Duration(milliseconds: 400),
    celebrate: Duration(milliseconds: 900),
    curveStandard: Curves.easeOutCubic,
    curveEmphasized: Curves.easeInOutCubicEmphasized,
    curvePop: Curves.easeOutBack,
  );

  /// 감소 모션용. 시간은 전부 0, 곡선은 `Curves.linear`
  /// (시간이 0이면 곡선은 결과에 영향이 없지만, 곡선만 쓰는 호출부가
  /// null을 받지 않도록 값을 채워 둔다).
  static const none = GameMotion(
    instant: Duration.zero,
    fast: Duration.zero,
    base: Duration.zero,
    slow: Duration.zero,
    celebrate: Duration.zero,
    curveStandard: Curves.linear,
    curveEmphasized: Curves.linear,
    curvePop: Curves.linear,
  );

  @override
  GameMotion copyWith({
    Duration? instant,
    Duration? fast,
    Duration? base,
    Duration? slow,
    Duration? celebrate,
    Curve? curveStandard,
    Curve? curveEmphasized,
    Curve? curvePop,
  }) =>
      GameMotion(
        instant: instant ?? this.instant,
        fast: fast ?? this.fast,
        base: base ?? this.base,
        slow: slow ?? this.slow,
        celebrate: celebrate ?? this.celebrate,
        curveStandard: curveStandard ?? this.curveStandard,
        curveEmphasized: curveEmphasized ?? this.curveEmphasized,
        curvePop: curvePop ?? this.curvePop,
      );

  // 시간·곡선을 섞으면 의미가 없으므로(GameColors와 달리 보간하지 않는다)
  // 중간에서 끊어 통째로 바꾼다.
  @override
  GameMotion lerp(GameMotion? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}
