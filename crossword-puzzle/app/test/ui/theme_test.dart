// 07-02 테마 계약 테스트 (INV-13 · INV-14).
//
// 07-02가 만든 토큰 층 전체(색·모션·타이포·테마 모드 저장·MaterialApp 연결)를
// 이 파일 하나가 감시한다. 대비 계산은 WCAG 상대 휘도 공식을 테스트 파일
// 안에 직접 둔다(07-02-05 "대비 계산 함수").
//
// 9번 테스트는 shell_test.dart(04-01)의 `_openEmptyDb` 패턴을 이 파일에
// 복사한 것이다 — 공유 헬퍼 파일이 없는 것이 이 저장소 관례다.
import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:jgame/data/db/app_database.dart';
import 'package:jgame/data/hint_repository.dart';
import 'package:jgame/data/stat_repository.dart';
import 'package:jgame/domain/fixtures/dummy_dictionary.dart';
import 'package:jgame/domain/generator/grid_generator.dart';
import 'package:jgame/main.dart';
import 'package:jgame/ui/state/app_scope.dart';
import 'package:jgame/ui/state/settings_model.dart';
import 'package:jgame/ui/theme/app_theme.dart';
import 'package:jgame/ui/theme/motion.dart';
import 'package:jgame/ui/theme/tokens.dart';

double _lum(Color c) {
  double ch(double s) =>
      s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05);
}

/// (쌍 이름, 전경, 배경, 최소 비율). UI-GUIDE 2.3 표 그대로.
typedef _ContrastCase = (String name, Color fg, Color bg, double min);

List<_ContrastCase> _pairs(GameColors c) => [
      ('ink/surface', c.ink, c.surface, 7.0),
      ('inkMuted/surface', c.inkMuted, c.surface, 4.5),
      ('inkMuted/surfaceAlt', c.inkMuted, c.surfaceAlt, 4.5),
      ('cellInk/cellFill', c.cellInk, c.cellFill, 7.0),
      ('cellInk/accentSoft', c.cellInk, c.accentSoft, 4.5),
      ('cellInkOnAccent/accent', c.cellInkOnAccent, c.accent, 4.5),
      ('surface/ink', c.surface, c.ink, 7.0),
      ('inkMuted/cellFill', c.inkMuted, c.cellFill, 3.0),
    ];

/// shell_test.dart(04-01)의 `_openEmptyDb`와 같은 패턴: `tools/schema.sql`로
/// 빈 DB를 만든다.
AppDatabase _openEmptyDb(String path, String schemaSql) {
  final raw = sqlite3.open(path);
  raw.execute(schemaSql);
  raw.close();
  return AppDatabase(NativeDatabase(File(path)));
}

void main() {
  test('1. 라이트 테마에 GameColors·GameMotion 확장 (INV-13)', () {
    final theme = buildLightTheme();
    expect(theme.extension<GameColors>(), same(GameColors.light));
    expect(theme.extension<GameMotion>(), same(GameMotion.standard));
  });

  test('2. 다크 테마에 GameColors·GameMotion 확장 (INV-13)', () {
    final theme = buildDarkTheme();
    expect(theme.extension<GameColors>(), same(GameColors.dark));
    expect(theme.extension<GameMotion>(), same(GameMotion.standard));
  });

  test('3. 대비 계약 8쌍 × 2테마 (INV-14)', () {
    for (final entry in [('light', GameColors.light), ('dark', GameColors.dark)]) {
      final (themeName, colors) = entry;
      for (final pair in _pairs(colors)) {
        final (name, fg, bg, min) = pair;
        final ratio = contrast(fg, bg);
        expect(
          ratio >= min,
          isTrue,
          reason: '$themeName $name = ${ratio.toStringAsFixed(2)} (기준 $min)',
        );
      }
    }
  });

  test('4. ColorScheme 매핑', () {
    for (final theme in [buildLightTheme(), buildDarkTheme()]) {
      final c = theme.extension<GameColors>()!;
      final scheme = theme.colorScheme;
      expect(scheme.primary, c.ink);
      expect(scheme.onPrimary, c.surface);
      expect(scheme.error, c.danger);
      expect(scheme.tertiary, c.accent);
      expect(scheme.primaryContainer, c.accentSoft);
    }
  });

  test('5. 폰트 패밀리', () {
    expect(buildLightTheme().textTheme.bodyLarge!.fontFamily, 'Pretendard');
  });

  testWidgets('6. 감소 모션: disableAnimations true → fast == Duration.zero',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildLightTheme(),
      home: const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: _MotionCapture(),
      ),
    ));
    expect(_capturedFast, Duration.zero);
  });

  testWidgets('7. 정상 모션: disableAnimations false → fast == 150ms',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildLightTheme(),
      home: const MediaQuery(
        data: MediaQueryData(disableAnimations: false),
        child: _MotionCapture(),
      ),
    ));
    expect(_capturedFast, const Duration(milliseconds: 150));
  });

  test('8. themeMode 저장', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsModel();
    await settings.load();
    expect(settings.themeMode, ThemeMode.system);

    await settings.setThemeMode(ThemeMode.dark);

    final restarted = SettingsModel();
    await restarted.load();
    expect(restarted.themeMode, ThemeMode.dark);
  });

  group('9. MaterialApp 연결', () {
    late Directory tmp;
    late String schemaSql;

    setUpAll(() {
      schemaSql = File('../tools/schema.sql').readAsStringSync();
    });

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('theme_test_');
    });

    tearDown(() {
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    testWidgets('JGameApp의 MaterialApp.themeMode가 SettingsModel 값과 같다',
        (tester) async {
      SharedPreferences.setMockInitialValues({'themeMode': 'dark'});
      final db = _openEmptyDb('${tmp.path}/t.sqlite', schemaSql);
      addTearDown(db.close);
      final words = InMemoryWordRepository(buildDummyDictionary(seed: 1));
      final scope = AppScope(
        db: db,
        words: words,
        stats: StatRepository(db),
        generator: GridGenerator(words),
        hints: HintRepository(db),
      );

      await tester.pumpWidget(JGameApp(bootstrap: Future.value(scope)));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MaterialApp));
      final settings = Provider.of<SettingsModel>(context, listen: false);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));

      expect(app.themeMode, settings.themeMode);
      expect(app.themeMode, ThemeMode.dark);
    });
  });
}

/// 6·7번용: `GameMotion.of(context)`는 `BuildContext`가 필요하므로 `Builder`
/// 안에서 값을 캡처해 바깥 변수에 담는다.
Duration? _capturedFast;

class _MotionCapture extends StatelessWidget {
  const _MotionCapture();

  @override
  Widget build(BuildContext context) {
    _capturedFast = GameMotion.of(context).fast;
    return const SizedBox.shrink();
  }
}
