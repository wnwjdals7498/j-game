import 'package:test/test.dart';

import 'package:jgame/domain/fixtures/dummy_dictionary.dart';

void main() {
  final repo = InMemoryWordRepository(buildDummyDictionary(seed: 1));

  test('findByPattern이 고정 자리를 지킨다', () async {
    final r = await repo.findByPattern(length: 3, fixed: {1: '가'});
    expect(r, isNotEmpty);
    for (final w in r) {
      expect(w.length, 3);
      expect(w.syllableAt(1), '가');
    }
  });

  test('findByPattern이 티어·제외를 지킨다', () async {
    final r = await repo.findByPattern(
        length: 2, tiers: {1, 2}, exclude: {'가나'}, limit: 10);
    expect(r.length, lessThanOrEqualTo(10));
    for (final w in r) {
      expect(w.tier, anyOf(1, 2));
      expect(w.headword, isNot('가나'));
    }
  });

  test('findByPattern은 같은 인자에 같은 순서를 낸다', () async {
    final a = await repo.findByPattern(length: 3, tiers: {2});
    final b = await repo.findByPattern(length: 3, tiers: {2});
    expect(a.map((w) => w.headword).toList(),
        b.map((w) => w.headword).toList());
  });

  test('coreCandidates는 통계 낮은 순', () async {
    final dict = buildDummyDictionary(seed: 1);
    // 특정 단어에 높은 점수 부여 (tier 3 중 사전순 앞의 3개)
    final penalized = (dict.where((w) => w.tier == 3).toList()
          ..sort((a, b) => a.headword.compareTo(b.headword)))
        .take(3)
        .map((w) => w.headword)
        .toSet();
    final r = InMemoryWordRepository(
      dict,
      stats: {for (final hw in penalized) hw: 10},
    );
    final c = await r.coreCandidates(tier: 3, count: 5, seed: 42);
    expect(c.length, greaterThanOrEqualTo(5));
    expect(c.every((w) => w.tier == 3), isTrue);
    // 점수 높게 준 단어가 앞쪽에 없는지 확인
    expect(c.map((w) => w.headword).any(penalized.contains), isFalse);
  });

  test('coreCandidates는 같은 seed에 같은 결과', () async {
    final a = await repo.coreCandidates(tier: 3, count: 5, seed: 7);
    final b = await repo.coreCandidates(tier: 3, count: 5, seed: 7);
    expect(a.map((w) => w.headword).toList(),
        b.map((w) => w.headword).toList());
  });

  test('더미 사전이 seed 고정 시 재현된다', () {
    final a = buildDummyDictionary(seed: 1);
    final b = buildDummyDictionary(seed: 1);
    expect(a.map((w) => w.headword).toList(),
        b.map((w) => w.headword).toList());
  });

  test('더미 사전 티어 분포가 피라미드', () {
    final d = buildDummyDictionary(seed: 1, target: 4000);
    final counts = List.filled(8, 0);
    for (final w in d) {
      counts[w.tier]++;
    }
    for (var t = 1; t < 7; t++) {
      expect(counts[t], greaterThan(counts[t + 1]),
          reason: 'tier $t should be more common than ${t + 1}');
    }
  });
}
