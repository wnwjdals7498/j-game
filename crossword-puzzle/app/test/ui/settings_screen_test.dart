// 07-07-03 설정 화면 재구성 테스트: 테마 모드 3택 · 효과음 토글 · 구획
// 헤더 4개 · 라이선스 진입. 기존 8종(힌트 모드, DB 정보, Wi-Fi 토글 등)은
// 그대로 home_settings_test.dart에 있다 — 이 파일은 07-07-03이 새로 더한
// 항목만 검증한다.
//
// S-01(효과음이 켜진 경우만 클릭음) 동작 테스트는 07-07-04가 이 파일에
// 그룹 하나를 덧붙인다.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:jgame/data/db/app_database.dart';
import 'package:jgame/data/hint_repository.dart';
import 'package:jgame/data/stat_repository.dart';
import 'package:jgame/domain/fixtures/dummy_dictionary.dart';
import 'package:jgame/domain/generator/grid_generator.dart';
import 'package:jgame/domain/levels.dart';
import 'package:jgame/domain/model/puzzle.dart';
import 'package:jgame/ui/common/section_header.dart';
import 'package:jgame/ui/puzzle/grid_view.dart';
import 'package:jgame/ui/puzzle/puzzle_page.dart';
import 'package:jgame/ui/settings/license_page.dart';
import 'package:jgame/ui/settings/settings_page.dart';
import 'package:jgame/ui/state/app_scope.dart';
import 'package:jgame/ui/state/puzzle_model.dart';
import 'package:jgame/ui/state/settings_model.dart';
import 'package:jgame/ui/theme/app_theme.dart';

