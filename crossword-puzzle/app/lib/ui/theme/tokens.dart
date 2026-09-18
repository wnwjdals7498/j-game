// lib/ui/theme/tokens.dart
//
// UI-GUIDE.md 2.2·2.4·2.5의 값을 코드로 옮긴 유일한 자리.
// `Color(0x…)` 리터럴은 이 디렉터리 밖에 있으면 INV-05 위반이다.
import 'package:flutter/material.dart';

@immutable
class GameColors extends ThemeExtension<GameColors> {
  final Color surface, surfaceAlt, ink, inkMuted, line, accent, accentSoft,
      success, danger, gridLine, cellFill, cellBlocked, cellCoreMark,
      cellInk, cellInkOnAccent;

  const GameColors({
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkMuted,
    required this.line,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.danger,
    required this.gridLine,
    required this.cellFill,
    required this.cellBlocked,
    required this.cellCoreMark,
    required this.cellInk,
    required this.cellInkOnAccent,
  });

  static GameColors of(BuildContext context) =>
      Theme.of(context).extension<GameColors>()!;

  // UI-GUIDE 2.2 표 라이트 열.
  static const light = GameColors(
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF5F5F3),
    ink: Color(0xFF121212),
    inkMuted: Color(0xFF6E6E6E),
    line: Color(0xFFDEDEDE),
    accent: Color(0xFFFFDA00),
    accentSoft: Color(0xFFA7D8FF),
    success: Color(0xFF1B7F3B),
    danger: Color(0xFFC62828),
    gridLine: Color(0xFF121212),
    cellFill: Color(0xFFFFFFFF),
    cellBlocked: Color(0xFF121212),
    cellCoreMark: Color(0xFF8A8A8A),
    cellInk: Color(0xFF121212),
    cellInkOnAccent: Color(0xFF121212),
  );

  // UI-GUIDE 2.2 표 다크 열.
  static const dark = GameColors(
    surface: Color(0xFF121212),
    surfaceAlt: Color(0xFF1C1C1C),
    ink: Color(0xFFF2F2F2),
    inkMuted: Color(0xFFA3A3A3),
    line: Color(0xFF2E2E2E),
    accent: Color(0xFFE5C400),
    accentSoft: Color(0xFF2B5C8A),
    success: Color(0xFF58B368),
    danger: Color(0xFFEF5350),
    gridLine: Color(0xFF4A4A4A),
    cellFill: Color(0xFF1E1E1E),
    cellBlocked: Color(0xFF050505),
    cellCoreMark: Color(0xFF8A8A8A),
    cellInk: Color(0xFFF2F2F2),
    cellInkOnAccent: Color(0xFF121212),
  );

  @override
  GameColors copyWith({
    Color? surface,
    Color? surfaceAlt,
    Color? ink,
    Color? inkMuted,
    Color? line,
    Color? accent,
    Color? accentSoft,
    Color? success,
    Color? danger,
    Color? gridLine,
    Color? cellFill,
    Color? cellBlocked,
    Color? cellCoreMark,
    Color? cellInk,
    Color? cellInkOnAccent,
  }) =>
      GameColors(
        surface: surface ?? this.surface,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        ink: ink ?? this.ink,
        inkMuted: inkMuted ?? this.inkMuted,
        line: line ?? this.line,
        accent: accent ?? this.accent,
        accentSoft: accentSoft ?? this.accentSoft,
        success: success ?? this.success,
        danger: danger ?? this.danger,
        gridLine: gridLine ?? this.gridLine,
        cellFill: cellFill ?? this.cellFill,
        cellBlocked: cellBlocked ?? this.cellBlocked,
        cellCoreMark: cellCoreMark ?? this.cellCoreMark,
        cellInk: cellInk ?? this.cellInk,
        cellInkOnAccent: cellInkOnAccent ?? this.cellInkOnAccent,
      );

  @override
  GameColors lerp(GameColors? other, double t) => other == null
      ? this
      : GameColors(
          surface: Color.lerp(surface, other.surface, t)!,
          surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
          ink: Color.lerp(ink, other.ink, t)!,
          inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
          line: Color.lerp(line, other.line, t)!,
          accent: Color.lerp(accent, other.accent, t)!,
          accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
          success: Color.lerp(success, other.success, t)!,
          danger: Color.lerp(danger, other.danger, t)!,
          gridLine: Color.lerp(gridLine, other.gridLine, t)!,
          cellFill: Color.lerp(cellFill, other.cellFill, t)!,
          cellBlocked: Color.lerp(cellBlocked, other.cellBlocked, t)!,
          cellCoreMark: Color.lerp(cellCoreMark, other.cellCoreMark, t)!,
          cellInk: Color.lerp(cellInk, other.cellInk, t)!,
          cellInkOnAccent:
              Color.lerp(cellInkOnAccent, other.cellInkOnAccent, t)!,
        );
}

/// 화면 좌우 여백은 `GameSpace.l`(16). UI-GUIDE 2.5.
abstract final class GameSpace {
  static const xs = 4.0, s = 8.0, m = 12.0, l = 16.0, xl = 24.0, xxl = 32.0;
}

abstract final class GameRadius {
  static const cell = 0.0, panel = 12.0, pill = 999.0;
  static const hairline = 1.0;        // 구분선·셀 테두리 두께
  static const gridOuter = 2.0;       // 격자 외곽 두께
  static const outlineButton = 1.5;   // 보조 버튼 테두리
  static const buttonHeight = 52.0;   // UI-GUIDE 2.5 버튼 규격
}

abstract final class GameType {
  static const family = 'Pretendard';   // 07-02-04에서 실제 파일을 번들한다

  static const display = TextStyle(fontFamily: family, fontSize: 34, fontWeight: FontWeight.w700, height: 1.1);
  static const title   = TextStyle(fontFamily: family, fontSize: 22, fontWeight: FontWeight.w700, height: 1.2);
  static const heading = TextStyle(fontFamily: family, fontSize: 17, fontWeight: FontWeight.w600, height: 1.3);
  static const body    = TextStyle(fontFamily: family, fontSize: 16, fontWeight: FontWeight.w400, height: 1.5);
  static const label   = TextStyle(fontFamily: family, fontSize: 13, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: 0.4);
  static const caption = TextStyle(fontFamily: family, fontSize: 12, fontWeight: FontWeight.w400, height: 1.3);

  static TextStyle cellSyllable(double cell) =>
      TextStyle(fontFamily: family, fontSize: cell * 0.55, fontWeight: FontWeight.w600, height: 1.0);
  static TextStyle cellNumber(double cell) =>
      TextStyle(fontFamily: family, fontSize: cell * 0.22, fontWeight: FontWeight.w600, height: 1.0);
}
