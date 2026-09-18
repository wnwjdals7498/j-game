// 04-07 "A. 통합 위젯 테스트". 04-02~04-06은 각자 단위 테스트를 가진다
// (grid_view_test.dart·selection_test.dart·word_input_test.dart·submit_test.dart·
// home_settings_test.dart). 여기서는 04-07 문서 "목록" 표의 9행을 1:1로
// 확인한다 — 플레이 루프 전체 1개 + 루프를 구성하는 개별 동작 8개.
//
// B(IME 실기기 수동검증)·C(웹 확인)·D(실기기 루프 확인)는 04-07 "담당"이
// HUMAN이라 이 파일 대상이 아니다.
//
// ## 문서 스니펫과 실제 코드의 차이
//
// 04-07 문서의 `play_loop_test.dart` 스니펫은 `GridView2`·`testApp`·`fakeScope`·
// `cellCenter`라는 이름을 쓴다. 이 저장소에는 그 이름들이 존재한 적이 없다 —
// 04-02는 격자 위젯 이름을 `PuzzleGridView`로 정했고(grid_view.dart 주석:
// "프레임워크 이름과 겹치지 않는 이름을 골랐다"), `testApp`/`fakeScope`
// 헬퍼도 따로 만들지 않았다. 대신 submit_test.dart(04-05)·selection_test.dart
// (04-03)·word_input_test.dart(04-04)·home_settings_test.dart(04-06)가 이미
// 확립해 둔 패턴 — 임시 실 DB(`tools/schema.sql`)로 빈 [AppDatabase]를 열고
// `InMemoryWordRepository(buildDummyDictionary(seed: 1))`로 [AppScope]를 직접
// 만드는 방식 — 을 그대로 따른다. 탭 좌표도 고정값이 아니라
// `tester.getTopLeft`/`tester.getSize`로 구한다(04-07 "막히면": "격자 위젯의
// 실제 렌더 크기를 tester.getRect로 구해 계산한다. 고정 좌표를 쓰지
// 않는다" — grid_view_test.dart와 같은 방식).
//
// ## seed 선택
//
// "1. 루프 전체"만 문서 그대로 홈 화면 탭(`newSeed()`, 현재 시각 기반)으로
// 실제 진입 흐름을 검증한다 — 레벨 1(첫걸음)은 코어 2 + 채움 최소 2개로
// 여유롭게 설계돼(01-09/03-06, backtrackBudget 150) 실패율이 1% 미만이라
// 어떤 seed든 사실상 항상 성공한다. 나머지 테스트는 결정성을 위해 seed
// 1000을 쓴다 — submit_test.dart(04-05)의 통합 테스트, levels_test.dart
// (03-06 "더미 사전으로 전 레벨이 생성된다")가 이미 (1000, 2000, ..., 20000)
// 성공을 확인해 둔 값이다.
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
import 'package:jgame/domain/scoring/scorer.dart';
import 'package:jgame/ui/home/home_page.dart';
import 'package:jgame/ui/puzzle/clue_bar.dart';
import 'package:jgame/ui/puzzle/grid_view.dart';
import 'package:jgame/ui/puzzle/puzzle_page.dart';
import 'package:jgame/ui/theme/app_theme.dart';
import 'package:jgame/ui/result/result_page.dart';
import 'package:jgame/ui/settings/license_page.dart';
import 'package:jgame/ui/settings/settings_page.dart';
import 'package:jgame/ui/state/app_scope.dart';
import 'package:jgame/ui/state/puzzle_model.dart';
import 'package:jgame/ui/state/settings_model.dart';

