// 04-02 격자 렌더링 테스트: "구조와 탭 변환"만 검증한다(문서 "테스트":
// "위젯 테스트로 픽셀을 검증하긴 어렵다"). 골든 테스트는 04-ui.md
// "골든 테스트는 생략(1차)"에 따라 하지 않는다.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jgame/domain/model/puzzle.dart';
import 'package:jgame/domain/model/submit_result.dart';
import 'package:jgame/ui/puzzle/grid_painter.dart';
import 'package:jgame/ui/puzzle/grid_view.dart';
import 'package:jgame/ui/theme/app_theme.dart';
import 'package:jgame/ui/theme/motion.dart';
import 'package:jgame/ui/theme/tokens.dart';

/// width×height 격자. (0,0)만 검은 칸, 나머지는 '가'로 채운 더미 정답.
/// 이 테스트는 탭 변환·구조만 보므로 실제로 풀리는 단어 배치는 필요 없다.
Puzzle _testPuzzle({int width = 5, int height = 5}) {
  final cells = List.generate(
    height,
    (r) => List.generate(width, (c) {
      if (r == 0 && c == 0) return const Cell.blocked();
      return const Cell.filled('가');
    }),
  );
  return Puzzle(
    levelId: 1,
    width: width,
    height: height,
    cells: cells,
    words: const [
      PlacedWord(
        headword: '가나다',
        row: 1,
        col: 0,
        dir: Direction.across,
        isCore: false,
        tier: 1,
      ),
    ],
    seed: 1,
    attempts: 1,
  );
}

GridPainter _painter(
  Puzzle puzzle, {
  Map<(int, int), String> answers = const {},
  PlacedWord? selected,
  (int, int)? focusedCell,
  SubmitResult? result,
  Rect? selectionRect,
  Map<(int, int), double> pop = const {},
}) =>
    GridPainter(
      puzzle: puzzle,
      answers: answers,
      selected: selected,
      focusedCell: focusedCell,
      result: result,
      colors: GameColors.light,
      cell: 40,
      selectionRect: selectionRect,
      pop: pop,
    );

/// 5×3. '가나다' 가로 (0,0)~(0,2) / '나비야' 세로 (0,1)~(2,1), isCore /
/// '다람쥐' 가로 (2,2)~(2,4). (1,0)만 검은 칸.
/// selection_test.dart의 `_crossPuzzle`과 같은 배치 — 07-03-03이 모션·코어 원
/// 검증에 쓴다(단어가 1개뿐인 `_testPuzzle()`로는 E-02·코어 원을 볼 수 없다).
Puzzle _motionPuzzle() {
  const width = 5, height = 3;
  final cells = List.generate(
    height,
    (r) => List.generate(width, (c) {
      if (r == 1 && c == 0) return const Cell.blocked();
      return const Cell.filled('가');
    }),
  );
  return Puzzle(
    levelId: 1,
    width: width,
    height: height,
    cells: cells,
    words: const [
      PlacedWord(
        headword: '가나다',
        row: 0,
        col: 0,
        dir: Direction.across,
        isCore: false,
        tier: 1,
      ),
      PlacedWord(
        headword: '나비야',
        row: 0,
        col: 1,
        dir: Direction.down,
        isCore: true,
        tier: 2,
      ),
      PlacedWord(
        headword: '다람쥐',
        row: 2,
        col: 2,
        dir: Direction.across,
        isCore: false,
        tier: 1,
      ),
    ],
    seed: 1,
    attempts: 1,
  );
}

/// 코어 원 카운트 전용 간이 Canvas. `GridPainter` 시그니처는 건드리지 않는다
/// (프로덕션 코드 추가 0줄) — `noSuchMethod`가 나머지 멤버(drawRect·
/// drawParagraph 등)를 조용히 삼킨다.
class _CountingCanvas implements Canvas {
  int circles = 0;
  @override
  void drawCircle(Offset c, double radius, Paint paint) => circles++;
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  final puzzle = _testPuzzle();

  // 기본 테스트 뷰포트는 800×600(논리 픽셀)이다. 5×5 격자 → side = min(800,
  // 600) = 600, cell = 600/5 = 120.
  const cell = 600 / 5;

