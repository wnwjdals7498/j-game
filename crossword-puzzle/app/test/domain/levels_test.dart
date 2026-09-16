import 'package:test/test.dart';

import 'package:jgame/domain/generator/grid_generator.dart';
import 'package:jgame/domain/levels.dart';

import 'fixtures/dummy_dictionary.dart';

void main() {
  test('id가 1..N 연속·유일', () {
    expect(levels.map((l) => l.id).toList(),
        List.generate(levels.length, (i) => i + 1));
    expect(levels.map((l) => l.id).toSet().length, levels.length);
  });

  test('격자 크기 상한 8×8', () {
    for (final l in levels) {
      expect(l.width, lessThanOrEqualTo(8), reason: 'level ${l.id}');
      expect(l.height, lessThanOrEqualTo(8), reason: 'level ${l.id}');
    }
  });

  test('코어 티어 단조 비감소', () {
    for (var i = 0; i + 1 < levels.length; i++) {
      expect(levels[i].coreTier, lessThanOrEqualTo(levels[i + 1].coreTier),
          reason: 'level ${levels[i].id} → ${levels[i + 1].id}');
    }
  });

  test('채움 티어 < 코어 티어', () {
    for (final l in levels) {
      for (final q in l.fillQuotas) {
        expect(q.tier, lessThan(l.coreTier), reason: 'level ${l.id}');
      }
    }
  });

  test('할당량 유효: 0 <= min <= max', () {
    for (final l in levels) {
      for (final q in l.fillQuotas) {
        expect(q.min, greaterThanOrEqualTo(0), reason: 'level ${l.id}');
        expect(q.min, lessThanOrEqualTo(q.max), reason: 'level ${l.id}');
      }
    }
  });

  test('단어가 격자에 들어감 (느슨한 sanity)', () {
    for (final l in levels) {
      expect(l.minWordCount * 2, lessThanOrEqualTo(l.width * l.height),
          reason: 'level ${l.id}');
    }
  });

  test('levelById 동작', () {
    for (final l in levels) {
      expect(levelById(l.id).name, l.name);
    }
    expect(() => levelById(0), throwsStateError);
    expect(() => levelById(levels.length + 1), throwsStateError);
  });

  test('더미 사전으로 전 레벨이 생성된다', () async {
    final gen = GridGenerator(
        InMemoryWordRepository(buildDummyDictionary(seed: 1)));
    for (final spec in levels) {
      for (var s = 1; s <= 20; s++) {
        final o = await gen.tryGenerate(spec, s * 1000);
        expect(o.puzzle, isNotNull,
            reason: 'level ${spec.id} seed ${s * 1000}: ${o.stats.failReason}');
      }
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
