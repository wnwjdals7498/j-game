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
}) =>
    GridPainter(
      puzzle: puzzle,
      answers: answers,
      selected: selected,
      focusedCell: focusedCell,
      result: result,
      colors: GameColors.light,
      cell: 40,
    );

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
}
