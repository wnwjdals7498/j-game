import '../model/puzzle.dart';
import '../model/submit_result.dart';

/// 유저 입력. 키는 (row, col), 값은 입력된 음절 1글자.
/// 비어 있는 칸은 맵에 없거나 빈 문자열.
typedef Answers = Map<(int, int), String>;

/// 단어 단위 채점 (01-08, DESIGN 5절 7번).
///
/// 규칙: 빈칸은 오답(부분 정답 없음), 교차 셀 오류는 두 단어에 모두 반영,
/// 점수는 [SubmitResult.score] 가 계산한다.
class Scorer {
  /// 규칙: 빈칸 = 오답, 부분 정답 없음.
  static SubmitResult score(
    Puzzle puzzle,
    Answers answers, {
    required bool isFirstSubmit,
  }) {
    final results = <WordResult>[];

    for (final w in puzzle.words) {
      final buf = StringBuffer();
      var hasBlank = false;
      var allMatch = true;
      var i = 0;

      for (final (r, c) in w.cells) {
        final entered = answers[(r, c)];
        final expected = w.syllableAt(i++);

        if (entered == null || entered.isEmpty) {
          hasBlank = true;
          allMatch = false;
          buf.write(' ');
        } else {
          buf.write(entered);
          if (entered != expected) allMatch = false;
        }
      }

      final outcome = hasBlank
          ? WordOutcome.blank
          : (allMatch ? WordOutcome.correct : WordOutcome.wrong);

      results.add(WordResult(w, buf.toString(), outcome));
    }

    return SubmitResult(results, isFirstSubmit: isFirstSubmit);
  }

  /// 제출 확인 다이얼로그용 (04-05). 비어 있는 칸 수.
  static int blankCellCount(Puzzle puzzle, Answers answers) {
    var n = 0;
    for (var r = 0; r < puzzle.height; r++) {
      for (var c = 0; c < puzzle.width; c++) {
        if (puzzle.cellAt(r, c).blocked) continue;
        final v = answers[(r, c)];
        if (v == null || v.isEmpty) n++;
      }
    }
    return n;
  }

  /// 정답으로 채운 Answers. 테스트·디버그용.
  static Answers solutionOf(Puzzle puzzle) {
    final a = <(int, int), String>{};
    for (var r = 0; r < puzzle.height; r++) {
      for (var c = 0; c < puzzle.width; c++) {
        final s = puzzle.cellAt(r, c).solution;
        if (s != null) a[(r, c)] = s;
      }
    }
    return a;
  }
}
