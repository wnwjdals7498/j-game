import 'package:test/test.dart';

import 'package:jgame/domain/generator/grid_generator.dart';
import 'package:jgame/domain/model/level_spec.dart';
import 'package:jgame/domain/model/puzzle.dart';
import 'package:jgame/domain/model/submit_result.dart';
import 'package:jgame/domain/scoring/scorer.dart';

import 'fixtures/dummy_dictionary.dart';

/// 채점 대상 퍼즐을 뽑는 스펙. `levels.dart` 는 01-09 산출물이라 아직 없으므로
/// 01-04·01-06·01-07 테스트와 같이 여기서 만든다(더미 사전 7×7 기준).
LevelSpec testSpec() => LevelSpec(
      id: 1,
      name: 'test',
      width: 7,
      height: 7,
      coreTier: 3,
      coreCount: 2,
      fillQuotas: const [TierQuota(1, 2, 4), TierQuota(2, 1, 3)],
      maxAttempts: 20,
    );

/// 01-08 "막히면": 같은 표제어가 두 번 나올 일은 없지만(01-03 규칙 6),
/// 결과를 찾을 때는 headword 대신 위치+방향으로 찾는 쪽이 안전하다.
WordResult resultOf(SubmitResult res, PlacedWord w) =>
    res.results.firstWhere((x) =>
        x.word.row == w.row && x.word.col == w.col && x.word.dir == w.dir);

/// (r, c) → 그 셀을 지나는 단어 수.
Map<(int, int), int> ownerCounts(Puzzle p) {
  final owners = <(int, int), int>{};
  for (final w in p.words) {
    for (final cell in w.cells) {
      owners[cell] = (owners[cell] ?? 0) + 1;
    }
  }
  return owners;
}

void main() {
  final gen = GridGenerator(InMemoryWordRepository(buildDummyDictionary(seed: 1)));
  final spec = testSpec();
  late Puzzle p;

  setUpAll(() async {
    p = await gen.generate(spec, 7);
  });

  test('전부 정답이면 모든 단어가 correct', () {
    // solutionOf 를 쓰지 않고 단어에서 직접 채운다(solutionOf 검증과 분리).
    final a = <(int, int), String>{};
    for (final w in p.words) {
      var i = 0;
      for (final (r, c) in w.cells) {
        a[(r, c)] = w.syllableAt(i++);
      }
    }

    final res = Scorer.score(p, a, isFirstSubmit: true);

    expect(res.results.length, p.words.length);
    for (final r in res.results) {
      expect(r.outcome, WordOutcome.correct, reason: r.word.headword);
    }
    expect(res.correctCount, p.words.length);
    expect(res.score, p.words.length);
  });

  test('전부 빈칸이면 모든 단어가 blank, 점수는 -단어수', () {
    final res = Scorer.score(p, {}, isFirstSubmit: true);

    for (final r in res.results) {
      expect(r.outcome, WordOutcome.blank, reason: r.word.headword);
      expect(r.entered, ' ' * r.word.length);
    }
    expect(res.correctCount, 0);
    expect(res.score, -p.words.length);
  });

  test('한 칸 틀리면 그 칸을 지나는 단어만 wrong', () {
    // 교차가 아닌 셀(단어 1개만 지남)을 고른다.
    final single =
        ownerCounts(p).entries.firstWhere((e) => e.value == 1).key;

    final a = Scorer.solutionOf(p);
    a[single] = '뷁'; // 더미 사전 음절 풀에 없는 글자

    final res = Scorer.score(p, a, isFirstSubmit: true);
    final affected = p.wordsAt(single.$1, single.$2);

    expect(affected.length, 1);
    expect(resultOf(res, affected.first).outcome, WordOutcome.wrong);
    expect(res.wrongCount, 1);
    expect(res.correctCount, p.words.length - 1);
  });

  test('교차 셀이 틀리면 두 단어 모두 오답', () {
    final cross = ownerCounts(p).entries.firstWhere((e) => e.value == 2).key;

    final a = Scorer.solutionOf(p);
    a[cross] = '뷁';

    final res = Scorer.score(p, a, isFirstSubmit: true);
    final affected = p.wordsAt(cross.$1, cross.$2);

    expect(affected.length, 2);
    for (final w in affected) {
      expect(resultOf(res, w).outcome, WordOutcome.wrong, reason: w.headword);
    }
    expect(res.wrongCount, greaterThanOrEqualTo(2));
  });

  test('한 칸 비우면 그 단어는 blank (wrong 아님)', () {
    final w = p.words.first;
    final target = w.cells.first;

    final a = Scorer.solutionOf(p);
    a.remove(target);

    final res = Scorer.score(p, a, isFirstSubmit: true);

    for (final owner in p.wordsAt(target.$1, target.$2)) {
      final r = resultOf(res, owner);
      expect(r.outcome, WordOutcome.blank, reason: owner.headword);
      expect(r.entered, contains(' '));
    }
    // 빈칸도 오답으로 센다.
    expect(res.correctCount, lessThan(p.words.length));
  });

  test('빈 문자열도 빈칸으로 본다', () {
    final w = p.words.first;
    final target = w.cells.first;

    final a = Scorer.solutionOf(p);
    a[target] = '';

    final res = Scorer.score(p, a, isFirstSubmit: true);

    expect(resultOf(res, w).outcome, WordOutcome.blank);
  });

  test('재제출해도 결과가 같다', () {
    final a = Scorer.solutionOf(p);
    a[p.words.first.cells.first] = '뷁';

    final first = Scorer.score(p, a, isFirstSubmit: true);
    final second = Scorer.score(p, a, isFirstSubmit: false);

    expect(second.results.length, first.results.length);
    for (var i = 0; i < first.results.length; i++) {
      expect(second.results[i].word.headword, first.results[i].word.headword);
      expect(second.results[i].entered, first.results[i].entered);
      expect(second.results[i].outcome, first.results[i].outcome);
    }
    expect(second.score, first.score);
  });

  test('isFirstSubmit은 넘긴 값 그대로', () {
    final a = Scorer.solutionOf(p);

    expect(Scorer.score(p, a, isFirstSubmit: true).isFirstSubmit, isTrue);
    expect(Scorer.score(p, a, isFirstSubmit: false).isFirstSubmit, isFalse);
  });

  test('blankCellCount는 검은 칸을 빼고 빈 칸만 센다', () {
    var openCells = 0;
    for (var r = 0; r < p.height; r++) {
      for (var c = 0; c < p.width; c++) {
        if (!p.cellAt(r, c).blocked) openCells++;
      }
    }
    // 성긴 격자라 검은 칸이 반드시 있다. 없으면 아래 비교가 의미를 잃는다.
    expect(openCells, lessThan(p.width * p.height));

    expect(Scorer.blankCellCount(p, {}), openCells);
    expect(Scorer.blankCellCount(p, Scorer.solutionOf(p)), 0);

    final one = Scorer.solutionOf(p)..[p.words.first.cells.first] = '';
    expect(Scorer.blankCellCount(p, one), 1);
  });

  test('solutionOf로 채우면 만점', () {
    final res = Scorer.score(p, Scorer.solutionOf(p), isFirstSubmit: true);

    expect(res.score, p.words.length);
    expect(res.total, p.words.length);
    expect(res.wrongCount, 0);
  });
}
