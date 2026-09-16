import '../generator/grid_generator.dart';
import '../model/level_spec.dart';
import '../repository/word_repository.dart';

/// 레벨 1개를 여러 seed로 돌린 측정 결과 (01-10).
///
/// **실패**(REVIEW 4.2 (f) — 01-10에서 확정) = `tryGenerate` 가 `maxAttempts` 를
/// 모두 소진하고 `puzzle == null` 을 돌려준 경우. 시간 초과는 실패가 아니고,
/// 한 seed가 30초를 넘으면 [timeouts] 로 따로 센다(무한 루프 감지용).
class LevelMeasurement {
  final LevelSpec spec;
  final int runs;
  final int failures;
  final int timeouts;
  final List<int> elapsedMicros; // 성공한 것만, 정렬됨
  final List<int> attempts;
  final List<int> backtracks;
  final List<int> queries;

  const LevelMeasurement({
    required this.spec,
    required this.runs,
    required this.failures,
    required this.timeouts,
    required this.elapsedMicros,
    required this.attempts,
    required this.backtracks,
    required this.queries,
  });

  double get failureRate => failures / runs;
  int get p50 => _pct(50);
  int get p95 => _pct(95);
  int get maxMicros => elapsedMicros.isEmpty ? 0 : elapsedMicros.last;
  double get avgAttempts =>
      attempts.isEmpty ? 0 : attempts.reduce((a, b) => a + b) / attempts.length;
  double get avgBacktracks => backtracks.isEmpty
      ? 0
      : backtracks.reduce((a, b) => a + b) / backtracks.length;
  double get avgQueries =>
      queries.isEmpty ? 0 : queries.reduce((a, b) => a + b) / queries.length;

  int _pct(int p) {
    if (elapsedMicros.isEmpty) return 0;
    final i = ((elapsedMicros.length - 1) * p / 100).round();
    return elapsedMicros[i];
  }
}

/// 실패율·생성 시간 하네스의 순수 Dart 부분.
///
/// 3단계(03-05)가 같은 클래스에 실 DB [WordRepository] 를 주입해 재사용한다.
/// 그래서 여기에 플랫폼 import·출력·파일 쓰기를 두지 않는다(진행 표시는 콜백).
class MeasureRunner {
  final WordRepository repo;
  const MeasureRunner(this.repo);

  /// [spec]을 seed [startSeed] .. 간격 100으로 [runs]회 돌린다.
  ///
  /// **seed 간격 100의 이유**: `tryGenerate(spec, s)` 는 내부에서
  /// `s, s+1, ... s+maxAttempts-1` 을 쓴다. seed를 1씩 늘리면 표본이 겹쳐
  /// 실패율이 왜곡되므로 간격을 `maxAttempts` 보다 크게 잡는다.
  ///
  /// [onProgress] 는 100회마다 호출 (진행 표시용).
  Future<LevelMeasurement> measureLevel(
    LevelSpec spec, {
    int runs = 1000,
    int startSeed = 1,
    void Function(int done, int total)? onProgress,
  }) async {
    final gen = GridGenerator(repo);
    final elapsed = <int>[];
    final attempts = <int>[];
    final backtracks = <int>[];
    final queries = <int>[];
    var failures = 0;
    var timeouts = 0;

    for (var i = 0; i < runs; i++) {
      final seed = startSeed + i * 100;
      final o = await gen.tryGenerate(spec, seed);
      if (o.stats.elapsed.inSeconds >= 30) timeouts++;
      if (o.puzzle == null) {
        failures++;
      } else {
        elapsed.add(o.stats.elapsed.inMicroseconds);
        attempts.add(o.stats.attempts);
        backtracks.add(o.stats.totalBacktracks);
        queries.add(o.stats.totalQueries);
      }
      if (onProgress != null && (i + 1) % 100 == 0) onProgress(i + 1, runs);
    }
    elapsed.sort();

    return LevelMeasurement(
      spec: spec,
      runs: runs,
      failures: failures,
      timeouts: timeouts,
      elapsedMicros: elapsed,
      attempts: attempts,
      backtracks: backtracks,
      queries: queries,
    );
  }

  Future<List<LevelMeasurement>> measureAll(
    List<LevelSpec> specs, {
    int runs = 1000,
    void Function(LevelSpec spec, int done, int total)? onProgress,
  }) async {
    final out = <LevelMeasurement>[];
    for (final spec in specs) {
      out.add(await measureLevel(
        spec,
        runs: runs,
        onProgress:
            onProgress == null ? null : (d, t) => onProgress(spec, d, t),
      ));
    }
    return out;
  }
}

