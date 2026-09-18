// 04-01 앱 셸·상태 관리 테스트 (부트스트랩 로딩/실패/성공, 라우트 등록,
// PuzzleModel 골격).
//
// 실 `DbBootstrap.open()`은 `rootBundle`/`path_provider`가 필요해 위젯
// 테스트에서 돌리지 않는다 — 04-01 "막히면": "테스트에서는 AppScope를 직접
// 주입하고 부트스트랩을 건너뛴다. 부트스트랩 자체는 03-02에서 테스트했다."
// 대신 `tools/schema.sql`(02-09, 단일 진실)로 빈 인메모리 DB를 만들고
// `InMemoryWordRepository`(01-10)를 붙인 가짜 [AppScope]를
// `JGameApp.bootstrap`에 완료/미완료/에러 Future로 직접 주입한다
// (stat_repository_test.dart 03-04의 `openEmpty`와 같은 패턴).
import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:jgame/data/db/app_database.dart';
import 'package:jgame/data/hint_repository.dart';
import 'package:jgame/data/stat_repository.dart';
import 'package:jgame/domain/fixtures/dummy_dictionary.dart';
import 'package:jgame/domain/generator/grid_generator.dart';
import 'package:jgame/domain/model/level_spec.dart';
import 'package:jgame/domain/model/puzzle.dart';
import 'package:jgame/main.dart';
import 'package:jgame/ui/bootstrap/bootstrap_pages.dart';
import 'package:jgame/ui/home/home_page.dart';
import 'package:jgame/ui/puzzle/puzzle_page.dart';
import 'package:jgame/ui/result/result_page.dart';
import 'package:jgame/ui/settings/settings_page.dart';
import 'package:jgame/ui/state/app_scope.dart';
import 'package:jgame/ui/state/puzzle_model.dart';

/// stat_repository_test.dart(03-04)의 `openEmpty`와 같은 패턴: `tools/schema.sql`
/// 로 빈 DB를 만든다.
AppDatabase _openEmptyDb(String path, String schemaSql) {
  final raw = sqlite3.open(path);
  raw.execute(schemaSql);
  raw.close();
  return AppDatabase(NativeDatabase(File(path)));
}

/// grid_generator_test.dart의 `testSpec()`과 같은, 더미 사전으로 성공하는 스펙.
LevelSpec _workingSpec() => const LevelSpec(
      id: 1,
      name: 'test',
      width: 7,
      height: 7,
      coreTier: 3,
      coreCount: 2,
      fillQuotas: [TierQuota(1, 2, 4), TierQuota(2, 1, 3)],
      maxAttempts: 20,
    );

/// grid_generator_test.dart의 `impossible`과 같은 근거: 3×3에 코어 5개는
/// 성긴 격자 규칙상 들어갈 수 없다.
LevelSpec _impossibleSpec() => const LevelSpec(
      id: 9,
      name: 'impossible',
      width: 3,
      height: 3,
      coreTier: 3,
      coreCount: 5,
      fillQuotas: [TierQuota(1, 2, 4), TierQuota(2, 1, 3)],
      maxAttempts: 5,
    );

void main() {
  late Directory tmp;
  late String schemaSql;
  late AppDatabase db;
  late AppScope scope;

  setUpAll(() {
    schemaSql = File('../tools/schema.sql').readAsStringSync();
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('shell_test_');
    db = _openEmptyDb('${tmp.path}/t.sqlite', schemaSql);
    final words = InMemoryWordRepository(buildDummyDictionary(seed: 1));
    scope = AppScope(
      db: db,
      words: words,
      stats: StatRepository(db),
      generator: GridGenerator(words),
      hints: HintRepository(db),
    );
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('부트스트랩', () {
    testWidgets('로딩: Future 미완료 시 로딩 화면', (tester) async {
      final completer = Completer<AppScope>();
      await tester.pumpWidget(JGameApp(bootstrap: completer.future));
      await tester.pump();

      expect(find.byType(BootstrapLoadingPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
    });

    testWidgets('실패: 예외 시 에러 화면 + 메시지', (tester) async {
      // 이미 에러로 완료된 Future를 바로 넘기면, FutureBuilder가 구독하기 전에
      // Dart가 "처리되지 않은 에러"로 판단해 테스트가 실패한다. Completer로
      // 위젯이 먼저 구독한 뒤(= pumpWidget으로 빌드된 뒤) 에러를 완료시킨다.
      final completer = Completer<AppScope>();
      await tester.pumpWidget(JGameApp(bootstrap: completer.future));
      completer.completeError(Exception('부트스트랩 실패 테스트'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(BootstrapErrorPage), findsOneWidget);
      expect(find.textContaining('부트스트랩 실패 테스트'), findsOneWidget);
    });

    testWidgets('성공: 홈 화면 표시', (tester) async {
      await tester.pumpWidget(JGameApp(bootstrap: Future.value(scope)));
      await tester.pumpAndSettle();

      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(BootstrapLoadingPage), findsNothing);
      expect(find.byType(BootstrapErrorPage), findsNothing);
    });
  });

  testWidgets('라우트 등록: 4개 라우트가 전부 정의됨, 이동 가능', (tester) async {
    await tester.pumpWidget(JGameApp(bootstrap: Future.value(scope)));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(buildRoutes().keys, containsAll(['/', '/play', '/result', '/settings']));
    expect(app.onGenerateRoute, isNotNull);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    navigator.pushNamed('/play');
    await tester.pumpAndSettle();
    expect(find.byType(PuzzlePage), findsOneWidget);

    navigator.pushNamed('/result');
    await tester.pumpAndSettle();
    expect(find.byType(ResultPage), findsOneWidget);

    navigator.pushNamed('/settings');
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
  });

  group('PuzzleModel', () {
    test('load 성공: puzzle != null, loading == false', () async {
      final model = PuzzleModel(scope, _workingSpec());
      await model.load(7);

      expect(model.puzzle, isNotNull);
      expect(model.loading, isFalse);
      expect(model.error, isNull);
    });

    test('load 실패: GenerationFailed → error != null, 크래시 없음', () async {
      final model = PuzzleModel(scope, _impossibleSpec());
      await model.load(1);

      expect(model.puzzle, isNull);
      expect(model.loading, isFalse);
      expect(model.error, isA<GenerationFailed>());
    });

    test('notifyListeners: 로드 전후로 리스너 호출', () async {
      final model = PuzzleModel(scope, _workingSpec());
      var calls = 0;
      model.addListener(() => calls++);

      await model.load(7);

      expect(calls, greaterThanOrEqualTo(2), reason: '로드 시작 1회 + 종료 1회');
    });
  });
}
