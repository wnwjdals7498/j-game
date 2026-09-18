// 04-05 제출 확인 · 결과 화면 테스트.
//
// "제출 확인 다이얼로그"·"첫 제출/재제출" 그룹은 `PuzzleModel.submit`을
// 직접 호출한다 — word_input_test.dart(04-04)와 같은 2×2 교차 격자를 손으로
// 만들어 `model.puzzle`에 꽂고, `showDialog`가 필요한 `BuildContext`만 최소
// 위젯(`Builder`)으로 제공한다. "첫 제출/재제출"만 `tools/schema.sql`(단일
// 진실)로 만든 실 DB에 대해 `StatRepository`를 함께 검증한다
// (stat_repository_test.dart 03-04와 같은 패턴).
//
// "결과 화면" 그룹은 `ResultPage`를 `PuzzleModel`·`Navigator` 없이 단독으로
// pump한다 — 이 화면은 표시 전용 위젯이라 필요한 값(스펙·격자·채점 결과·힌트)만
// 생성자로 받는다(result_page.dart 주석 참고).
//
// 통합 그룹만 `PuzzlePage`를 실제로 띄워 더미 사전(01-10)으로 퍼즐을 생성하고
// 제출→결과 화면→다음 레벨까지 실제 위젯 트리로 확인한다 — shell_test.dart
// (04-01)·levels_test.dart(03-06 "더미 사전으로 전 레벨이 생성된다")와 같은
// 패턴이라 결정성이 이미 검증돼 있다.
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
import 'package:jgame/domain/levels.dart';
import 'package:jgame/domain/model/level_spec.dart';
import 'package:jgame/domain/model/puzzle.dart';
import 'package:jgame/domain/model/submit_result.dart';
import 'package:jgame/domain/scoring/scorer.dart';
import 'package:jgame/ui/puzzle/grid_view.dart';
import 'package:jgame/ui/puzzle/puzzle_page.dart';
import 'package:jgame/ui/result/result_page.dart';
import 'package:jgame/ui/state/app_scope.dart';
import 'package:jgame/ui/theme/app_theme.dart';
import 'package:jgame/ui/state/puzzle_model.dart';
import 'package:jgame/ui/state/settings_model.dart';

/// word_input_test.dart(04-04)의 `_crossPuzzle`과 같은 모양이지만, (1,1)을
/// 검은 칸으로 둔다 — `Scorer.blankCellCount`가 격자 전체(단어가 아닌 칸
/// 포함)를 훑으므로, 실제 생성기 출력처럼 단어가 지나지 않는 칸은 막아 둬야
/// "빈칸 없음" 케이스를 정확히 만들 수 있다.
/// - '사과' 가로 (0,0)~(0,1)
/// - '사슴' 세로 (0,0)~(1,0) — (0,0)에서 교차
Puzzle _crossPuzzle() {
  const cells = [
    [Cell.filled('사'), Cell.filled('과')],
    [Cell.filled('슴'), Cell.blocked()],
  ];
  return const Puzzle(
    levelId: 7,
    width: 2,
    height: 2,
    cells: cells,
    words: [
      PlacedWord(
        headword: '사과',
        row: 0,
        col: 0,
        dir: Direction.across,
        isCore: false,
        tier: 1,
      ),
      PlacedWord(
        headword: '사슴',
        row: 0,
        col: 0,
        dir: Direction.down,
        isCore: false,
        tier: 1,
      ),
    ],
    seed: 42,
    attempts: 1,
  );
}

/// 두 단어 모두 정답인 입력 (총 정답 2, 오답/빈칸 0).
Map<(int, int), String> _correctAnswers() =>
    {(0, 0): '사', (0, 1): '과', (1, 0): '슴'};

