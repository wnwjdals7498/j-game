// 최초 진입 조작법 안내 튜토리얼 테스트.
//
// puzzle_page.dart의 `_maybeShowTutorial`이 `tutorialSeenPrefsKey`
// (shared_preferences)를 보고, 처음 한 번만 다이얼로그를 띄우는지 확인한다.
// `SharedPreferences.setMockInitialValues`로 매 테스트마다 값을 명시해
// (04-06/05-04 테스트들과 달리) 실제 파일 상태에 기대지 않는다.
import 'dart:io';

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
import 'package:jgame/domain/levels.dart';
import 'package:jgame/ui/puzzle/puzzle_page.dart';
import 'package:jgame/ui/state/app_scope.dart';
import 'package:jgame/ui/state/settings_model.dart';

void main() {
  late Directory tmp;
  late String schemaSql;

  setUpAll(() {
    schemaSql = File('../tools/schema.sql').readAsStringSync();
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('tutorial_test_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  AppScope buildScope() {
    final path = '${tmp.path}/t.sqlite';
    final raw = sqlite3.open(path);
    raw.execute(schemaSql);
    raw.close();
    final db = AppDatabase(NativeDatabase(File(path)));
    addTearDown(db.close);
    final words = InMemoryWordRepository(buildDummyDictionary(seed: 1));
    return AppScope(
      db: db,
      words: words,
      stats: StatRepository(db),
      generator: GridGenerator(words),
      hints: HintRepository(db),
    );
  }

  Widget wrapApp(AppScope scope, Widget child) => MultiProvider(
        providers: [
          Provider<AppScope>.value(value: scope),
          ChangeNotifierProvider(create: (_) => SettingsModel()),
        ],
        child: MaterialApp(home: child),
      );

  testWidgets('처음 퍼즐에 들어가면 조작법 안내가 한 번 뜬다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final scope = buildScope();

    await tester
        .pumpWidget(wrapApp(scope, PuzzlePage(spec: levels.first, seed: 1000)));
    await tester.pumpAndSettle();

    expect(find.text('이렇게 플레이해요'), findsOneWidget);
    expect(find.textContaining('방향이 바뀝니다'), findsOneWidget);

    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();

    expect(find.text('이렇게 플레이해요'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(tutorialSeenPrefsKey), isTrue);
  });

  testWidgets('이미 본 적 있으면 다시 안 뜬다', (tester) async {
    SharedPreferences.setMockInitialValues({tutorialSeenPrefsKey: true});
    final scope = buildScope();

    await tester
        .pumpWidget(wrapApp(scope, PuzzlePage(spec: levels.first, seed: 1000)));
    await tester.pumpAndSettle();

    expect(find.text('이렇게 플레이해요'), findsNothing);
  });
}
