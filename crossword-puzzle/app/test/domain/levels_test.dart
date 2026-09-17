import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:test/test.dart';

import 'package:jgame/data/db/app_database.dart';
import 'package:jgame/data/drift_word_repository.dart';
import 'package:jgame/domain/generator/grid_generator.dart';
import 'package:jgame/domain/levels.dart';

import 'package:jgame/domain/fixtures/dummy_dictionary.dart';

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

  group('실 DB로 전 레벨이 생성된다 (03-06 DoD)', () {
    // word_repository_test.dart(03-03)와 같은 이유로 assets 원본을 직접 열지
    // 않고 임시 복사본을 연다(word_stat 오염 방지, 03-05 "막히면").
    late Directory tmp;
    late AppDatabase db;
    late DriftWordRepository repo;
    late bool isFixture;

    setUpAll(() async {
      tmp = Directory.systemTemp.createTempSync('levels_test_');
      final target = File('${tmp.path}/words.sqlite');
      await target.writeAsBytes(
        await File('assets/words.sqlite').readAsBytes(),
        flush: true,
      );
      db = AppDatabase(NativeDatabase(target));
      repo = DriftWordRepository(db);

      isFixture = false;
      final raw = await db.metaValue('source_versions');
      if (raw != null) {
        try {
          final parsed = jsonDecode(raw);
          isFixture = parsed is Map && parsed['origin'] == 'fixtures';
        } catch (_) {
          isFixture = false;
        }
      }
    });

    tearDownAll(() async {
      await db.close();
      tmp.deleteSync(recursive: true);
    });

    // 1000 seed/레벨 정밀 측정은 `dart run tool/measure_real.dart` 가 맡는다
    // (docs/reports/03-real-failure.md). 여기서는 CI 회귀 감지용으로 레벨당
    // 30 seed만 도는 빠른 하드 검증이다 — 03-06 확정 스펙은 전 레벨 실패율이
    // 1% 미만이라 30번 중 1번이라도 실패하면 회귀로 본다.
    test('전 레벨 × 30 seed 전부 성공', () async {
      final gen = GridGenerator(repo);
      for (final spec in levels) {
        for (var s = 1; s <= 30; s++) {
          final seed = 1 + (s - 1) * 100;
          final o = await gen.tryGenerate(spec, seed);
          if (isFixture) {
            // 00-01 승인 대기 중 fixtures 샘플(16단어)이면 통계적으로 의미가
            // 없다 (word_repository_test.dart와 같은 판단). 하드 검증은
            // origin=raw(실데이터)일 때만 한다.
            continue;
          }
          expect(o.puzzle, isNotNull,
              reason: 'level ${spec.id} seed $seed: ${o.stats.failReason}');
        }
      }
      if (isFixture) {
        markTestSkipped('origin=fixtures — 00-01 승인 대기 중 샘플이라 하드 '
            '검증 생략 (docs/reports/03-real-failure.md 참고)');
      }
    }, timeout: const Timeout(Duration(minutes: 3)));
  });
}
