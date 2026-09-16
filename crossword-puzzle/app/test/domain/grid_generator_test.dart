import 'package:test/test.dart';

import 'package:jgame/domain/generator/grid.dart';
import 'package:jgame/domain/generator/grid_generator.dart';
import 'package:jgame/domain/generator/grid_rules.dart';
import 'package:jgame/domain/model/level_spec.dart';
import 'package:jgame/domain/model/puzzle.dart';

import 'package:jgame/domain/fixtures/dummy_dictionary.dart';

/// 생성기 전체를 도는 스펙. `levels.dart` 는 01-09 산출물이라 아직 없으므로
/// 01-04·01-06 테스트와 같이 여기서 만든다(더미 사전 7×7 기준).
LevelSpec testSpec({
  int id = 1,
  int width = 7,
  int height = 7,
  int coreTier = 3,
  int coreCount = 2,
  List<TierQuota> fillQuotas = const [TierQuota(1, 2, 4), TierQuota(2, 1, 3)],
  int maxAttempts = 20,
}) =>
    LevelSpec(
      id: id,
      name: 'test',
      width: width,
      height: height,
      coreTier: coreTier,
      coreCount: coreCount,
      fillQuotas: fillQuotas,
      maxAttempts: maxAttempts,
    );

/// 퍼즐 1개를 문자열 하나로 굳힌 값. 결정성 비교의 기준이다.
String fingerprint(Puzzle p) {
  final grid = p.cells
      .map((row) => row.map((c) => c.solution ?? '.').join())
      .join('/');
  final words = (p.words
          .map((w) => '${w.headword}@${w.row},${w.col},${w.dir.name},${w.isCore}')
          .toList()
        ..sort())
      .join('|');
  return '$grid#$words';
}

/// [GridRules.validate] 는 [MutableGrid] 를 받는다. 완성된 [Puzzle] 을 검증하려면
/// 단어 목록만으로 격자를 되돌린 뒤, 그 격자가 `puzzle.cells` 와 같은지 본다.
/// (같지 않다면 단어와 셀이 어긋난 것이므로 그 자체가 실패다.)
MutableGrid regrid(Puzzle p) {
  final g = MutableGrid(p.width, p.height);
  for (final w in p.words) {
    g.place(w);
  }
  for (var r = 0; r < p.height; r++) {
    for (var c = 0; c < p.width; c++) {
      expect(g.at(r, c), p.cellAt(r, c).solution, reason: 'cell $r,$c');
    }
  }
  return g;
}

