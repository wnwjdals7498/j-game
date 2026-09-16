import 'dart:math';

import 'package:test/test.dart';

import 'package:jgame/domain/generator/core_placer.dart';
import 'package:jgame/domain/generator/filler.dart';
import 'package:jgame/domain/generator/grid.dart';
import 'package:jgame/domain/generator/grid_rules.dart';
import 'package:jgame/domain/model/level_spec.dart';

import 'package:jgame/domain/fixtures/dummy_dictionary.dart';

/// 채움만 보는 스펙. 코어는 [coreGrid] 가 같은 스펙으로 먼저 깐다.
LevelSpec testSpec(List<TierQuota> fillQuotas, {int backtrackBudget = 200}) =>
    LevelSpec(
      id: 1,
      name: 'test',
      width: 7,
      height: 7,
      coreTier: 3,
      coreCount: 2,
      fillQuotas: fillQuotas,
      backtrackBudget: backtrackBudget,
    );

/// 코어만 놓인 격자. 01-07이 할 일을 테스트에서 미리 손으로 한다.
///
/// [seed] 를 테스트마다 고정하는 이유: 채움은 MRV 슬롯 **하나만** 시도하므로
/// (01-06 주의점 2) 성공 여부가 격자 모양에 크게 좌우된다. 막히는 격자는
/// 실패가 맞고 seed를 바꿔 재시작하는 건 01-07 몫이다.
Future<MutableGrid> coreGrid(
  InMemoryWordRepository repo,
  LevelSpec spec,
  int seed,
) async {
  final cands = await repo.coreCandidates(
      tier: spec.coreTier, count: spec.coreCount, seed: seed);
  final g = MutableGrid(spec.width, spec.height);
  expect(CorePlacer.place(g, spec, cands, Random(seed)), isNotNull);
  return g;
}

String dump(MutableGrid g) => g.placed
    .map((w) => '${w.headword}@${w.row},${w.col},${w.dir.name}')
    .join('|');

