import 'package:test/test.dart';

// import 경로는 pubspec의 name(jgame) 기준: package:jgame/domain/model/...
import 'package:jgame/domain/model/puzzle.dart';
import 'package:jgame/domain/model/submit_result.dart';
import 'package:jgame/domain/model/word_entry.dart';

void main() {
  test('WordEntry가 음절로 쪼개진다', () {
    final w = WordEntry(headword: '사과나무', tier: 3, pos: '명사');
    expect(w.length, 4);
    expect(w.syllables, ['사', '과', '나', '무']);
    expect(w.syllableAt(2), '나');
  });

  test('WordEntry 동등성은 표제어 기준', () {
    final a = WordEntry(headword: '사과', tier: 1, pos: '명사');
    final b = WordEntry(headword: '사과', tier: 7, pos: '명사');
    expect(a, b);
    expect({a, b}.length, 1);
  });

  test('PlacedWord.cells가 방향대로 좌표를 낸다', () {
    const w = PlacedWord(
      headword: '사과',
      row: 2,
      col: 3,
      dir: Direction.across,
      isCore: true,
      tier: 2,
    );
    expect(w.cells.toList(), [(2, 3), (2, 4)]);

    const d = PlacedWord(
      headword: '사과',
      row: 2,
      col: 3,
      dir: Direction.down,
      isCore: true,
      tier: 2,
    );
    expect(d.cells.toList(), [(2, 3), (3, 3)]);
  });

  test('SubmitResult 점수: 맞으면 +1, 틀리거나 비면 -1', () {
    const w = PlacedWord(
      headword: '사과',
      row: 0,
      col: 0,
      dir: Direction.across,
      isCore: false,
      tier: 1,
    );
    final r = SubmitResult([
      const WordResult(w, '사과', WordOutcome.correct),
      const WordResult(w, '사자', WordOutcome.wrong),
      const WordResult(w, '사 ', WordOutcome.blank),
    ], isFirstSubmit: true);

    expect(r.correctCount, 1);
    expect(r.wrongCount, 2);
    expect(r.score, -1);
  });
}