/// 표시 전용 검증용 3단어 격자. 3×3, 서로 교차하지 않는다.
/// `words` 등록 순서를 격자 위치 순서와 **일부러 다르게** 둔다 — 결과 화면이
/// 번호 순(위→아래)으로 다시 정렬하는지 보기 위해서다(04-05 "정렬").
/// - '사과' 가로 (2,0)~(2,1)  → words[0], 격자에서는 맨 아래(3번째로 보여야 함)
/// - '나무' 가로 (0,0)~(0,1)  → words[1], 격자 맨 위(1번째로 보여야 함)
/// - '바나나' 가로 (1,0)~(1,2) → words[2], 중간(2번째로 보여야 함)
Puzzle _threeWordPuzzle() {
  const cells = [
    [Cell.filled('나'), Cell.filled('무'), Cell.blocked()],
    [Cell.filled('바'), Cell.filled('나'), Cell.filled('나')],
    [Cell.filled('사'), Cell.filled('과'), Cell.blocked()],
  ];
  const apple = PlacedWord(
      headword: '사과', row: 2, col: 0, dir: Direction.across, isCore: false, tier: 1);
  const tree = PlacedWord(
      headword: '나무', row: 0, col: 0, dir: Direction.across, isCore: false, tier: 1);
  const banana = PlacedWord(
      headword: '바나나', row: 1, col: 0, dir: Direction.across, isCore: false, tier: 1);
  return const Puzzle(
    levelId: 1,
    width: 3,
    height: 3,
    cells: cells,
    words: [apple, tree, banana],
    seed: 1,
    attempts: 1,
  );
}

/// `_threeWordPuzzle`용 채점 결과: 나무=정답, 바나나=오답(입력 "바나다"),
/// 사과=빈칸. 상태 3종을 한 화면에서 모두 보기 위해서다(04-05 "상태").
SubmitResult _threeWordResult({bool isFirstSubmit = true}) {
  final words = _threeWordPuzzle().words;
  final tree = words.firstWhere((w) => w.headword == '나무');
  final banana = words.firstWhere((w) => w.headword == '바나나');
  final apple = words.firstWhere((w) => w.headword == '사과');
  return SubmitResult(
    [
      WordResult(tree, '나무', WordOutcome.correct),
      WordResult(banana, '바나다', WordOutcome.wrong),
      WordResult(apple, '  ', WordOutcome.blank),
    ],
    isFirstSubmit: isFirstSubmit,
  );
}