void main() {
  final repo = InMemoryWordRepository(buildDummyDictionary(seed: 1));

  /// 더미 사전으로 채워지는 할당량.
  final easySpec = testSpec(const [TierQuota(1, 2, 4), TierQuota(2, 1, 3)]);

  /// 못 채우는 할당량. 같은 코어 격자에 1티어 6개를 정확히 요구한다.
  final tightSpec = testSpec(const [TierQuota.exact(1, 6)]);

  /// 코어 2개가 서로 고립된 격자(공유 음절 없음 → 연결 요소 2개).
  /// 규칙 5를 채움 단계에서 지켜야 하는 격자다.
  const coreSeed = 7;

  test('기본 채움 성공', () async {
    final g = await coreGrid(repo, easySpec, coreSeed);
    final cores = g.placed.length;

    final stats = await Filler(g, easySpec, repo, Random(7)).run();

    expect(stats.success, isTrue);
    expect(g.placed.length, greaterThan(cores));
  });

  test('채움 후 GridRules.validate 통과', () async {
    // 이 격자의 코어 2개는 공유 음절이 없어 서로 고립돼 있다(연결 요소 2개).
    // 채움이 아무 쪽에나 붙으면 규칙 5("2개면 한쪽은 단어 1개")가 깨지므로
    // Filler의 고립 가드가 여기서 실제로 걸린다.
    final g = await coreGrid(repo, easySpec, coreSeed);

    final stats = await Filler(g, easySpec, repo, Random(7)).run();

    expect(stats.success, isTrue);
    expect(GridRules.components(g.placed).length, lessThanOrEqualTo(2));
    expect(GridRules.validate(g, allowIsolated: easySpec.allowIsolated),
        isEmpty);
  });

  test('할당량 준수: 티어별 배치 수가 [min, max] 안', () async {
    final g = await coreGrid(repo, easySpec, coreSeed);

    final stats = await Filler(g, easySpec, repo, Random(7)).run();

    expect(stats.success, isTrue);
    for (final q in easySpec.fillQuotas) {
      final n = g.placed.where((w) => !w.isCore && w.tier == q.tier).length;
      expect(n, greaterThanOrEqualTo(q.min), reason: 'tier ${q.tier}');
      expect(n, lessThanOrEqualTo(q.max), reason: 'tier ${q.tier}');
      expect(stats.achieved[q.tier], n, reason: 'tier ${q.tier} achieved');
    }
    // 할당량 밖 티어는 채움으로 들어가지 않는다.
    final quotaTiers = easySpec.fillQuotas.map((q) => q.tier).toSet();
    for (final w in g.placed.where((w) => !w.isCore)) {
      expect(quotaTiers.contains(w.tier), isTrue, reason: w.headword);
    }
  });

  test('채움 단어는 isCore == false', () async {
    final g = await coreGrid(repo, easySpec, coreSeed);
    final coreWords = g.placedWords;

    final stats = await Filler(g, easySpec, repo, Random(7)).run();

    expect(stats.success, isTrue);
    for (final w in g.placed) {
      expect(w.isCore, coreWords.contains(w.headword), reason: w.headword);
    }
    expect(g.placed.where((w) => !w.isCore), isNotEmpty);
  });

  test('중복 단어 없음', () async {
    final g = await coreGrid(repo, easySpec, coreSeed);

    final stats = await Filler(g, easySpec, repo, Random(7)).run();

    expect(stats.success, isTrue);
    expect(g.placedWords.length, g.placed.length);
  });

  test('결정성: 같은 seed, 같은 격자 → 같은 결과', () async {
    Future<String> run() async {
      final g = await coreGrid(repo, easySpec, coreSeed);
      final s = await Filler(g, easySpec, repo, Random(7)).run();
      return '${s.success}/${s.backtracks}/${s.queries}/${s.achieved}#${dump(g)}';
    }

    final a = await run();
    expect(a, await run());
    expect(a, startsWith('true/'));
  });

  test('예산 소진 실패: backtrackBudget이 상한으로 동작', () async {
    final poorBudget = testSpec(tightSpec.fillQuotas, backtrackBudget: 1);
    final g1 = await coreGrid(repo, poorBudget, coreSeed);
    final tight = await Filler(g1, poorBudget, repo, Random(1)).run();

    final g2 = await coreGrid(repo, tightSpec, coreSeed);
    final wide = await Filler(g2, tightSpec, repo, Random(1)).run();

    expect(tight.success, isFalse);
    expect(wide.success, isFalse);
    // 예산 1이면 첫 실패에서 바로 접힌다. 되감기 카운터는 되감아 올라오는
    // 프레임마다 1씩 늘어 예산을 재귀 깊이만큼 넘을 수 있다(알고리즘대로).
    // 요점은 자릿수가 다르다는 것.
    expect(tight.backtracks, lessThan(wide.backtracks));
    expect(tight.backtracks, lessThan(10));
  });

  test('실패해도 코어 배치는 그대로 남는다', () async {
    final g = await coreGrid(repo, tightSpec, coreSeed);
    final before = dump(g);

    final stats = await Filler(g, tightSpec, repo, Random(1)).run();

    expect(stats.success, isFalse);
    expect(dump(g), before);
    expect(g.placed.every((w) => w.isCore), isTrue);
    expect(stats.achieved.values.every((n) => n == 0), isTrue);
  });

  test('캐시 동작: queries가 backtracks보다 훨씬 작다', () async {
    final g = await coreGrid(repo, tightSpec, coreSeed);

    final stats = await Filler(g, tightSpec, repo, Random(1)).run();

    expect(stats.backtracks, greaterThan(100), reason: '되감기가 많아야 비교가 의미 있다');
    expect(stats.queries * 10, lessThan(stats.backtracks),
        reason: 'queries=${stats.queries} backtracks=${stats.backtracks}');
  });

  test('사전 부족: 5티어가 없는 사전에 5티어 할당 → 실패', () async {
    final poor = InMemoryWordRepository(
        buildDummyDictionary(seed: 1).where((w) => w.tier != 5).toList());
    final spec = testSpec(const [TierQuota.exact(5, 1)]);
    final g = await coreGrid(poor, spec, coreSeed);
    final before = dump(g);

    final stats = await Filler(g, spec, poor, Random(1)).run();

    expect(stats.success, isFalse);
    expect(stats.achieved[5], 0);
    expect(dump(g), before);
  });
}
