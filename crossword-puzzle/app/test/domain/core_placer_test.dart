import 'dart:math';

import 'package:test/test.dart';

import 'package:jgame/domain/generator/core_placer.dart';
import 'package:jgame/domain/generator/grid.dart';
import 'package:jgame/domain/generator/grid_rules.dart';
import 'package:jgame/domain/model/level_spec.dart';
import 'package:jgame/domain/model/puzzle.dart';
import 'package:jgame/domain/model/word_entry.dart';

import 'fixtures/dummy_dictionary.dart';

/// 코어 배치만 보는 최소 스펙. 채움 할당량(01-06)은 이 문서 범위 밖이라 비운다.
LevelSpec testSpec({
  required int coreTier,
  required int coreCount,
  required int width,
  required int height,
  bool allowIsolated = true,
}) =>
    LevelSpec(
      id: 1,
      name: 'test',
      width: width,
      height: height,
      coreTier: coreTier,
      coreCount: coreCount,
      fillQuotas: const [],
      allowIsolated: allowIsolated,
    );

WordEntry we(String headword, {int tier = 1}) =>
    WordEntry(headword: headword, tier: tier, pos: '명사');

void main() {
  final repo = InMemoryWordRepository(buildDummyDictionary(seed: 1));

  test('코어 3개 배치 성공 (더미 사전)', () async {
    final cands = await repo.coreCandidates(tier: 3, count: 3, seed: 99);
    final spec = testSpec(coreTier: 3, coreCount: 3, width: 7, height: 7);
    final g = MutableGrid(7, 7);

    final r = CorePlacer.place(g, spec, cands, Random(99));

    expect(r, isNotNull);
    expect(g.placed.length, 3);
    expect(g.placed.every((w) => w.isCore), isTrue);
  });

  test('배치 후 GridRules.validate 통과', () async {
    final cands = await repo.coreCandidates(tier: 3, count: 3, seed: 99);
    final spec = testSpec(coreTier: 3, coreCount: 3, width: 7, height: 7);
    final g = MutableGrid(7, 7);

    expect(CorePlacer.place(g, spec, cands, Random(99)), isNotNull);
    expect(GridRules.validate(g), isEmpty);
  });

  test('코어끼리 교차한다', () async {
    final cands = await repo.coreCandidates(tier: 3, count: 3, seed: 99);
    final spec = testSpec(coreTier: 3, coreCount: 3, width: 7, height: 7);
    final g = MutableGrid(7, 7);

    expect(CorePlacer.place(g, spec, cands, Random(99)), isNotNull);
    expect(GridRules.components(g.placed).length, lessThanOrEqualTo(2));
  });

  test('고립 1개 허용: 교차 못 하는 코어는 고립 슬롯을 쓴다', () {
    // 사과-사자는 '사'로 교차한다. 무기는 공유 음절이 없어 고립 슬롯으로 들어간다.
    final cands = [we('사과'), we('사자'), we('무기')];
    final spec = testSpec(coreTier: 1, coreCount: 3, width: 7, height: 7);
    final g = MutableGrid(7, 7);

    final r = CorePlacer.place(g, spec, cands, Random(7));

    expect(r, isNotNull);
    expect(r!.isolatedUsed, isTrue);
    expect(g.placed.length, 3);
    final comps = GridRules.components(g.placed);
    expect(comps.length, lessThanOrEqualTo(2));
    expect(comps.map((c) => c.length).reduce((a, b) => a < b ? a : b), 1);
    expect(GridRules.validate(g), isEmpty);
  });

  test('고립 불허: 교차 불가능한 사전이면 null', () {
    final cands = [we('사과'), we('무기')];
    final spec = testSpec(
      coreTier: 1,
      coreCount: 2,
      width: 7,
      height: 7,
      allowIsolated: false,
    );
    final g = MutableGrid(7, 7);

    expect(CorePlacer.place(g, spec, cands, Random(7)), isNull);
  });

  test('고립 단어에 뒤 코어가 붙어 규칙 5를 깨지 않는다', () {
    // 기차는 '기'를 무기(고립 단어)와만 공유한다. 거기에 붙이면 연결 요소가
    // 2개 × 크기 2가 되어 규칙 5("2개면 한쪽은 단어 1개")가 깨진다.
    final cands = [we('사과'), we('사자'), we('무기'), we('기차')];
    final spec = testSpec(coreTier: 1, coreCount: 4, width: 7, height: 7);
    final g = MutableGrid(7, 7);

    final r = CorePlacer.place(g, spec, cands, Random(7));

    // 가드를 빼면 place가 성공을 내고 validate가
    // ['고립 요소 크기가 2 (1이어야 함)'] 를 낸다.
    expect(r, isNull); // 4개째를 합법적으로 놓을 자리가 없다
    expect(GridRules.validate(g), isEmpty); // 실패해도 격자는 규칙을 안 깬다
  });

  test('같은 seed면 같은 코어 배치', () async {
    final cands = await repo.coreCandidates(tier: 3, count: 3, seed: 99);
    final spec = testSpec(coreTier: 3, coreCount: 3, width: 7, height: 7);

    String run() {
      final g = MutableGrid(7, 7);
      CorePlacer.place(g, spec, cands, Random(99));
      return g.placed
          .map((w) => '${w.headword}@${w.row},${w.col},${w.dir.name}')
          .join('|');
    }

    expect(run(), run());
    expect(run(), isNotEmpty);
  });

  test('후보 부족: 후보 2개인데 coreCount 5면 null', () {
    final cands = [we('사과'), we('사자')];
    final spec = testSpec(coreTier: 1, coreCount: 5, width: 7, height: 7);
    final g = MutableGrid(7, 7);

    expect(CorePlacer.place(g, spec, cands, Random(1)), isNull);
  });

  test('격자 너무 작음: 3×3에 5음절 코어면 null', () {
    final cands = [we('가나다라마')];
    final spec = testSpec(coreTier: 1, coreCount: 1, width: 3, height: 3);
    final g = MutableGrid(3, 3);

    expect(CorePlacer.place(g, spec, cands, Random(1)), isNull);
  });

  test('crossingPlacements가 canPlace 통과분만 낸다', () {
    final g = MutableGrid(7, 7);
    g.place(const PlacedWord(
      headword: '사과',
      row: 3,
      col: 3,
      dir: Direction.across,
      isCore: true,
      tier: 1,
    ));
    g.place(const PlacedWord(
      headword: '사자',
      row: 3,
      col: 3,
      dir: Direction.down,
      isCore: true,
      tier: 1,
    ));

    final out = CorePlacer.crossingPlacements(g, we('과자'));

    expect(out, isNotEmpty);
    for (final p in out) {
      expect(GridRules.canPlace(g, p.headword, p.row, p.col, p.dir), isTrue);
      expect(p.headword, '과자');
      expect(p.isCore, isTrue);
    }
  });
}
