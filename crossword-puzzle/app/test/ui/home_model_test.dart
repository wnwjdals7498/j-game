// HomeModel 확장(07-05-01) 테스트: nextLevel · allCleared · justUnlockedId,
// 퍼즐에서 돌아오면 홈이 재로드되는지.
//
// `home_settings_test.dart`의 `openEmptyDb()`·`buildScope()`·`wrapHome()`·
// `useTallViewport()` 패턴을 그대로 베낀다 — 빈 실 DB에 필요한 값만 손으로
// 심어(customStatement) `HomeModel`이 만드는 상태를 확인한다.
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
import 'package:jgame/domain/model/submit_result.dart';
import 'package:jgame/ui/home/home_page.dart';
import 'package:jgame/ui/home/level_card.dart';
import 'package:jgame/ui/puzzle/puzzle_page.dart';
import 'package:jgame/ui/state/app_scope.dart';
import 'package:jgame/ui/state/home_model.dart';
import 'package:jgame/ui/state/settings_model.dart';
import 'package:jgame/ui/theme/app_theme.dart';

/// 호출 횟수를 세는 가짜. 실 [StatRepository]를 감싸 위임한다(6개 public
/// 메서드 전부 `@override`) — "돌아오면 재로드"에서 `bestScores()` 호출
/// 횟수로 `HomeModel.load()`가 몇 번 돌았는지 센다.
class _CountingStats implements StatRepository {
  _CountingStats(this._inner);
  final StatRepository _inner;
  int bestScoresCalls = 0;

  @override
  Future<Map<int, int>> bestScores() {
    bestScoresCalls++;
    return _inner.bestScores();
  }

  @override
  Future<int?> bestScore(int levelId) => _inner.bestScore(levelId);

  @override
  Future<bool> isFirstSubmit(int levelId, int seed) =>
      _inner.isFirstSubmit(levelId, seed);

  @override
  Future<bool> recordSubmit({
    required int levelId,
    required int seed,
    required SubmitResult result,
  }) =>
      _inner.recordSubmit(levelId: levelId, seed: seed, result: result);

  @override
  Future<({int correct, int wrong, int words})> summary() => _inner.summary();

  @override
  Future<void> resetAll() => _inner.resetAll();
}

void main() {
  late Directory tmp;
  late String schemaSql;
  var dbSeq = 0;

  setUpAll(() {
    schemaSql = File('../tools/schema.sql').readAsStringSync();
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('home_model_test_');
    dbSeq = 0;
    // 안 넣으면 퍼즐 진입 시 튜토리얼 시트('이렇게 플레이해요')가 떠서 pop이
    // 막힌다(puzzle_page.dart `_maybeShowTutorial`).
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

  AppScope buildScope(AppDatabase db, {StatRepository? stats}) {
    final words = InMemoryWordRepository(buildDummyDictionary(seed: 1));
    return AppScope(
      db: db,
      words: words,
      stats: stats ?? StatRepository(db),
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

  /// 기본 테스트 뷰포트(약 800×600)로는 레벨 10줄 + 통계 헤더가 다 안 들어가
  /// `ListView`가 화면 밖 항목을 아예 빌드하지 않는다. 전부 렌더되도록 세로로
  /// 넉넉한 화면을 쓴다.
  Future<void> useTallViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('HomeModel', () {
    test('nextLevel: 해제·미클리어 첫 레벨', () async {
      final db = openEmptyDb();
      addTearDown(db.close);
      await db.customStatement(
        'INSERT INTO puzzle_log (level_id, seed, first_score, submitted_at) '
        'VALUES (?, ?, ?, ?)',
        [levels.first.id, 1, 3, 0],
      );

      final model = HomeModel(buildScope(db));
      await model.load();

      expect(model.nextLevel!.spec.id, 2);
      expect(model.allCleared, isFalse);
    });

    test('nextLevel: 전부 클리어면 마지막 레벨', () async {
      final db = openEmptyDb();
      addTearDown(db.close);
      for (final spec in levels) {
        await db.customStatement(
          'INSERT INTO puzzle_log (level_id, seed, first_score, submitted_at) '
          'VALUES (?, ?, ?, ?)',
          [spec.id, 1, 3, 0],
        );
      }

      final model = HomeModel(buildScope(db));
      await model.load();

      expect(model.nextLevel!.spec.id, levels.last.id);
      expect(model.allCleared, isTrue);
    });

    test('justUnlockedId: 첫 load는 null', () async {
      final db = openEmptyDb(); // 빈 DB
      addTearDown(db.close);

      final model = HomeModel(buildScope(db));
      await model.load();

      expect(model.justUnlockedId, isNull);
    });

    test('justUnlockedId: 두 번째 load에서 새로 열린 레벨', () async {
      final db = openEmptyDb();
      addTearDown(db.close);
      final model = HomeModel(buildScope(db));
      await model.load(); // 1회: 레벨 1만 해제 상태, 비교 대상 없어 null

      await db.customStatement(
        'INSERT INTO puzzle_log (level_id, seed, first_score, submitted_at) '
        'VALUES (?, ?, ?, ?)',
        [levels.first.id, 1, 3, 0],
      );
      await model.load(); // 2회: 레벨 1 클리어 → 레벨 2가 새로 해제

      expect(model.justUnlockedId, 2);
    });
  });

  group('홈 → 퍼즐 → 복귀', () {
    testWidgets('돌아오면 재로드: pop 후 bestScores() 재조회', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);
      final stats = _CountingStats(StatRepository(db));

      await tester.pumpWidget(wrapHome(buildScope(db, stats: stats)));
      await tester.pumpAndSettle();
      expect(stats.bestScoresCalls, 1, reason: '최초 진입 시 1회');

      // 히어로가 같은 이름을 표시해 find.text가 2개를 찾으므로 카드로
      // 좁힌다(07-05-03, INV-08 이름 유지).
      await tester.tap(find.widgetWithText(LevelCard, levels.first.name));
      await tester.pumpAndSettle();
      expect(find.byType(PuzzlePage), findsOneWidget);

      Navigator.of(tester.element(find.byType(PuzzlePage))).pop();
      await tester.pumpAndSettle();

      expect(stats.bestScoresCalls, 2, reason: 'pop 후 HomeModel.load()가 다시 돎');
    });
  });
}
