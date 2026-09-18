// 07-05-02: 이어하기 히어로 · 통계 한 줄 테스트.
//
// `home_settings_test.dart`의 `openEmptyDb()`·`buildScope()`·`wrapHome()`·
// `useTallViewport()` 패턴을 그대로 베낀다 — 빈 실 DB에 필요한 값만 손으로
// 심어(customStatement) `HomeModel`이 만드는 상태를 확인한다.
//
// 07-05-03이 레벨 카드 3상태·E-10 테스트 4종을 더 얹어 이 파일이 8종이 된다.
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
import 'package:jgame/ui/home/home_page.dart';
import 'package:jgame/ui/home/hero_card.dart';
import 'package:jgame/ui/home/level_card.dart';
import 'package:jgame/ui/puzzle/puzzle_page.dart';
import 'package:jgame/ui/state/app_scope.dart';
import 'package:jgame/ui/state/home_model.dart';
import 'package:jgame/ui/state/settings_model.dart';
import 'package:jgame/ui/theme/app_theme.dart';
import 'package:jgame/ui/theme/tokens.dart';

void main() {
  late Directory tmp;
  late String schemaSql;
  var dbSeq = 0;

  setUpAll(() {
    schemaSql = File('../tools/schema.sql').readAsStringSync();
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('home_screen_test_');
    dbSeq = 0;
    // 안 넣으면 퍼즐 진입 시 튜토리얼 시트('이렇게 플레이해요')가 떠서
    // '시작' 탭 뒤 pumpAndSettle이 막힌다(puzzle_page.dart `_maybeShowTutorial`).
    SharedPreferences.setMockInitialValues({tutorialSeenPrefsKey: true});
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

  Widget wrapHome(AppScope scope) => MultiProvider(
        providers: [
          Provider<AppScope>.value(value: scope),
          ChangeNotifierProvider(create: (_) => SettingsModel()),
        ],
        child: MaterialApp(
          theme: buildLightTheme(), // HomePage → PuzzlePage가 GameColors.of(context)를 읽는다
          home: const HomePage(),
        ),
      );

  /// 감소 모션(07-05-03 "감소 모션" 테스트): `MediaQuery`는 `home:`의 자식으로
  /// 둔다 — `MaterialApp` 바깥에 두면 루트 뷰의 MediaQuery에 가려진다
  /// (theme_test.dart·puzzle_screen_test.dart와 같은 자리).
  Widget wrapHomeReducedMotion(AppScope scope) => MultiProvider(
        providers: [
          Provider<AppScope>.value(value: scope),
          ChangeNotifierProvider(create: (_) => SettingsModel()),
        ],
        child: MaterialApp(
          theme: buildLightTheme(),
          home: const MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: HomePage(),
          ),
        ),
      );

  /// 기본 테스트 뷰포트(약 800×600)로는 레벨 10줄 + 히어로 + 통계가 다 안
  /// 들어가 `ListView`가 화면 밖 항목을 아예 빌드하지 않는다. 전부 렌더되도록
  /// 세로로 넉넉한 화면을 쓴다.
  Future<void> useTallViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('홈 화면 히어로 · 통계', () {
    testWidgets('히어로: 미클리어 첫 레벨', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);
      await db.customStatement(
        'INSERT INTO puzzle_log (level_id, seed, first_score, submitted_at) '
        'VALUES (?, ?, ?, ?)',
        [levels.first.id, 1, 3, 0],
      );

      await tester.pumpWidget(wrapHome(buildScope(db)));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(HeroCard),
          matching: find.text(levels[1].name),
        ),
        findsOneWidget,
      );
      expect(find.text('이어하기'), findsOneWidget);
    });

    testWidgets('히어로: 전부 클리어', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);
      for (final spec in levels) {
        await db.customStatement(
          'INSERT INTO puzzle_log (level_id, seed, first_score, submitted_at) '
          'VALUES (?, ?, ?, ?)',
          [spec.id, 1, 3, 0],
        );
      }

      await tester.pumpWidget(wrapHome(buildScope(db)));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(HeroCard),
          matching: find.text(levels.last.name),
        ),
        findsOneWidget,
      );
      expect(find.text('다시 도전'), findsOneWidget);
      expect(find.text('이어하기'), findsNothing);
    });

    testWidgets('히어로 시작 탭', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb(); // 통계 없음 → nextLevel == 레벨 1
      addTearDown(db.close);

      await tester.pumpWidget(wrapHome(buildScope(db)));
      await tester.pumpAndSettle();

      final model = Provider.of<HomeModel>(
        tester.element(find.byType(HeroCard)),
        listen: false,
      );
      final expectedId = model.nextLevel!.spec.id;

      await tester.tap(find.widgetWithText(FilledButton, '시작'));
      await tester.pumpAndSettle();

      final page = tester.widget<PuzzlePage>(find.byType(PuzzlePage));
      expect(page.spec?.id, expectedId);
    });

    testWidgets('통계', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO word_stat (headword, correct, wrong, last_seen) "
        "VALUES ('가나', 3, 1, 0)",
      );

      await tester.pumpWidget(wrapHome(buildScope(db)));
      await tester.pumpAndSettle();

      expect(find.text('누적 정답률'), findsOneWidget);
      expect(find.text('75%'), findsOneWidget);
      expect(find.text('푼 단어'), findsOneWidget);
      expect(find.text('1개'), findsOneWidget);
    });
  });

  group('레벨 카드 3상태 · E-10 (07-05-03)', () {
    testWidgets('카드 3상태', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);
      // 레벨 1만 클리어 → 레벨 2 해제·미클리어, 3부터 잠김.
      await db.customStatement(
        'INSERT INTO puzzle_log (level_id, seed, first_score, submitted_at) '
        'VALUES (?, ?, ?, ?)',
        [levels.first.id, 1, 3, 0],
      );

      await tester.pumpWidget(wrapHome(buildScope(db)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock), findsNWidgets(levels.length - 2));
      expect(
        find.descendant(
          of: find.widgetWithText(LevelCard, levels[1].name),
          matching: find.text('${levels[1].id}'),
        ),
        findsOneWidget,
        reason: '레벨 2: 해제·미클리어 → 번호 표시',
      );
      final clearedCard = find.widgetWithText(LevelCard, levels.first.name);
      expect(find.descendant(of: clearedCard, matching: find.byIcon(Icons.star)),
          findsOneWidget);
      expect(find.descendant(of: clearedCard, matching: find.text('+3')),
          findsOneWidget);
    });

    testWidgets('카드 색', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);
      await db.customStatement(
        'INSERT INTO puzzle_log (level_id, seed, first_score, submitted_at) '
        'VALUES (?, ?, ?, ?)',
        [levels.first.id, 1, 3, 0],
      );

      await tester.pumpWidget(wrapHome(buildScope(db)));
      await tester.pumpAndSettle();

      final clearedContainer = tester.widget<Container>(
        find
            .descendant(
              of: find.widgetWithText(LevelCard, levels.first.name),
              matching: find.byType(Container),
            )
            .first,
      );
      final clearedDecoration = clearedContainer.decoration as BoxDecoration;
      expect(clearedDecoration.color, GameColors.light.surfaceAlt);

      // 레벨 3(인덱스 2): 아직 잠김(레벨 2까지만 해제).
      final lockedName = tester.widget<Text>(find.descendant(
        of: find.widgetWithText(LevelCard, levels[2].name),
        matching: find.text(levels[2].name),
      ));
      expect(lockedName.style?.color, GameColors.light.inkMuted);
    });

    testWidgets('E-10', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(wrapHome(buildScope(db)));
      await tester.pumpAndSettle(); // 1회 load(): 비교 대상 없어 justUnlockedId == null

      await db.customStatement(
        'INSERT INTO puzzle_log (level_id, seed, first_score, submitted_at) '
        'VALUES (?, ?, ?, ?)',
        [levels.first.id, 1, 3, 0],
      );
      final model = Provider.of<HomeModel>(
        tester.element(find.byType(HeroCard)),
        listen: false,
      );
      await model.load(); // 2회: 레벨 2가 새로 해제 → justUnlockedId == 2

      // pump() 2번: 1번째는 justUnlocked==true로 다시 빌드(플립 예약),
      // 2번째가 플립이 시작되는 프레임 — 이때 자물쇠·번호가 공존한다.
      await tester.pump();
      await tester.pump();

      final card2 = find.widgetWithText(LevelCard, levels[1].name);
      expect(find.descendant(of: card2, matching: find.byIcon(Icons.lock)),
          findsOneWidget,
          reason: '플립 진행 중 자물쇠와 번호가 공존');
      expect(
          find.descendant(
              of: card2, matching: find.text('${levels[1].id}')),
          findsOneWidget);

      // 정확히 motion.base만큼 pump하면 AnimationController 상태 갱신이
      // 아직 반영되지 않아 자물쇠가 남아 있는 것으로 보일 수 있다(플레이키) —
      // 07-03-02 grid_view_test.dart 등과 같은 이유로 pumpAndSettle을 쓴다.
      await tester.pumpAndSettle(); // 플립 완료

      expect(find.descendant(of: card2, matching: find.byIcon(Icons.lock)),
          findsNothing);
      expect(
          find.descendant(
              of: card2, matching: find.text('${levels[1].id}')),
          findsOneWidget);
    });

    testWidgets('감소 모션', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(wrapHomeReducedMotion(buildScope(db)));
      await tester.pumpAndSettle();

      await db.customStatement(
        'INSERT INTO puzzle_log (level_id, seed, first_score, submitted_at) '
        'VALUES (?, ?, ?, ?)',
        [levels.first.id, 1, 3, 0],
      );
      final model = Provider.of<HomeModel>(
        tester.element(find.byType(HeroCard)),
        listen: false,
      );
      await model.load();

      await tester.pump(); // 감소 모션이면 첫 프레임부터 최종 상태

      final card2 = find.widgetWithText(LevelCard, levels[1].name);
      expect(find.descendant(of: card2, matching: find.byIcon(Icons.lock)),
          findsNothing, reason: '감소 모션이면 자물쇠 단계를 건너뛴다');
      expect(
          find.descendant(
              of: card2, matching: find.text('${levels[1].id}')),
          findsOneWidget);
    });
  });
}
