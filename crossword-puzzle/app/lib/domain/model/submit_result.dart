import 'puzzle.dart';

enum WordOutcome {
  correct, // 전부 맞음
  wrong, // 전부 채웠으나 틀림
  blank, // 한 칸 이상 비어 있음 → 규칙상 오답 취급
}

class WordResult {
  final PlacedWord word;
  final String entered; // 유저가 넣은 음절을 이어붙인 것. 빈 칸은 ' '
  final WordOutcome outcome;

  const WordResult(this.word, this.entered, this.outcome);

  bool get isCorrect => outcome == WordOutcome.correct;
}

class SubmitResult {
  final List<WordResult> results;
  final bool isFirstSubmit; // 통계 반영 여부. 3단계 stat_repository가 판단해 넣는다

  const SubmitResult(this.results, {required this.isFirstSubmit});

  int get correctCount => results.where((r) => r.isCorrect).length;
  int get wrongCount => results.length - correctCount;

  /// 규칙: 맞으면 +1, 틀리거나 비면 -1 (DESIGN 5절 "빈칸은 오답")
  int get score => correctCount - wrongCount;

  int get total => results.length;
}