/// `model.submit(context)`를 호출할 수 있게 `BuildContext`만 제공하는 최소
/// 위젯. 다이얼로그를 띄우기만 하고 닫지 않는다 — 내용(빈칸 문구)을 검증한
/// 뒤 [_confirmDialog]/[_cancelDialog]로 직접 닫는다.
Future<void> _openSubmitDialog(WidgetTester tester, PuzzleModel model) async {
  await tester.pumpWidget(MaterialApp(
    theme: buildLightTheme(), // 07-04-04: 시트가 GameColors.of(context)를 읽는다
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => model.submit(context),
          child: const Text('제출'),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('제출'));
  await tester.pumpAndSettle();
}

/// 다이얼로그의 "제출" 버튼(밑에 깔린 원래 버튼과 라벨이 같아 `.last`로
/// 고른다 — 04-07 계획 문서의 `play_loop_test.dart` 스니펫과 같은 방식).
Future<void> _confirmDialog(WidgetTester tester) async {
  await tester.tap(find.text('제출').last);
  await tester.pumpAndSettle();
}

Future<void> _cancelDialog(WidgetTester tester) async {
  await tester.tap(find.text('계속 풀기'));
  await tester.pumpAndSettle();
}

/// 다이얼로그를 띄우고 바로 확인/취소까지 마친다 (내용 검증이 필요 없는
/// 테스트용).
Future<void> _submitViaDialog(
  WidgetTester tester,
  PuzzleModel model, {
  required bool confirm,
}) async {
  await _openSubmitDialog(tester, model);
  if (confirm) {
    await _confirmDialog(tester);
  } else {
    await _cancelDialog(tester);
  }
}

void main() {
  group('제출 확인 다이얼로그 · 첫 제출/재제출', () {
    late Directory tmp;
    late String schemaSql;
    var dbSeq = 0;

    setUpAll(() {
      schemaSql = File('../tools/schema.sql').readAsStringSync();
    });

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('submit_test_');
      dbSeq = 0;
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

    /// word_input_test.dart(04-04)의 `newModel`과 같은 패턴: `scope`는 생성자
    /// 계약을 채울 뿐 `load()`는 부르지 않고 `puzzle`을 직접 손으로 꽂는다.
    PuzzleModel newModel({LevelSpec? spec}) {
      final db = openEmptyDb();
      addTearDown(db.close);
      final words = InMemoryWordRepository(buildDummyDictionary(seed: 1));
      final scope = AppScope(
        db: db,
        words: words,
        stats: StatRepository(db),
        generator: GridGenerator(words),
        hints: HintRepository(db),
      );
      return PuzzleModel(scope, spec ?? levels.first)..puzzle = _crossPuzzle();
    }

    testWidgets('빈칸 있음: 빈칸 개수 문구 표시', (tester) async {
      final model = newModel()..answers = {(0, 0): '사'}; // 2칸 빈칸
      await _openSubmitDialog(tester, model);
      expect(find.text('빈 칸이 2개 있습니다. 빈 칸은 오답으로 처리됩니다.'),
          findsOneWidget);
      await _cancelDialog(tester);
    });

    testWidgets('빈칸 없음: "모든 칸을 채웠습니다"', (tester) async {
      final model = newModel()..answers = _correctAnswers();
      await _openSubmitDialog(tester, model);
      expect(find.text('모든 칸을 채웠습니다.'), findsOneWidget);
      await _cancelDialog(tester);
    });

    testWidgets('취소: 제출 안 됨, submitted == false', (tester) async {
      final model = newModel()..answers = _correctAnswers();
      await _submitViaDialog(tester, model, confirm: false);
      expect(model.submitted, isFalse);
      expect(model.result, isNull);
    });

    testWidgets('제출: result != null', (tester) async {
      final model = newModel()..answers = _correctAnswers();
      await _submitViaDialog(tester, model, confirm: true);
      expect(model.submitted, isTrue);
      expect(model.result, isNotNull);
      expect(model.result!.correctCount, 2);
    });

    testWidgets('첫 제출: isFirstSubmit == true, word_stat 반영', (tester) async {
      final model = newModel()..answers = _correctAnswers();
      await _submitViaDialog(tester, model, confirm: true);

      expect(model.result!.isFirstSubmit, isTrue);
      final summary = await model.scope.stats.summary();
      expect(summary.words, 2, reason: '사과·사슴 두 단어');
      expect(summary.correct, 2);
      expect(summary.wrong, 0);
    });

    testWidgets('재제출: isFirstSubmit == false, word_stat 불변', (tester) async {
      final model = newModel()..answers = _correctAnswers();
      await _submitViaDialog(tester, model, confirm: true); // 첫 제출
      await _submitViaDialog(tester, model, confirm: true); // 재제출(같은 seed)

      expect(model.result!.isFirstSubmit, isFalse);
      final summary = await model.scope.stats.summary();
      expect(summary.correct, 2, reason: '재제출로 두 배가 되면 안 된다');
      expect(summary.wrong, 0);
    });

    testWidgets('다시 풀기: 같은 seed, answers 초기화', (tester) async {
      final model = newModel()..answers = _correctAnswers();
      await _submitViaDialog(tester, model, confirm: true);
      final puzzleBefore = model.puzzle;
      expect(model.submitted, isTrue);

      model.retry();

      expect(model.answers, isEmpty);
      expect(model.submitted, isFalse);
      expect(model.result, isNull);
      expect(model.selected, isNull);
      expect(identical(model.puzzle, puzzleBefore), isTrue,
          reason: '같은 seed·같은 퍼즐이라 재생성하지 않는다');
      expect(model.puzzle!.seed, 42);
    });
  });

  group('결과 화면 (ResultPage)', () {
    Widget wrap(Widget child) => MaterialApp(home: child);

    testWidgets('결과 목록: 단어 수만큼 행, 번호 순으로 정렬', (tester) async {
      await tester.pumpWidget(wrap(ResultPage(
        spec: levels.first,
        puzzle: _threeWordPuzzle(),
        result: _threeWordResult(),
      )));

      expect(find.byType(ListTile), findsNWidgets(3));

      // 번호 순(위→아래): 나무(0행) → 바나나(1행) → 사과(2행). `puzzle.words`
      // 등록 순서(사과·나무·바나나)와 다르므로, 실제로 다시 정렬됐을 때만
      // 화면상 y좌표 순서가 이렇게 나온다.
      final treeY = tester.getTopLeft(find.textContaining('나무').first).dy;
      final bananaY = tester.getTopLeft(find.textContaining('바나나').first).dy;
      final appleY = tester.getTopLeft(find.textContaining('사과').first).dy;
      expect(treeY, lessThan(bananaY));
      expect(bananaY, lessThan(appleY));
    });

    testWidgets('상태 구분: 정답/오답/빈칸 아이콘이 다름', (tester) async {
      await tester.pumpWidget(wrap(ResultPage(
        spec: levels.first,
        puzzle: _threeWordPuzzle(),
        result: _threeWordResult(),
      )));

      expect(find.byIcon(Icons.check_circle), findsOneWidget, reason: '정답 1개');
      expect(find.byIcon(Icons.cancel), findsOneWidget, reason: '오답 1개');
      expect(find.byIcon(Icons.radio_button_unchecked), findsOneWidget,
          reason: '빈칸 1개');
      expect(find.textContaining('입력: 바나다'), findsOneWidget);
      expect(find.textContaining('입력: (빈칸)'), findsOneWidget);
    });

    testWidgets('뜻풀이 노출: 마스킹 없이 표시', (tester) async {
      await tester.pumpWidget(wrap(ResultPage(
        spec: levels.first,
        puzzle: _threeWordPuzzle(),
        result: _threeWordResult(),
        hints: const {
          '나무': Hint('줄기가 목질로 된 식물.', ['수목', '목본']),
        },
      )));

      // hintTextFor(04-03)와 달리 표제어를 ○로 가리지 않아야 한다.
      expect(find.text('줄기가 목질로 된 식물.'), findsOneWidget);
      expect(find.textContaining('○'), findsNothing);
      expect(find.textContaining('유의어: 수목, 목본'), findsOneWidget);
    });

    testWidgets('재제출 안내: isFirstSubmit == false일 때만 표시', (tester) async {
      await tester.pumpWidget(wrap(ResultPage(
        spec: levels.first,
        puzzle: _threeWordPuzzle(),
        result: _threeWordResult(isFirstSubmit: false),
      )));
      expect(find.textContaining('재제출이라 기록에 반영되지 않았습니다'), findsOneWidget);
    });

    testWidgets('첫 제출이면 재제출 안내가 없다', (tester) async {
      await tester.pumpWidget(wrap(ResultPage(
        spec: levels.first,
        puzzle: _threeWordPuzzle(),
        result: _threeWordResult(),
      )));
      expect(find.textContaining('재제출이라 기록에 반영되지 않았습니다'), findsNothing);
    });

    testWidgets('다시 풀기 버튼: onRetry 콜백 호출', (tester) async {
      var called = false;
      await tester.pumpWidget(wrap(ResultPage(
        spec: levels.first,
        puzzle: _threeWordPuzzle(),
        result: _threeWordResult(),
        onRetry: () => called = true,
      )));
      await tester.tap(find.text('다시 풀기'));
      expect(called, isTrue);
    });

    testWidgets('다음 레벨(마지막 아님): 버튼 라벨 "다음 레벨", 콜백 호출', (tester) async {
      var called = false;
      await tester.pumpWidget(wrap(ResultPage(
        spec: levels.first, // 마지막 레벨이 아님
        puzzle: _threeWordPuzzle(),
        result: _threeWordResult(),
        onNextLevel: () => called = true,
      )));
      expect(find.text('다음 레벨'), findsOneWidget);
      expect(find.text('홈으로'), findsNothing);
      await tester.tap(find.text('다음 레벨'));
      expect(called, isTrue);
    });

    testWidgets('마지막 레벨: "다음 레벨" 대신 "홈으로"', (tester) async {
      var called = false;
      await tester.pumpWidget(wrap(ResultPage(
        spec: levels.last, // 마지막 레벨
        puzzle: _threeWordPuzzle(),
        result: _threeWordResult(),
        onNextLevel: () => called = true,
      )));
      expect(find.text('홈으로'), findsOneWidget);
      expect(find.text('다음 레벨'), findsNothing);
      await tester.tap(find.text('홈으로'));
      expect(called, isTrue);
    });

    testWidgets('레벨 해제: score >= clearScore(첫 제출) → 안내 표시', (tester) async {
      // '나무'만 있는 1단어 퍼즐 전부 정답 → correct=1, wrong=0, score=1 >=
      // clearScore(기본 0).
      final onlyTree = _threeWordPuzzle().words.firstWhere((w) => w.headword == '나무');
      final unlockResult = SubmitResult(
        [WordResult(onlyTree, '나무', WordOutcome.correct)],
        isFirstSubmit: true,
      );
      await tester.pumpWidget(wrap(ResultPage(
        spec: levels.first,
        puzzle: _threeWordPuzzle(),
        result: unlockResult,
      )));
      expect(find.textContaining('레벨 ${levels[1].id}이 열렸습니다'), findsOneWidget);
    });

    testWidgets('레벨 해제 안 됨: score < clearScore → 안내 없음', (tester) async {
      await tester.pumpWidget(wrap(ResultPage(
        spec: levels.first,
        puzzle: _threeWordPuzzle(),
        result: _threeWordResult(), // score = 1 - 2 = -1 < 0
      )));
      expect(find.textContaining('열렸습니다'), findsNothing);
    });

    testWidgets('레벨 해제 조건이어도 재제출이면 안내 없음', (tester) async {
      final onlyTree = _threeWordPuzzle().words.firstWhere((w) => w.headword == '나무');
      final unlockResult = SubmitResult(
        [WordResult(onlyTree, '나무', WordOutcome.correct)],
        isFirstSubmit: false,
      );
      await tester.pumpWidget(wrap(ResultPage(
        spec: levels.first,
        puzzle: _threeWordPuzzle(),
        result: unlockResult,
      )));
      expect(find.textContaining('열렸습니다'), findsNothing,
          reason: '재제출은 puzzle_log/bestScore에 반영되지 않는다(03-04)');
    });
  });

  group('다음 레벨 계산 (순수 함수)', () {
    test('마지막이 아니면 목록상 다음 레벨', () {
      final next = nextLevelOf(levels.first);
      expect(next, isNotNull);
      expect(next!.id, levels[1].id);
    });

    test('마지막 레벨이면 null', () {
      expect(nextLevelOf(levels.last), isNull);
    });

    test('newSeed: 유효 범위(0..0x7FFFFFFF)의 정수', () {
      final s = newSeed();
      expect(s, greaterThanOrEqualTo(0));
      expect(s, lessThanOrEqualTo(0x7FFFFFFF));
    });
  });

  group('통합: PuzzlePage 실제 흐름', () {
    late Directory tmp;
    late String schemaSql;

    setUpAll(() {
      schemaSql = File('../tools/schema.sql').readAsStringSync();
    });

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('submit_integration_');
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
          child: MaterialApp(
            theme: buildLightTheme(), // PuzzlePage → PuzzleGridView가 GameColors.of(context)를 읽는다
            home: child,
          ),
        );

    testWidgets(
      '제출 → 결과 화면 진입 → 레벨 해제 안내 → 다음 레벨(새 seed)',
      (tester) async {
        final scope = buildScope();
        // seed 1000: levels_test.dart(03-06)의 "더미 사전으로 전 레벨이
        // 생성된다"가 전 레벨 × (1000, 2000, ..., 20000) 성공을 이미 확인했다.
        await tester
            .pumpWidget(wrapApp(scope, PuzzlePage(spec: levels.first, seed: 1000)));
        await tester.pumpAndSettle();

        expect(find.byType(PuzzleGridView), findsOneWidget);
        final model = Provider.of<PuzzleModel>(
            tester.element(find.byType(PuzzleGridView)),
            listen: false);
        final puzzle = model.puzzle!;

        // 전부 정답으로 채운다 — 결과 화면·레벨 해제 배너까지 확인하기 위해
        // (Scorer.solutionOf, 01-08 "테스트·디버그용").
        model.answers = Scorer.solutionOf(puzzle);
        model.notifyListeners();
        await tester.pump();

        await tester.tap(find.text('제출'));
        await tester.pumpAndSettle();
        expect(find.text('모든 칸을 채웠습니다.'), findsOneWidget);

        await tester.tap(find.text('제출').last);
        await tester.pumpAndSettle();

        expect(find.byType(ResultPage), findsOneWidget, reason: '결과 화면 진입');
        expect(
            find.textContaining('${puzzle.words.length} / ${puzzle.words.length}'),
            findsOneWidget);
        expect(find.textContaining('레벨 ${levels[1].id}이 열렸습니다'), findsOneWidget,
            reason: '만점(score >= clearScore)이면 다음 레벨 해제 안내');

        await tester.tap(find.text('다음 레벨'));
        await tester.pumpAndSettle();

        expect(find.byType(ResultPage), findsNothing);
        expect(find.text(levels[1].name), findsOneWidget,
            reason: '다음 레벨(id+1) 화면으로 전환');
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
