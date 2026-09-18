// 07-08-01 골든 하네스: 고정 크기·고정 데이터·고정 테마를 한 곳에 모은다.
// 장면(`*_golden_test.dart`)은 이 문서에서 만들지 않는다 — 07-08-02가 한
// 번에 추가한다.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:jgame/data/db/app_database.dart';
import 'package:jgame/data/hint_repository.dart';
import 'package:jgame/data/stat_repository.dart';
import 'package:jgame/domain/fixtures/dummy_dictionary.dart';
import 'package:jgame/domain/generator/grid_generator.dart';
import 'package:jgame/ui/state/app_scope.dart';
import 'package:jgame/ui/state/settings_model.dart';
import 'package:jgame/ui/theme/app_theme.dart';

/// 07-08 A절 "크기 고정". 폰 세로 한 종만 쓴다.
const goldenSize = Size(390, 844);

/// `../tools/schema.sql`로 임시 빈 DB를 연다 — `play_loop_test.dart`와 같은
/// 방식이고, cwd가 `app/`일 때 맞는 경로다.
AppDatabase openGoldenDb(Directory tmp, {int seq = 0}) {
  final schemaSql = File('../tools/schema.sql').readAsStringSync();
  final path = '${tmp.path}/golden$seq.sqlite';
  final raw = sqlite3.open(path);
  raw.execute(schemaSql);
  raw.close();
  return AppDatabase(NativeDatabase(File(path)));
}

/// 더미 사전 seed 1로 만든 가짜 의존성. `syncService`는 null(골든 3장과 무관).
AppScope goldenScope(AppDatabase db) {
  final words = InMemoryWordRepository(buildDummyDictionary(seed: 1));
  return AppScope(
    db: db,
    words: words,
    stats: StatRepository(db),
    generator: GridGenerator(words),
    hints: HintRepository(db),
  );
}

Future<void> pumpGolden(
  WidgetTester tester,
  Widget child, {
  required AppScope scope,
  required ThemeMode themeMode,
  SettingsModel? settings,
}) async {
  tester.view.physicalSize = goldenSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<AppScope>.value(value: scope),
      ChangeNotifierProvider<SettingsModel>.value(
          value: settings ?? SettingsModel()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: themeMode,
      // MaterialApp 바깥의 MediaQuery는 WidgetsApp의 MediaQuery.fromView가
      // 덮어쓴다. 반드시 builder 안에서 감싼다.
      builder: (context, inner) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            disableAnimations: true, textScaler: TextScaler.noScaling),
        child: inner!,
      ),
      home: child,
    ),
  ));
  await tester.pumpAndSettle();
}
