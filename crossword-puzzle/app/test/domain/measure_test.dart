import 'package:test/test.dart';

import 'package:jgame/domain/fixtures/dummy_dictionary.dart';
import 'package:jgame/domain/generator/grid_generator.dart';
import 'package:jgame/domain/levels.dart';
import 'package:jgame/domain/measure/measure_runner.dart';
import 'package:jgame/domain/model/level_spec.dart';
import 'package:jgame/domain/model/puzzle.dart';

/// 퍼즐 1개를 문자열 하나로 굳힌 값. seed 간격 검증의 기준이다.
String fingerprint(Puzzle p) {
  final grid =
      p.cells.map((row) => row.map((c) => c.solution ?? '.').join()).join('/');
  final words = (p.words
          .map((w) => '${w.headword}@${w.row},${w.col},${w.dir.name}')
          .toList()
        ..sort())
      .join('|');
  return '$grid#$words';
}

/// 백분위·렌더 테스트용. 실제 생성을 돌리지 않고 숫자만 넣는다.
LevelMeasurement fake(
  LevelSpec spec, {
  int runs = 10,
  int failures = 0,
  int timeouts = 0,
  List<int> elapsed = const [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
}) =>
    LevelMeasurement(
      spec: spec,
      runs: runs,
      failures: failures,
      timeouts: timeouts,
      elapsedMicros: elapsed,
      attempts: const [1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
      backtracks: const [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      queries: const [10, 10, 10, 10, 10, 10, 10, 10, 10, 10],
    );

void main() {
  final repo = InMemoryWordRepository(buildDummyDictionary(seed: 1));
  final runner = MeasureRunner(repo);

  /// 3×3에 코어 5개는 규칙상 불가능하다. 실패율 1.0을 만드는 스펙.
  const impossible = LevelSpec(
    id: 99,
    name: 'impossible',
    width: 3,
    height: 3,
    coreTier: 3,
    coreCount: 5,
    fillQuotas: [TierQuota(1, 1, 2)],
  );

  test('measureLevel(runs: 10)이 10회를 남김없이 분류한다', () async {
    final m = await runner.measureLevel(levels.first, runs: 10);

    expect(m.runs, 10);
    expect(m.failures + m.elapsedMicros.length, 10);
    expect(m.attempts.length, m.elapsedMicros.length);
    expect(m.backtracks.length, m.elapsedMicros.length);
    expect(m.queries.length, m.elapsedMicros.length);
    expect(m.spec.id, levels.first.id);
  });

  test('elapsedMicros가 정렬되어 돌아온다', () async {
    final m = await runner.measureLevel(levels.first, runs: 10);
    final sorted = List.of(m.elapsedMicros)..sort();

    expect(m.elapsedMicros, sorted);
  });

  test('백분위 계산: 알려진 리스트로 p50/p95', () {
    // 인덱스 = ((n - 1) * p / 100).round()
    // n=10 → p50: (9*0.5).round()=5 → 6, p95: (9*0.95).round()=9 → 10
    final m = fake(levels.first);

    expect(m.p50, 6);
    expect(m.p95, 10);
    expect(m.maxMicros, 10);
    expect(m.avgAttempts, 1.0);
    expect(m.avgBacktracks, 4.5);
    expect(m.avgQueries, 10.0);

    // 전부 실패한 레벨: 성공 표본이 없으면 모든 지표가 0이다.
    final empty = LevelMeasurement(
      spec: levels.first,
      runs: 1,
      failures: 1,
      timeouts: 0,
      elapsedMicros: const [],
      attempts: const [],
      backtracks: const [],
      queries: const [],
    );
    expect(empty.p50, 0);
    expect(empty.p95, 0);
    expect(empty.maxMicros, 0);
    expect(empty.avgAttempts, 0);
    expect(empty.avgBacktracks, 0);
    expect(empty.avgQueries, 0);
  });

  test('실패율 계산: 불가능한 스펙이면 1.0', () async {
    final m = await runner.measureLevel(impossible, runs: 5);

    expect(m.failures, 5);
    expect(m.failureRate, 1.0);
    expect(m.elapsedMicros, isEmpty);
    expect(m.timeouts, 0);
  });

  test('실패율 계산: 성공만 하면 0.0', () async {
    final m = await runner.measureLevel(levels.first, runs: 10);

    expect(m.failureRate, m.failures / 10);
    expect(m.failureRate, lessThan(1.0));
  });

  test('seed 간격 100이면 서로 다른 퍼즐이 나온다', () async {
    // measureLevel은 startSeed + i * 100 을 쓴다. tryGenerate가 내부에서
    // seed..seed+maxAttempts-1 을 밟으므로 간격이 좁으면 표본이 겹친다.
    final gen = GridGenerator(repo);
    final prints = <String>{};
    for (var i = 0; i < 20; i++) {
      final o = await gen.tryGenerate(levels.first, 1 + i * 100);
      final p = o.puzzle;
      if (p != null) prints.add(fingerprint(p));
    }

    expect(prints.length, greaterThanOrEqualTo(18));
  });

  test('measureAll이 스펙마다 하나씩 돌려준다', () async {
    final specs = levels.take(2).toList();
    final seen = <int>[];
    final ms = await runner.measureAll(specs,
        runs: 2, onProgress: (s, d, t) => seen.add(s.id));

    expect(ms.length, 2);
    expect(ms.map((m) => m.spec.id).toList(), specs.map((s) => s.id).toList());
    for (final m in ms) {
      expect(m.runs, 2);
    }
    expect(seen, isEmpty, reason: 'onProgress는 100회마다라 2회에선 안 불린다');
  });

  test('리포트 렌더: 마크다운에 모든 레벨 행이 있다', () {
    final md = renderMarkdown(
      levels.map(fake).toList(),
      runs: 1000,
      source: '더미 사전 (seed 1, 4000단어, 음절 풀 40)',
      environment: 'test',
      measuredAt: DateTime(2026, 9, 16),
    );

    expect(md, contains('# 01단계 더미 사전 실패율 리포트'));
    expect(md, contains('측정일: 2026-09-16'));
    expect(md, contains('레벨당 시도: 1000 seed (간격 100)'));
    expect(md, contains('환경: test'));
    expect(md, contains('## 요약'));
    expect(md, contains('## 레벨별'));
    expect(md, contains('## 해석'));
    for (final l in levels) {
      expect(md, contains('| ${l.id} ${l.name} | ${l.width}×${l.height} '
          '| t${l.coreTier}×${l.coreCount} |'),
          reason: 'level ${l.id} 행이 없다');
    }
  });

  test('리포트 렌더: DoD 미달이면 ❌ 로 표시된다', () {
    final ok = renderMarkdown([fake(levels.first)],
        runs: 10, source: 'x', environment: 'test');
    expect(ok, contains('| 실패율 | 전 레벨 < 1% | ✅'));
    expect(ok, contains('| 생성 시간 | p95 < 200ms | ✅'));
    expect(ok, contains('| timeout | 30초 초과 0건 | ✅ 0건 |'));

    final bad = renderMarkdown(
      [
        fake(levels.first, runs: 100, failures: 5, timeouts: 1),
        fake(levels[1], elapsed: const [300000, 300000]),
      ],
      runs: 100,
      source: 'x',
      environment: 'test',
    );
    expect(bad, contains('| 실패율 | 전 레벨 < 1% | ❌ 최대 5.00% (레벨 1) |'));
    expect(bad, contains('| 생성 시간 | p95 < 200ms | ❌ 최대 300.0ms (레벨 2) |'));
    expect(bad, contains('| timeout | 30초 초과 0건 | ❌ 1건 |'));
  });

  test('failingMeasurements가 DoD 미달만 고른다', () {
    final pass = fake(levels.first);
    final failRate = fake(levels[1], runs: 100, failures: 1);
    final slow = fake(levels[2], elapsed: const [300000, 300000]);

    expect(failingMeasurements([pass]), isEmpty);
    expect(failingMeasurements([pass, failRate, slow]).map((m) => m.spec.id),
        [levels[1].id, levels[2].id]);
  });
}
