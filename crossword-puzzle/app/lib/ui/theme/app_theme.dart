// lib/ui/theme/app_theme.dart
//
// `GameColors`·`GameMotion`(07-02-01·07-02-02)을 실제 `ThemeData`로 조립한다
// (07-02-03). `ColorScheme` 매핑은 UI-GUIDE 2.2 마지막 줄 + 07-02-03 표,
// `TextTheme` 매핑은 UI-GUIDE 2.4 마지막 줄, 컴포넌트 테마는 UI-GUIDE 2.5·4절.
//
// `pageTransitionsTheme`(E-09)는 여기서 넣지 않는다 — 07-07 몫이다.
import 'package:flutter/material.dart';

import 'motion.dart';
import 'tokens.dart';

ThemeData buildLightTheme() => _build(GameColors.light, Brightness.light);
ThemeData buildDarkTheme() => _build(GameColors.dark, Brightness.dark);

ThemeData _build(GameColors c, Brightness brightness) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.ink,
    onPrimary: c.surface,
    secondary: c.accentSoft,
    onSecondary: c.cellInk,
    secondaryContainer: c.accentSoft,
    onSecondaryContainer: c.cellInk,
    tertiary: c.accent,
    onTertiary: c.cellInkOnAccent,
    error: c.danger,
    onError: c.surface,
    surface: c.surface,
    onSurface: c.ink,
    onSurfaceVariant: c.inkMuted,
    outline: c.line,
    outlineVariant: c.line,
    // grid_painter.dart가 선택 하이라이트로 읽는다. 비워 두면 M3 기본 보라가
    // 격자에 뜬다 (07-02-03 "막히면").
    primaryContainer: c.accentSoft,
    onPrimaryContainer: c.cellInk,
    surfaceContainerHighest: c.surfaceAlt,
    surfaceContainerHigh: c.surfaceAlt,
  );

  final textTheme = const TextTheme(
    displaySmall: GameType.display,
    titleLarge: GameType.title,
    titleMedium: GameType.heading,
    bodyLarge: GameType.body,
    bodyMedium: GameType.body,
    labelLarge: GameType.label,
    bodySmall: GameType.caption,
  ).apply(bodyColor: c.ink, displayColor: c.ink);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: GameType.family,
    scaffoldBackgroundColor: c.surface,
    textTheme: textTheme,
    extensions: <ThemeExtension<dynamic>>[c, GameMotion.standard],
    appBarTheme: AppBarTheme(
      backgroundColor: c.surface,
      foregroundColor: c.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: GameType.title.copyWith(color: c.ink),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.ink,
        foregroundColor: c.surface,
        disabledBackgroundColor: c.surfaceAlt,
        disabledForegroundColor: c.inkMuted,
        textStyle: GameType.body.copyWith(fontWeight: FontWeight.w700),
        minimumSize: Size.fromHeight(GameRadius.buttonHeight),
        shape: const StadiumBorder(),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: c.ink,
        textStyle: GameType.body.copyWith(fontWeight: FontWeight.w600),
        side: BorderSide(color: c.line, width: GameRadius.outlineButton),
        minimumSize: Size.fromHeight(GameRadius.buttonHeight),
        shape: const StadiumBorder(),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.line, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.ink,
      contentTextStyle: GameType.body.copyWith(color: c.surface),
      shape: const StadiumBorder(),
      behavior: SnackBarBehavior.floating,
      elevation: 0,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(GameRadius.panel)),
      ),
      elevation: 0,
      showDragHandle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: InputBorder.none,
      filled: false,
      hintStyle: GameType.body.copyWith(color: c.inkMuted),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.ink,
      linearMinHeight: 2,
    ),
  );
}
