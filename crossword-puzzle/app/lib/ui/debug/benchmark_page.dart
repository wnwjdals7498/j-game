// 03-05 실기기 벤치마크 화면.
//
// **임시 화면이다.** 4단계(04-06 홈·설정 화면) UI가 완성되기 전까지 여기
// 있다가, 04-06에서 설정 화면 하위로 옮긴다 (03-05 "실기기 벤치마크 화면"
// 절 — "4단계 UI 전이라 임시 화면을 만든다"). `main.dart` 의 진입점도 같은
// 이유로 임시다.
//
// [DoD는 실기기 기준]이다 (03-05 "두 환경" 절) — 데스크톱 하네스
// (`tool/measure_real.dart`)로 스펙을 먼저 맞춘 뒤, 이 화면으로 실기기에서
// 최종 확인한다. 실기기는 1000회가 오래 걸려 레벨당 100회로 고정하고,
// 데스크톱 1000회와 비교해 "실기기가 데스크톱의 몇 배 느린가" 배수를 구해
// 데스크톱 수치에 적용한다 (03-05 "실기기 벤치마크 화면" 절).
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

import '../../domain/levels.dart';
import '../../domain/measure/measure_runner.dart';
import '../../domain/model/level_spec.dart';
import '../../domain/repository/word_repository.dart';

/// 실기기 벤치마크 화면. [repo] 는 실 DB([DriftWordRepository]) 를 주입받는다.
/// 이 파일은 `ui/` 라 drift를 직접 알아도 되지만, 데스크톱/테스트에서도 같은
/// 화면을 열 수 있도록 인터페이스([WordRepository])로만 받는다.
class BenchmarkPage extends StatefulWidget {
  final WordRepository repo;
  const BenchmarkPage({super.key, required this.repo});

  @override
  State<BenchmarkPage> createState() => _BenchmarkPageState();
}

class _BenchmarkPageState extends State<BenchmarkPage> {
  /// 실기기 1회 실행 횟수 (03-05: "실기기는 1000회가 너무 오래 걸린다.
  /// 레벨당 100회로 하고" — 데스크톱 1000회는 `tool/measure_real.dart` 몫이다).
  static const int _runsPerLevel = 100;

  /// [MeasureRunner.measureLevel] 을 한 번에 100회 부르면 `onProgress` 가
  /// 100회에 1번만(끝에서) 불려 진행률 표시가 무의미해진다. 대신 이 크기로
  /// 나눠 여러 번 부르고, 배치 사이에 [Future.delayed] 로 UI 스레드를
  /// 양보한다 (03-05 "막히면": "벤치마크 화면이 ANR → 루프에
  /// `await Future.delayed(Duration.zero)` 를 넣어 UI 스레드를 양보한다").
  /// `MeasureRunner` 자체는 01-10 그대로이고 새로 만들지 않는다 — 화면이
  /// 배치로 나눠 부르고 결과를 합칠 뿐이다.
  static const int _batchSize = 10;

  LevelSpec _selected = levels.first;
  bool _running = false;
  int _done = 0;
  LevelMeasurement? _result;
  String? _error;

  Future<void> _runBenchmark() async {
    setState(() {
      _running = true;
      _done = 0;
      _result = null;
      _error = null;
    });

    final spec = _selected;
    final runner = MeasureRunner(widget.repo);
    final chunks = <LevelMeasurement>[];

    try {
      for (var start = 0; start < _runsPerLevel; start += _batchSize) {
        final n = min(_batchSize, _runsPerLevel - start);
        // measureLevel 내부는 startSeed, startSeed+100, ... 을 쓰므로
        // (seed 간격 100의 이유는 measure_runner.dart 참고), 배치 경계에서
        // 표본이 겹치지 않도록 시작 seed를 배치만큼씩 밀어준다.
        final m = await runner.measureLevel(
          spec,
          runs: n,
          startSeed: 1 + start * 100,
        );
        chunks.add(m);
        if (!mounted) return;
        setState(() => _done += n);
        // UI 스레드 양보 — 위 클래스 문서 참고.
        await Future.delayed(Duration.zero);
      }
      if (!mounted) return;
      setState(() => _result = _mergeChunks(spec, chunks));
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  /// 배치별 [LevelMeasurement] 를 레벨 하나짜리 결과로 합친다.
  LevelMeasurement _mergeChunks(LevelSpec spec, List<LevelMeasurement> chunks) {
    final elapsed = <int>[];
    final attempts = <int>[];
    final backtracks = <int>[];
    final queries = <int>[];
    var runs = 0;
    var failures = 0;
    var timeouts = 0;
    for (final c in chunks) {
      runs += c.runs;
      failures += c.failures;
      timeouts += c.timeouts;
      elapsed.addAll(c.elapsedMicros);
      attempts.addAll(c.attempts);
      backtracks.addAll(c.backtracks);
      queries.addAll(c.queries);
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

  String _summaryText(LevelMeasurement m) {
    return '레벨 ${m.spec.id} ${m.spec.name} (${m.runs}회, 실기기)\n'
        '실패율 ${(m.failureRate * 100).toStringAsFixed(2)}%\n'
        'p50 ${(m.p50 / 1000).toStringAsFixed(1)}ms\n'
        'p95 ${(m.p95 / 1000).toStringAsFixed(1)}ms\n'
        '평균 시도 ${m.avgAttempts.toStringAsFixed(2)}\n'
        '평균 되감기 ${m.avgBacktracks.toStringAsFixed(1)}\n'
        '평균 질의 ${m.avgQueries.toStringAsFixed(1)}\n'
        'timeout ${m.timeouts}건';
  }

  Future<void> _copyResult() async {
    final m = _result;
    if (m == null) return;
    await Clipboard.setData(ClipboardData(text: _summaryText(m)));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('결과를 클립보드에 복사했다')));
  }

  @override
  Widget build(BuildContext context) {
    final m = _result;
    return Scaffold(
      appBar: AppBar(title: const Text('벤치마크 (임시 · 03-05)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButton<LevelSpec>(
              value: _selected,
              items: [
                for (final l in levels)
                  DropdownMenuItem(value: l, child: Text('${l.id} ${l.name}')),
              ],
              onChanged: _running
                  ? null
                  : (l) => setState(() => _selected = l ?? _selected),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _running ? null : _runBenchmark,
              child: Text('$_runsPerLevel회 실행'),
            ),
            const SizedBox(height: 12),
            if (_running) ...[
              LinearProgressIndicator(value: _done / _runsPerLevel),
              const SizedBox(height: 8),
              Text('$_done / $_runsPerLevel'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text('오류: $_error', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (m != null) ...[
              const SizedBox(height: 16),
              Text(_summaryText(m)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _copyResult,
                child: const Text('결과를 클립보드로 복사'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