void main() {
  late Directory tmp;
  late String schemaSql;
  var dbSeq = 0;

  setUpAll(() {
    schemaSql = File('../tools/schema.sql').readAsStringSync();
    // `_AppVersionSection`(06-01)이 쓰는 `PackageInfo.fromPlatform()`은
    // 테스트 환경엔 플랫폼 채널 구현이 없다 — home_settings_test.dart와
    // 같은 목값.
    PackageInfo.setMockInitialValues(
      appName: 'jgame',
      packageName: 'io.github.wnwjdals7498.jgame',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('settings_screen_test_');
    dbSeq = 0;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  AppDatabase openEmptyDb() {
    final path = '${tmp.path}/t${dbSeq++}.sqlite';
    final raw = sqlite3.open(path);
    raw.execute(schemaSql);
    raw.close();
    return AppDatabase(NativeDatabase(File(path)));
  }

  /// home_settings_test.dart의 `useTallViewport`와 같은 이유: 구획이 4개로
  /// 늘어 기본 테스트 뷰포트(약 800×600)로는 `ListView`가 아래쪽 항목('정보'
  /// 구획, '출처 및 라이선스' 등)을 화면 밖이라 아예 빌드하지 않는다(레이지
  /// 리스트 — 완전히 잘림).
  Future<void> useTallViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// home_settings_test.dart의 `buildScope`와 같은 패턴: 더미 사전으로
  /// 성공하는 [AppScope]. `syncService`를 생략하면 `null`(웹 경로).
  AppScope buildScope(AppDatabase db) {
    final words = InMemoryWordRepository(buildDummyDictionary(seed: 1));
    return AppScope(
      db: db,
      words: words,
      stats: StatRepository(db),
      generator: GridGenerator(words),
      hints: HintRepository(db),
    );
  }

  /// `main.dart`의 `JGameApp` 조립과 같은 구조: `Consumer<SettingsModel>`
  /// 아래 `MaterialApp`을 둬야 `themeMode` 변경이 갱신된다(07-02-03,
  /// 07-07-03 "막히면").
  Widget wrapApp(AppScope scope, SettingsModel settings) => MultiProvider(
        providers: [
          Provider<AppScope>.value(value: scope),
          ChangeNotifierProvider<SettingsModel>.value(value: settings),
        ],
        child: Consumer<SettingsModel>(
          builder: (_, settings, _) => MaterialApp(
            theme: buildLightTheme(),
            darkTheme: buildDarkTheme(),
            themeMode: settings.themeMode,
            home: const SettingsPage(),
          ),
        ),
      );

  group('테마 모드', () {
    testWidgets('기본값: prefs 비었을 때 system, SegmentedButton.selected == {system}',
        (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);
      final settings = SettingsModel();
      await settings.load();

      await tester.pumpWidget(wrapApp(buildScope(db), settings));
      await tester.pumpAndSettle();

      expect(settings.themeMode, ThemeMode.system);
      final segmented = tester
          .widget<SegmentedButton<ThemeMode>>(find.byType(SegmentedButton<ThemeMode>));
      expect(segmented.selected, {ThemeMode.system});
    });

    testWidgets("'다크' 탭: themeMode 변경 + MaterialApp 반영 + 재시작 후 유지",
        (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);
      final settings = SettingsModel();
      await settings.load();

      await tester.pumpWidget(wrapApp(buildScope(db), settings));
      await tester.pumpAndSettle();

      await tester.tap(find.text('다크'));
      await tester.pumpAndSettle();

      expect(settings.themeMode, ThemeMode.dark);
      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.dark);

      // "재시작"은 새 SettingsModel 인스턴스로 흉내 낸다 (home_settings_test.dart와
      // 같은 방식) — shared_preferences mock 저장소는 테스트 프로세스 동안
      // 공유된다.
      final restarted = SettingsModel();
      await restarted.load();
      expect(restarted.themeMode, ThemeMode.dark);
    });
  });

  group('효과음', () {
    testWidgets("토글: 기본 꺼짐 → '효과음' 탭 → true, 재시작 후 유지",
        (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);
      final settings = SettingsModel();
      await settings.load();

      await tester.pumpWidget(wrapApp(buildScope(db), settings));
      await tester.pumpAndSettle();
      expect(settings.soundEnabled, isFalse);

      await tester.tap(find.text('효과음'));
      await tester.pumpAndSettle();
      expect(settings.soundEnabled, isTrue);

      final restarted = SettingsModel();
      await restarted.load();
      expect(restarted.soundEnabled, isTrue);
    });

    testWidgets('안내 문구: 기기의 터치음 설정을 따릅니다', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(wrapApp(buildScope(db), SettingsModel()));
      await tester.pumpAndSettle();

      expect(find.text('기기의 터치음 설정을 따릅니다'), findsOneWidget);
    });
  });

  testWidgets('구획 헤더 4개: 화면·힌트·단어 데이터·정보', (tester) async {
    await useTallViewport(tester);
    final db = openEmptyDb();
    addTearDown(db.close);

    await tester.pumpWidget(wrapApp(buildScope(db), SettingsModel()));
    await tester.pumpAndSettle();

    // '단어 데이터'는 DB 조회 실패 분기의 ListTile 제목과도 겹칠 수 있어
    // SectionHeader 안에서만 찾는다(07-07-03 "막히면").
    expect(find.widgetWithText(SectionHeader, '화면'), findsOneWidget);
    expect(find.widgetWithText(SectionHeader, '힌트'), findsOneWidget);
    expect(find.widgetWithText(SectionHeader, '단어 데이터'), findsOneWidget);
    expect(find.widgetWithText(SectionHeader, '정보'), findsOneWidget);
  });

  testWidgets('라이선스 진입: LicenseNoticePage 1개 + SelectableText 1개 (INV-06b)',
      (tester) async {
    await useTallViewport(tester);
    final db = openEmptyDb();
    addTearDown(db.close);

    await tester.pumpWidget(wrapApp(buildScope(db), SettingsModel()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('출처 및 라이선스'));
    await tester.pumpAndSettle();

    expect(find.byType(LicenseNoticePage), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
  });

  group('S-01: 셀 탭 효과음', () {
    // play_loop_test.dart의 wrapApp과 같은 모양. 위쪽 wrapApp은 SettingsPage
    // 전용이라 PuzzlePage를 띄우는 데는 쓸 수 없어 따로 둔다.
    Widget wrapPlay(AppScope scope, SettingsModel settings, Widget child) =>
        MultiProvider(
          providers: [
            Provider<AppScope>.value(value: scope),
            ChangeNotifierProvider<SettingsModel>.value(value: settings),
          ],
          child: MaterialApp(theme: buildLightTheme(), home: child),
        );

    // play_loop_test.dart의 cellCenter와 같은 방식 — 고정 좌표 대신 실제
    // 렌더 크기로 계산한다(04-07 "막히면").
    Offset cellCenter(WidgetTester tester, Puzzle puzzle, int row, int col) {
      final topLeft = tester.getTopLeft(find.byType(PuzzleGridView));
      final size = tester.getSize(find.byType(PuzzleGridView));
      final cell = size.width / puzzle.width;
      return topLeft + Offset(cell * (col + 0.5), cell * (row + 0.5));
    }

    testWidgets('켜짐: 셀 탭 → 소리 1회', (tester) async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemSound.play') {
          calls.add(call.arguments as String);
        }
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      // 튜토리얼 바텀시트(첫 진입 안내)가 셀 탭을 가로채지 않도록 이미 본 것으로
      // 표시해 둔다 — puzzle_screen_test.dart(07-04-05)와 같은 이유.
      SharedPreferences.setMockInitialValues({tutorialSeenPrefsKey: true});
      final db = openEmptyDb();
      addTearDown(db.close);
      final settings = SettingsModel();
      await settings.load();
      await settings.setSoundEnabled(true);

      await tester.pumpWidget(wrapPlay(buildScope(db), settings,
          PuzzlePage(spec: levels.first, seed: 1000)));
      await tester.pumpAndSettle();

      final model = Provider.of<PuzzleModel>(
          tester.element(find.byType(PuzzleGridView)),
          listen: false);
      final puzzle = model.puzzle!;
      final (r, c) = puzzle.words.first.cells.first;
      await tester.tapAt(cellCenter(tester, puzzle, r, c));
      await tester.pumpAndSettle();

      expect(calls, ['SystemSoundType.click']);
    });

    testWidgets('꺼짐(기본값): 셀 탭 → 소리 0회', (tester) async {
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'SystemSound.play') {
          calls.add(call.arguments as String);
        }
        return null;
      });
      addTearDown(() => TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      SharedPreferences.setMockInitialValues({tutorialSeenPrefsKey: true});
      final db = openEmptyDb();
      addTearDown(db.close);
      final settings = SettingsModel();
      await settings.load();

      await tester.pumpWidget(wrapPlay(buildScope(db), settings,
          PuzzlePage(spec: levels.first, seed: 1000)));
      await tester.pumpAndSettle();

      final model = Provider.of<PuzzleModel>(
          tester.element(find.byType(PuzzleGridView)),
          listen: false);
      final puzzle = model.puzzle!;
      final (r, c) = puzzle.words.first.cells.first;
      await tester.tapAt(cellCenter(tester, puzzle, r, c));
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
    });

    test('기본값: 새 SettingsModel().load()의 soundEnabled == false', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = SettingsModel();
      await settings.load();
      expect(settings.soundEnabled, isFalse);
    });
  });
}