void main() {
  late Directory tmp;
  late String schemaSql;
  var dbSeq = 0;

  setUpAll(() {
    schemaSql = File('../tools/schema.sql').readAsStringSync();
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('play_loop_test_');
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

  /// 다른 04-0x 테스트 파일과 같은 패턴: 더미 사전(01-10)으로 성공하는
  /// [AppScope]를 만든다.
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

  /// submit_test.dart(04-05)의 `wrapApp`과 같은 모양: 실제 라우트 전환
  /// (`Navigator.push`)이 계속 같은 Provider를 보도록 [MaterialApp] 바깥에
  /// [MultiProvider]를 둔다.
  Widget wrapApp(AppScope scope, Widget child) => MultiProvider(
        providers: [
          Provider<AppScope>.value(value: scope),
          ChangeNotifierProvider(create: (_) => SettingsModel()),
        ],
        child: MaterialApp(
          theme: buildLightTheme(), // PuzzleGridView가 GameColors.of(context)를 읽는다
          home: child,
        ),
      );

  /// home_settings_test.dart(04-06)와 같은 이유: 기본 테스트 뷰포트
  /// (약 800×600)로는 `SettingsPage`의 모든 섹션(힌트·DB 정보·정보)이 다
  /// 들어가지 않아 `ListView`가 화면 밖 항목("출처 및 라이선스")을 아예
  /// 빌드하지 않는다 — 레이지 리스트라 완전히 잘림(`Offstage`가 아니라
  /// 위젯 트리에 없음). 전부 렌더되도록 세로로 넉넉한 화면을 쓴다.
  Future<void> useTallViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// 격자 위 (row, col) 셀 중앙의 화면 좌표. grid_view_test.dart와 같은 방식 —
  /// 고정 좌표 대신 위젯의 실제 렌더 크기로 계산한다(04-07 "막히면").
  Offset cellCenter(WidgetTester tester, Puzzle puzzle, int row, int col) {
    final topLeft = tester.getTopLeft(find.byType(PuzzleGridView));
    final size = tester.getSize(find.byType(PuzzleGridView));
    final cell = size.width / puzzle.width;
    return topLeft + Offset(cell * (col + 0.5), cell * (row + 0.5));
  }

  group('A. 통합 위젯 테스트 (04-07)', () {
    testWidgets('1. 루프 전체: 홈 → 퍼즐 → 제출 → 결과 → 다음 레벨',
        (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(wrapApp(buildScope(db), const HomePage()));
      await tester.pumpAndSettle();

      // 1. 홈에서 레벨 1 탭
      await tester.tap(find.text(levels.first.name));
      await tester.pumpAndSettle();
      expect(find.byType(PuzzleGridView), findsOneWidget);

      final model = Provider.of<PuzzleModel>(
          tester.element(find.byType(PuzzleGridView)),
          listen: false);
      final puzzle = model.puzzle!;

      // 2. 셀 탭 → 단어 선택 → 힌트 표시
      final tapWord = puzzle.words.first;
      final (tr, tc) = tapWord.cells.first;
      await tester.tapAt(cellCenter(tester, puzzle, tr, tc));
      await tester.pumpAndSettle();
      expect(find.byType(ClueBar), findsOneWidget);
      final selected = model.selected;
      expect(selected, isNotNull);
      expect(puzzle.wordsAt(tr, tc), contains(selected),
          reason: '탭한 셀을 지나는 단어 중 하나가 선택돼야 한다 (04-03 선택 규칙)');

      // 3. 입력
      final answer = selected!.cells
          .map((c) => puzzle.cellAt(c.$1, c.$2).solution!)
          .join();
      await tester.enterText(find.byType(TextField), answer);
      await tester.pumpAndSettle();
      for (final (r, c) in selected.cells) {
        expect(model.answers[(r, c)], puzzle.cellAt(r, c).solution);
      }

      // 4. 제출 → 다이얼로그 → 확인
      await tester.tap(find.text('제출'));
      await tester.pumpAndSettle();
      expect(find.textContaining('빈 칸'), findsOneWidget,
          reason: '레벨 1은 최소 4단어(코어 2 + 채움 2 이상)라 한 단어만 채워선 '
              '빈 칸이 남는다');
      await tester.tap(find.text('제출').last);
      await tester.pumpAndSettle();

      // 5. 결과 화면
      expect(find.byType(ResultPage), findsOneWidget);

      // 6. 다음 레벨
      await tester.tap(find.text('다음 레벨'));
      await tester.pumpAndSettle();
      expect(find.byType(ResultPage), findsNothing);
      expect(find.byType(PuzzlePage), findsOneWidget);
      expect(find.text(levels[1].name), findsOneWidget,
          reason: '다음 레벨(id+1) 화면으로 전환');
    }, timeout: const Timeout(Duration(minutes: 2)));

    testWidgets('2. 격자 탭 → 올바른 단어 선택: 힌트 패널이 그 단어',
        (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(
          wrapApp(buildScope(db), PuzzlePage(spec: levels.first, seed: 1000)));
      await tester.pumpAndSettle();

      final model = Provider.of<PuzzleModel>(
          tester.element(find.byType(PuzzleGridView)),
          listen: false);
      final puzzle = model.puzzle!;
      final target = puzzle.words.first;
      final (r, c) = target.cells.first;

      await tester.tapAt(cellCenter(tester, puzzle, r, c));
      await tester.pumpAndSettle();

      final selected = model.selected;
      expect(selected, isNotNull);
      expect(puzzle.wordsAt(r, c), contains(selected));

      final panel = tester.widget<ClueBar>(find.byType(ClueBar));
      expect(panel.selected, same(selected),
          reason: '힌트 패널이 탭으로 선택된 단어를 그대로 받아야 한다');
      expect(panel.hintText, model.hintTextFor(selected!, HintMode.definition));
    });

    testWidgets('3. 입력 → 셀 반영: 격자에 글자', (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(
          wrapApp(buildScope(db), PuzzlePage(spec: levels.first, seed: 1000)));
      await tester.pumpAndSettle();

      final model = Provider.of<PuzzleModel>(
          tester.element(find.byType(PuzzleGridView)),
          listen: false);
      final puzzle = model.puzzle!;
      final word = puzzle.words.first;
      final (r0, c0) = word.cells.first;

      await tester.tapAt(cellCenter(tester, puzzle, r0, c0));
      await tester.pumpAndSettle();
      final selected = model.selected!;

      final answer = selected.cells
          .map((c) => puzzle.cellAt(c.$1, c.$2).solution!)
          .join();
      await tester.enterText(find.byType(TextField), answer);
      await tester.pumpAndSettle();

      // grid_view_test.dart(04-02) 주석대로 위젯 테스트로 그려진 글자(픽셀)를
      // 직접 검증하긴 어렵다 — `PuzzleGridView`가 그대로 받아 `GridPainter`에
      // 넘기는 `model.answers`로 "격자에 글자"가 반영됐음을 확인한다.
      for (final (r, c) in selected.cells) {
        expect(model.answers[(r, c)], puzzle.cellAt(r, c).solution);
      }
      final gridView = tester.widget<PuzzleGridView>(find.byType(PuzzleGridView));
      expect(gridView.answers, same(model.answers));
    });

    testWidgets('4. 제출 → 결과 화면: 진입', (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(
          wrapApp(buildScope(db), PuzzlePage(spec: levels.first, seed: 1000)));
      await tester.pumpAndSettle();

      final model = Provider.of<PuzzleModel>(
          tester.element(find.byType(PuzzleGridView)),
          listen: false);
      // Scorer.solutionOf(01-08 "테스트·디버그용")로 전부 정답 채움 — 빈 칸
      // 문구가 아니라 "결과 화면 진입" 자체를 보는 테스트라 빈 칸을 남기지
      // 않는다.
      model.answers = Scorer.solutionOf(model.puzzle!);
      model.notifyListeners();
      await tester.pump();

      await tester.tap(find.text('제출'));
      await tester.pumpAndSettle();
      expect(find.text('모든 칸을 채웠습니다.'), findsOneWidget);

      await tester.tap(find.text('제출').last);
      await tester.pumpAndSettle();

      expect(find.byType(ResultPage), findsOneWidget);
    });

    testWidgets('5. 다시 풀기: 같은 퍼즐, 입력 초기화', (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(
          wrapApp(buildScope(db), PuzzlePage(spec: levels.first, seed: 1000)));
      await tester.pumpAndSettle();

      final model = Provider.of<PuzzleModel>(
          tester.element(find.byType(PuzzleGridView)),
          listen: false);
      final puzzleBefore = model.puzzle;
      model.answers = Scorer.solutionOf(model.puzzle!);
      model.notifyListeners();
      await tester.pump();

      await tester.tap(find.text('제출'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('제출').last);
      await tester.pumpAndSettle();
      expect(find.byType(ResultPage), findsOneWidget);

      await tester.tap(find.text('다시 풀기'));
      await tester.pumpAndSettle();

      expect(find.byType(ResultPage), findsNothing);
      expect(find.byType(PuzzleGridView), findsOneWidget);
      expect(model.answers, isEmpty);
      expect(model.submitted, isFalse);
      expect(identical(model.puzzle, puzzleBefore), isTrue,
          reason: '같은 seed·같은 퍼즐이라 재생성하지 않는다 (04-05 retry)');
    });

    testWidgets('6. 잠긴 레벨: 진입 불가', (tester) async {
      final db = openEmptyDb(); // 통계 없음 → 레벨 1만 해제
      addTearDown(db.close);

      await tester.pumpWidget(wrapApp(buildScope(db), const HomePage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text(levels[1].name)); // 레벨 2, 아직 잠김
      await tester.pump(); // 스낵바 등장 프레임만 먼저 확인

      expect(find.byType(PuzzlePage), findsNothing);
      expect(find.textContaining('클리어해야'), findsOneWidget);

      // 스낵바 자동 닫힘 타이머를 여기서 흘려보낸다 (home_settings_test.dart
      // 와 같은 이유 — 다음 테스트의 pumpAndSettle이 엉뚱하게 걸리지 않도록).
      await tester.pumpAndSettle();
    });

    testWidgets('7. 설정 → 라이선스: 4개 자료명 표시', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(wrapApp(buildScope(db), const SettingsPage()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('출처 및 라이선스'));
      await tester.pumpAndSettle();

      expect(find.byType(LicenseNoticePage), findsOneWidget);
      expect(find.textContaining('한국어기초사전'), findsOneWidget);
      expect(find.textContaining('표준국어대사전'), findsOneWidget);
      expect(find.textContaining('현대 국어 사용 빈도 조사 2'), findsOneWidget);
      expect(find.textContaining('한국어 학습용 어휘 목록'), findsOneWidget);
    });

    testWidgets('8. 힌트 모드 전환: 힌트 텍스트 변화', (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);
      // selection_test.dart(04-03) "힌트 선택" 그룹과 같은 값. 여기서는
      // `PuzzleModel.hintTextFor`(모델 로직)가 아니라 그 값을 받은
      // `ClueBar`(표시 전용 위젯)가 실제로 다른
      // 텍스트를 그리는지를 본다.
      final model = PuzzleModel(buildScope(db), levels.first);
      model.hints = {
        '나무': const Hint('줄기가 목질로 된 식물.', ['수목', '목본']),
      };
      const word = PlacedWord(
        headword: '나무',
        row: 0,
        col: 0,
        dir: Direction.across,
        isCore: false,
        tier: 1,
      );

      Widget wrapHint(HintMode mode) => MaterialApp(
            theme: buildLightTheme(), // ClueBar가 GameColors.of(context)를 읽는다
            home: Scaffold(
              body: ClueBar(
                selected: word,
                number: 1,
                hintText: model.hintTextFor(word, mode),
                onPrev: () {},
                onNext: () {},
                child: const SizedBox.shrink(),
              ),
            ),
          );

      await tester.pumpWidget(wrapHint(HintMode.definition));
      expect(find.text('줄기가 목질로 된 식물.'), findsOneWidget);

      await tester.pumpWidget(wrapHint(HintMode.association));
      expect(find.text('수목, 목본'), findsOneWidget);
      expect(find.text('줄기가 목질로 된 식물.'), findsNothing);
    });

    testWidgets('9. 생성 실패: GenerationFailed → 에러 화면, 크래시 없음',
        (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);

      // shell_test.dart(04-01)의 `_impossibleSpec()`과 같은 근거: 3×3 격자에
      // 코어 5개는 성긴 격자 규칙(01-03)상 들어갈 수 없다.
      const impossible = LevelSpec(
        id: 9,
        name: 'impossible',
        width: 3,
        height: 3,
        coreTier: 3,
        coreCount: 5,
        fillQuotas: [TierQuota(1, 2, 4), TierQuota(2, 1, 3)],
        maxAttempts: 5,
      );

      await tester.pumpWidget(
          wrapApp(buildScope(db), const PuzzlePage(spec: impossible, seed: 1)));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '크래시 없음');
      expect(find.byType(PuzzleGridView), findsNothing);
      expect(find.textContaining('퍼즐을 만들지 못했습니다'), findsOneWidget);
    });
  });
}
