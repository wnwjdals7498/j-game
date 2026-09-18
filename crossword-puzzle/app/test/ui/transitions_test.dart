// test/ui/transitions_test.dart
//
// E-09 화면 전환 검증 (07-07-01). DB가 필요 없다 — `GameRoute`만 쓰는 2화면
// 미니 앱과 `onGenerateGameRoute` 직접 호출로 검증한다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jgame/main.dart';
import 'package:jgame/ui/theme/app_theme.dart';
import 'package:jgame/ui/theme/fade_through_route.dart';
import 'package:jgame/ui/theme/motion.dart';

/// `GameRoute`만 쓰는 2화면 미니 앱. `/a`가 시작 화면, `/b`가 전환 목적지.
Widget _miniApp() {
  final builders = <String, WidgetBuilder>{
    '/a': (_) => const Text('화면A'),
    '/b': (_) => const Text('화면B'),
  };
  return MaterialApp(
    theme: buildLightTheme(),
    initialRoute: '/a',
    onGenerateRoute: (settings) {
      final builder = builders[settings.name];
      return builder == null
          ? null
          : GameRoute<void>(builder: builder, settings: settings);
    },
  );
}

void main() {
  testWidgets('E-09: 전환 중 두 화면 공존', (tester) async {
    await tester.pumpWidget(_miniApp());
    await tester.pumpAndSettle();
    expect(find.text('화면A'), findsOneWidget);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed('/b');
    await tester.pump(); // 전환 시작
    await tester.pump(GameMotion.standard.base ~/ 2); // base의 절반 지점

    expect(find.text('화면A'), findsOneWidget);
    expect(find.text('화면B'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('화면A'), findsNothing);
    expect(find.text('화면B'), findsOneWidget);
  });

  test('E-09 지속 시간: transitionDuration == GameMotion.standard.base', () {
    final route = GameRoute<void>(builder: (_) => const SizedBox());
    expect(route.transitionDuration, GameMotion.standard.base);
  });

  testWidgets('감소 모션: 한 프레임에 완료', (tester) async {
    tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(
        tester.binding.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await tester.pumpWidget(_miniApp());
    await tester.pumpAndSettle();

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed('/b');
    await tester.pump(); // 감소 모션이면 이 한 프레임으로 전환이 끝나야 한다

    expect(find.text('화면A'), findsNothing);
    expect(find.text('화면B'), findsOneWidget);
  });

  group('onGenerateGameRoute', () {
    test('등록된 4개 이름은 GameRoute<void>를 돌려준다', () {
      for (final name in ['/', '/play', '/result', '/settings']) {
        final route = onGenerateGameRoute(RouteSettings(name: name));
        expect(route, isA<GameRoute<void>>(), reason: name);
      }
    });

    test('등록되지 않은 이름은 null', () {
      expect(onGenerateGameRoute(const RouteSettings(name: '/nope')), isNull);
    });
  });

  group('pageTransitionsTheme', () {
    const platforms = [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
      TargetPlatform.fuchsia,
    ];

    void checkBuilders(ThemeData theme) {
      final builders = theme.pageTransitionsTheme.builders;
      expect(builders.keys, containsAll(platforms));
      for (final p in platforms) {
        expect(builders[p], isA<FadeThroughPageTransitionsBuilder>(),
            reason: '$p');
      }
    }

    test('라이트 테마: 6개 플랫폼 전부 등록', () => checkBuilders(buildLightTheme()));
    test('다크 테마: 6개 플랫폼 전부 등록', () => checkBuilders(buildDarkTheme()));
  });
}