void main() {
  final repo = InMemoryWordRepository(buildDummyDictionary(seed: 1));
  final gen = GridGenerator(repo);
  final spec = testSpec();

  /// 3×3에 코어 5개는 규칙상 불가능하다(성긴 격자에 2~5음절 단어 5개가 안 들어감).
  final impossible = testSpec(id: 9, width: 3, height: 3, coreCount: 5);

  test('기본 생성 성공', () async {
    final p = await gen.generate(spec, 7);

    expect(p.levelId, spec.id);
    expect(p.width, spec.width);
    expect(p.height, spec.height);
    expect(p.words.length, greaterThanOrEqualTo(spec.minWordCount));
    expect(p.attempts, greaterThanOrEqualTo(1));
  });

  test('같은 seed면 완전히 같은 퍼즐', () async {
    final a = await gen.generate(spec, 7);
    final b = await gen.generate(spec, 7);

    expect(fingerprint(a), fingerprint(b));
    expect(a.seed, b.seed);
    expect(a.attempts, b.attempts);
  });

  test('seed가 다르면 결과가 다르다 (10개 중 8개 이상)', () async {
    final prints = <String>{};
    for (var i = 0; i < 10; i++) {
      // seed 간격을 벌린다. attemptSeed = seed + attempt - 1 이라 연속 seed는
      // 재시도 시 서로 같은 attemptSeed를 밟아 같은 퍼즐이 나올 수 있다.
      prints.add(fingerprint(await gen.generate(spec, 1 + i * 100)));
    }

    expect(prints.length, greaterThanOrEqualTo(8));
  });

  test('생성된 모든 퍼즐이 validate를 통과한다', () async {
    for (var i = 0; i < 10; i++) {
      final p = await gen.generate(spec, 1 + i * 100);
      expect(
        GridRules.validate(regrid(p), allowIsolated: spec.allowIsolated),
        isEmpty,
        reason: 'seed ${1 + i * 100}',
      );
    }
  });

  test('코어 개수가 spec.coreCount와 같다', () async {
    for (var i = 0; i < 5; i++) {
      final p = await gen.generate(spec, 1 + i * 100);
      expect(p.cores.length, spec.coreCount, reason: 'seed ${1 + i * 100}');
    }
  });

  test('모든 코어가 spec.coreTier다', () async {
    for (var i = 0; i < 5; i++) {
      final p = await gen.generate(spec, 1 + i * 100);
      for (final w in p.cores) {
        expect(w.tier, spec.coreTier, reason: w.headword);
      }
    }
  });

  test('채움 할당량: 티어별 개수가 [min, max] 안', () async {
    for (var i = 0; i < 5; i++) {
      final seed = 1 + i * 100;
      final p = await gen.generate(spec, seed);
      final fills = p.words.where((w) => !w.isCore);
      for (final q in spec.fillQuotas) {
        final n = fills.where((w) => w.tier == q.tier).length;
        expect(n, greaterThanOrEqualTo(q.min), reason: 'seed $seed t${q.tier}');
        expect(n, lessThanOrEqualTo(q.max), reason: 'seed $seed t${q.tier}');
      }
      // 할당량 밖 티어는 채움으로 들어가지 않는다.
      final quotaTiers = spec.fillQuotas.map((q) => q.tier).toSet();
      for (final w in fills) {
        expect(quotaTiers.contains(w.tier), isTrue, reason: w.headword);
      }
    }
  });

  test('Puzzle.seed로 재생성하면 같은 퍼즐', () async {
    final p = await gen.generate(spec, 3);
    final again = await gen.generate(spec, p.seed);

    expect(fingerprint(again), fingerprint(p));
    expect(again.attempts, 1); // p.seed는 성공한 시도의 seed다
  });

  test('불가능한 스펙이면 GenerationFailed', () async {
    await expectLater(
      gen.generate(impossible, 1),
      throwsA(isA<GenerationFailed>()
          .having((e) => e.levelId, 'levelId', impossible.id)
          .having((e) => e.attempts, 'attempts', impossible.maxAttempts)
          .having((e) => e.reason, 'reason', isNotEmpty)),
    );
  });

  test('tryGenerate는 예외를 던지지 않는다', () async {
    final o = await gen.tryGenerate(impossible, 1);

    expect(o.puzzle, isNull);
    expect(o.stats.success, isFalse);
    expect(o.stats.attempts, impossible.maxAttempts);
    expect(o.stats.failReason, isNotNull);
    expect(o.stats.totalBacktracks, greaterThanOrEqualTo(0));
    expect(o.stats.totalQueries, greaterThanOrEqualTo(0));
    expect(o.stats.elapsed, greaterThanOrEqualTo(Duration.zero));
  });

  test('wordsAt: 교차 셀에서 단어 2개', () async {
    final p = await gen.generate(spec, 7);

    final owners = <(int, int), int>{};
    for (final w in p.words) {
      for (final cell in w.cells) {
        owners[cell] = (owners[cell] ?? 0) + 1;
      }
    }
    final cross = owners.entries.where((e) => e.value == 2).toList();

    expect(cross, isNotEmpty, reason: '교차가 하나도 없는 격자면 코어 배치가 잘못된 것');
    for (final e in cross) {
      final ws = p.wordsAt(e.key.$1, e.key.$2);
      expect(ws.length, 2, reason: '${e.key}');
      expect(ws.map((w) => w.dir).toSet().length, 2, reason: '${e.key}');
    }
    // 빈 칸을 지나는 단어는 없다.
    for (var r = 0; r < p.height; r++) {
      for (var c = 0; c < p.width; c++) {
        if (p.cellAt(r, c).blocked) {
          expect(p.wordsAt(r, c), isEmpty, reason: '$r,$c');
        }
      }
    }
  });
}