/// 1단계 DoD 기준: 전 레벨 실패율 1% 미만, p95 생성 시간 200ms 미만.
const double kMaxFailureRate = 0.01;
const int kMaxP95Micros = 200 * 1000;

/// DoD를 못 채운 측정치. `tool/measure.dart` 가 이 목록으로 `exit(1)` 을 판정한다.
List<LevelMeasurement> failingMeasurements(List<LevelMeasurement> ms) => ms
    .where((m) =>
        m.failureRate >= kMaxFailureRate || m.p95 > kMaxP95Micros)
    .toList();

String _ms(int micros) => (micros / 1000).toStringAsFixed(1);

/// 측정 결과를 `docs/reports/01-dummy-failure.md` 형식의 마크다운으로 만든다.
///
/// [source] 는 사전 설명(더미/실 DB), [environment] 는 OS·dart·CPU 한 줄.
/// 03-05가 실 DB 리포트를 낼 때 두 값만 바꿔 그대로 쓴다.
String renderMarkdown(
  List<LevelMeasurement> results, {
  required int runs,
  required String source,
  String title = '01단계 더미 사전 실패율 리포트',
  String environment = '(미기록)',
  DateTime? measuredAt,
}) {
  final at = measuredAt ?? DateTime.now();
  final date = '${at.year.toString().padLeft(4, '0')}-'
      '${at.month.toString().padLeft(2, '0')}-'
      '${at.day.toString().padLeft(2, '0')}';

  final b = StringBuffer()
    ..writeln('# $title')
    ..writeln()
    ..writeln('측정일: $date')
    ..writeln('사전: $source')
    ..writeln('레벨당 시도: $runs seed (간격 100)')
    ..writeln('환경: $environment')
    ..writeln()
    ..writeln('## 요약')
    ..writeln();

  if (results.isEmpty) {
    b
      ..writeln('측정된 레벨이 없다.')
      ..writeln();
  } else {
    final worstFail =
        results.reduce((a, c) => c.failureRate > a.failureRate ? c : a);
    final worstP95 = results.reduce((a, c) => c.p95 > a.p95 ? c : a);
    final totalTimeouts = results.fold(0, (a, m) => a + m.timeouts);
    final failOk = worstFail.failureRate < kMaxFailureRate;
    final p95Ok = worstP95.p95 <= kMaxP95Micros;

    b
      ..writeln('| DoD | 기준 | 결과 |')
      ..writeln('|---|---|---|')
      ..writeln('| 실패율 | 전 레벨 < 1% | ${failOk ? '✅' : '❌'} 최대 '
          '${(worstFail.failureRate * 100).toStringAsFixed(2)}% '
          '(레벨 ${worstFail.spec.id}) |')
      ..writeln('| 생성 시간 | p95 < 200ms | ${p95Ok ? '✅' : '❌'} 최대 '
          '${_ms(worstP95.p95)}ms (레벨 ${worstP95.spec.id}) |')
      ..writeln('| timeout | 30초 초과 0건 | '
          '${totalTimeouts == 0 ? '✅' : '❌'} $totalTimeouts건 |')
      ..writeln();
  }

  b
    ..writeln('## 레벨별')
    ..writeln()
    ..writeln('| 레벨 | 격자 | 코어 | 실패율 | p50 | p95 | 최대 | '
        '평균 시도 | 평균 되감기 | 평균 질의 |')
    ..writeln('|---|---|---|---|---|---|---|---|---|---|');

  for (final m in results) {
    final s = m.spec;
    b.writeln('| ${s.id} ${s.name} '
        '| ${s.width}×${s.height} '
        '| t${s.coreTier}×${s.coreCount} '
        '| ${(m.failureRate * 100).toStringAsFixed(2)}% '
        '| ${_ms(m.p50)}ms '
        '| ${_ms(m.p95)}ms '
        '| ${_ms(m.maxMicros)}ms '
        '| ${m.avgAttempts.toStringAsFixed(2)} '
        '| ${m.avgBacktracks.toStringAsFixed(1)} '
        '| ${m.avgQueries.toStringAsFixed(1)} |');
  }

  b
    ..writeln()
    ..writeln('## 해석')
    ..writeln()
    ..writeln('(여기에 사람이 한두 줄.)');

  return b.toString();
}
