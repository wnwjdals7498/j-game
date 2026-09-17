// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jgame/domain/fixtures/dummy_dictionary.dart';
import 'package:jgame/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // MyApp이 이제 실 DB WordRepository를 받는다 (03-05, main.dart 임시 진입점).
    // 위젯 테스트는 파일시스템/DB 없이 도는 InMemoryWordRepository로 대신한다.
    final repo = InMemoryWordRepository(buildDummyDictionary(seed: 1));

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(repo: repo));

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });
}
