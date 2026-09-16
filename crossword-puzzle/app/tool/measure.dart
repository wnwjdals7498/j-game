import 'dart:io';

import 'package:jgame/domain/fixtures/dummy_dictionary.dart';
import 'package:jgame/domain/levels.dart';
import 'package:jgame/domain/measure/measure_runner.dart';

/// 실패율·성능 하네스 진입점 (01-10).
///
/// `tool/` 은 `lib/` 밖이라 `dart:io` 를 써도 된다. 측정 로직은
/// `lib/domain/measure/measure_runner.dart` 에 있고 3단계(03-05)가 실 DB
/// repository를 주입해 그대로 돌린다.
///
/// 사용법 (`app/` 디렉터리에서):
///   dart run tool/measure.dart                 (전 레벨 1000회)
///   dart run tool/measure.dart --runs 200      (빠른 확인)
///   dart run tool/measure.dart --level 9       (특정 레벨만)
Future<void> main(List<String> args) async {
  final runs = _intArg(args, '--runs', 1000);
  final onlyLevel = _intArg(args, '--level', 0);

  final repo = InMemoryWordRepository(buildDummyDictionary(seed: 1));
  final runner = MeasureRunner(repo);
  final specs = onlyLevel == 0
      ? levels
      : levels.where((l) => l.id == onlyLevel).toList();

  final results = <LevelMeasurement>[];
  for (final spec in specs) {
    stdout.write('level ${spec.id} ${spec.name} ');
    final m = await runner.measureLevel(spec,
        runs: runs, onProgress: (d, t) => stdout.write('.'));
    stdout.writeln(' 실패 ${(m.failureRate * 100).toStringAsFixed(2)}% '
        'p50 ${(m.p50 / 1000).toStringAsFixed(1)}ms '
        'p95 ${(m.p95 / 1000).toStringAsFixed(1)}ms');
    results.add(m);
  }

  final md = renderMarkdown(
    results,
    runs: runs,
    source: '더미 사전 (seed 1, 4000단어, 음절 풀 40)',
    environment: '${Platform.operatingSystemVersion}, '
        'dart ${Platform.version.split(' ').first}, '
        'CPU ${Platform.numberOfProcessors} 코어',
  );
  final f = File('../docs/reports/01-dummy-failure.md');
  f.parent.createSync(recursive: true);
  f.writeAsStringSync(md);
  stdout.writeln('리포트: ${f.path}');

  // DoD 판정. exit(1)로 끝내면 CI(06-06)에서도 게이트로 쓸 수 있다.
  final bad = failingMeasurements(results);
  if (bad.isNotEmpty) {
    stderr.writeln('DoD 미달 레벨: ${bad.map((m) => m.spec.id).join(", ")}');
    exit(1);
  }
}

int _intArg(List<String> args, String name, int fallback) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return fallback;
  return int.tryParse(args[i + 1]) ?? fallback;
}