  /// [PuzzleGridView]를 화면 중앙에 띄우고, 그 좌상단 기준 로컬 좌표 [local]을
  /// 탭한 뒤 콜백으로 넘어온 (row, col)을 돌려준다(미호출이면 null).
  Future<(int, int)?> tapAndCapture(WidgetTester tester, Offset local) async {
    (int, int)? tapped;
    await tester.pumpWidget(MaterialApp(
      theme: buildLightTheme(), // PuzzleGridView가 GameColors.of(context)를 읽는다
      home: Scaffold(
        body: Center(
          child: PuzzleGridView(
            puzzle: puzzle,
            answers: const {},
            selected: null,
            result: null,
            focusedCell: null,
            onCellTap: (r, c) => tapped = (r, c),
          ),
        ),
      ),
    ));

    final topLeft = tester.getTopLeft(find.byType(PuzzleGridView));
    await tester.tapAt(topLeft + local);
    await tester.pump();
    return tapped;
  }

  testWidgets('탭 → 셀 변환: (cell*2.5, cell*1.5) 탭 → (row 1, col 2)',
      (tester) async {
    final tapped =
        await tapAndCapture(tester, const Offset(cell * 2.5, cell * 1.5));
    expect(tapped, (1, 2));
  });

  testWidgets('검은 칸 탭은 무시된다 (onCellTap 미호출)', (tester) async {
    final tapped =
        await tapAndCapture(tester, const Offset(cell * 0.5, cell * 0.5));
    expect(tapped, isNull);
  });

  test('범위 밖 좌표는 셀로 바뀌지 않는다 (cellForOffset이 null)', () {
    const c = 40.0;
    expect(cellForOffset(const Offset(-1, -1), c, puzzle), isNull);
    expect(
      cellForOffset(Offset(c * puzzle.width, c * puzzle.height), c, puzzle),
      isNull,
    );
  });

  testWidgets('격자 크기: 5×5 퍼즐 → 위젯 크기가 정사각형', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildLightTheme(), // PuzzleGridView가 GameColors.of(context)를 읽는다
      home: Scaffold(
        body: Center(
          child: PuzzleGridView(
            puzzle: puzzle,
            answers: const {},
            selected: null,
            result: null,
            focusedCell: null,
            onCellTap: (_, _) {},
          ),
        ),
      ),
    ));

    final size = tester.getSize(find.byType(PuzzleGridView));
    expect(size.width, size.height);
  });

  test('shouldRepaint: 같은 입력 → false, 입력 변경 → true', () {
    final same = _painter(puzzle, answers: const {(0, 1): '가'});
    final identical = _painter(puzzle, answers: const {(0, 1): '가'});
    expect(same.shouldRepaint(identical), isFalse);

    final changed = _painter(puzzle, answers: const {(0, 1): '나'});
    expect(same.shouldRepaint(changed), isTrue);
  });

  test('선택 변경 시 repaint', () {
    final word = puzzle.words.first;
    final unselected = _painter(puzzle, selected: null);
    final selected = _painter(puzzle, selected: word);
    expect(unselected.shouldRepaint(selected), isTrue);
  });

  test('제출 결과 반영 시 repaint', () {
    final word = puzzle.words.first;
    final result = SubmitResult(
      [WordResult(word, '가나다', WordOutcome.correct)],
      isFirstSubmit: true,
    );
    final before = _painter(puzzle, result: null);
    final after = _painter(puzzle, result: result);
    expect(before.shouldRepaint(after), isTrue);
  });

  test('커서 셀 변경 시 repaint', () {
    final a = _painter(puzzle, focusedCell: (0, 1));
    final same = _painter(puzzle, focusedCell: (0, 1));
    expect(a.shouldRepaint(same), isFalse);

    final b = _painter(puzzle, focusedCell: (1, 1));
    expect(a.shouldRepaint(b), isTrue);
  });

  test('pop 변경 시 repaint: 내용 다르면 true, 같으면 false', () {
    final a = _painter(puzzle, pop: {(0, 1): 0.5});
    final b = _painter(puzzle, pop: {(0, 1): 0.9});
    expect(a.shouldRepaint(b), isTrue);

    final c = _painter(puzzle, pop: {(0, 1): 0.5});
    expect(a.shouldRepaint(c), isFalse);
  });

  test('selectionRect 변경 시 repaint', () {
    final a = _painter(puzzle, selectionRect: null);
    final b =
        _painter(puzzle, selectionRect: const Rect.fromLTWH(0, 0, 120, 40));
    expect(a.shouldRepaint(b), isTrue);
  });

  group('모션 (07-03-02 컨트롤러)', () {
    final puzzle = _motionPuzzle();

    Future<PuzzleGridViewState> mount(
      WidgetTester tester, {
      required Map<(int, int), String> answers,
      PlacedWord? selected,
      (int, int)? focusedCell,
      bool reduceMotion = false,
    }) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildLightTheme(),
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(
              body: Center(
                  child: PuzzleGridView(
            puzzle: puzzle,
            answers: answers,
            selected: selected,
            focusedCell: focusedCell,
            result: null,
            onCellTap: (_, _) {},
          ))),
        ),
      ));
      return tester.state<PuzzleGridViewState>(find.byType(PuzzleGridView));
    }

    testWidgets('E-01 팝: 빈 셀이 채워지면 시작하고 fast 뒤 끝난다', (tester) async {
      await mount(tester, answers: const {});
      final state = await mount(tester, answers: const {(0, 0): '가'});
      await tester.pump();
      expect(state.pop.containsKey((0, 0)), isTrue);
      expect(state.pop[(0, 0)]!, lessThan(1.0));

      // 정확히 duration만큼만 pump하면 AnimationController가 값은 1.0에
      // 닿아도 status가 completed로 넘어가지 않는 프레임 경계 문제가 있다
      // (07-03-03 "막히면"이 다루는 증상과 같지만 제시된 처방으로는 안 풀린다).
      // _pop이 completed 상태 리스너로 _popCells를 비우므로, 이 파일의
      // E-02/E-03(값만 읽는 getter라 이 문제가 없다)과 달리 settle까지
      // pump해야 한다 — play_loop_test.dart 등 이 저장소의 다른 통합 테스트가
      // "애니메이션이 끝나길 기다린다"에 이미 쓰는 것과 같은 방식이다.
      await tester.pumpAndSettle();
      expect(state.pop, isEmpty);
    });

    testWidgets('E-01 미발동: 지우기는 팝하지 않는다', (tester) async {
      await mount(tester, answers: const {(0, 0): '가'});
      final state = await mount(tester, answers: const {});
      await tester.pump();
      expect(state.pop, isEmpty);
    });

    testWidgets('E-02 보간 · E-03 커서 알파', (tester) async {
      final ganada = puzzle.words[0]; // '가나다'
      final nabiya = puzzle.words[1]; // '나비야'
      await mount(
        tester,
        answers: const {},
        selected: ganada,
        focusedCell: (0, 0),
      );
      final state = await mount(
        tester,
        answers: const {},
        selected: nabiya,
        focusedCell: (0, 1),
      );

      await tester.pump();
      expect(state.selectionRect, isNotNull);
      expect(state.cursorOpacity, lessThan(1.0));

      await tester.pump(GameMotion.standard.fast ~/ 2);
      final mid = state.selectionRect!;
      expect(mid.left, inExclusiveRange(0.0, 120.0));
      expect(mid.width, inExclusiveRange(120.0, 360.0));

      await tester.pump(GameMotion.standard.fast);
      expect(state.selectionRect, isNull);
      expect(state.cursorOpacity, 1.0);
    });

    testWidgets('감소 모션: 팝 없음, 커서 알파 1', (tester) async {
      await mount(
        tester,
        answers: const {},
        reduceMotion: true,
        focusedCell: (0, 0),
      );
      final state = await mount(
        tester,
        answers: const {(0, 0): '가'},
        reduceMotion: true,
        focusedCell: (0, 1),
      );
      await tester.pump();

      expect(state.pop, isEmpty);
      expect(state.cursorOpacity, 1.0);
      expect(state.selectionRect, isNull);
    });

    test('코어 원: 코어 셀 수만큼 drawCircle', () {
      final canvas = _CountingCanvas();
      final painter = GridPainter(
        puzzle: puzzle,
        answers: const {},
        selected: null,
        focusedCell: null,
        result: null,
        colors: GameColors.light,
        cell: 120,
      );
      painter.paint(canvas, const Size(600, 360));
      expect(canvas.circles, 3);
    });
  });
}
