import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:jgame/data/db/app_database.dart';
import 'package:jgame/data/drift_word_repository.dart';
import 'package:jgame/domain/levels.dart';
import 'package:jgame/domain/measure/measure_runner.dart';

/// 실 DB 실패율·성능 하네스 (03-05).
///
/// 01-10의 [MeasureRunner] 를 그대로 쓰고 repository만 [DriftWordRepository]
/// 로 바꾼다. `tool/` 은 `lib/` 밖이라 `dart:io` 를 써도 된다.
///
/// **2026-09-17**: `app/assets/words.sqlite` 가 00-01 승인 후 실데이터(26,000단어,
/// 기초사전+표준국어대사전+빈도+학습용 어휘 등급, `origin=raw`)로 재빌드됐다.
/// 이 하네스로 낸 03단계 실측(레벨당 1000 seed)이 `docs/reports/03-real-failure.md`
/// 에 있고, 그 결과로 03-06에서 `levels.dart` 를 v1으로 확정했다.
///
/// 아래 `origin=fixtures` 판정은 `tools/fixtures/` 손수 샘플(16단어)로 배선만
/// 확인하던 이전 단계의 잔재다. 앞으로도 fixtures DB로 이 하네스를 돌릴 일이
/// 있을 수 있어(예: CI 스모크) 판정 로직과 경고문은 그대로 둔다 — 지금 커밋된
/// `assets/words.sqlite` 는 `origin=raw` 라 이 경고는 뜨지 않는다.
///
/// 사용법 (`app/` 디렉터리에서):
///   dart run tool/measure_real.dart                  (전 레벨 1000회)
///   dart run tool/measure_real.dart --runs 100        (빠른 확인)
///   dart run tool/measure_real.dart --level 9 --runs 1000
Future<void> main(List<String> args) async {
  final runs = _intArg(args, '--runs', 1000);
  final onlyLevel = _intArg(args, '--level', 0);
  final dbPath = _strArg(args, '--db', 'assets/words.sqlite');

  // assets 원본을 직접 열면 coreCandidates가 (그리고 향후 앱 코드가)
  // word_stat에 쓰게 되어 재측정마다 결과가 달라진다 (03-05 "막히면":
  // "측정할 때마다 결과가 다름 → word_stat이 오염됐다"). 임시 복사본만 연다.
  final tmp = File('${Directory.systemTemp.path}/'
      'measure_real_${DateTime.now().microsecondsSinceEpoch}.sqlite');
  await File(dbPath).copy(tmp.path);

  final db = AppDatabase(NativeDatabase(tmp));
  final repo = DriftWordRepository(db);

  try {
    // fixtures(00-01 승인 대기 중 손수 샘플) 여부 판정. word_repository_test.dart
    // (03-03)가 쓰는 것과 같은 판정 — meta.source_versions.origin.
    var isFixture = false;
    final raw = await db.metaValue('source_versions');
    if (raw != null) {
      try {
        final parsed = jsonDecode(raw);
        isFixture = parsed is Map && parsed['origin'] == 'fixtures';
      } catch (_) {
        isFixture = false;
      }
    }
    final wordCount = await db.wordCount;

    final runner = MeasureRunner(repo);
    final specs =
        onlyLevel == 0 ? levels : levels.where((l) => l.id == onlyLevel).toList();

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

    final source = 'app/assets/words.sqlite ($wordCount단어'
        '${isFixture ? ", origin=fixtures — 00-01 승인 대기 중 손수 샘플" : ""})';

    var md = renderMarkdown(
      results,
      runs: runs,
      source: source,
      title: '03단계 실데이터 실패율 리포트',
      environment: '${Platform.operatingSystemVersion}, '
          'dart ${Platform.version.split(' ').first}, '
          'CPU ${Platform.numberOfProcessors} 코어',
    );
    if (isFixture) md = _withFixtureWarning(md);

    final f = File('../docs/reports/03-real-failure.md');
    f.parent.createSync(recursive: true);
    f.writeAsStringSync(md);
    stdout.writeln('리포트: ${f.path}');

    if (isFixture) {
      // 16단어 표본으로는 실패율·p95가 통계적으로 의미가 없어 DoD 게이트로
      // 쓰지 않는다. 03-05의 DoD는 실기기 기준이고, 이 실행은 배선 확인일
      // 뿐이다 (문서 "두 환경" 절).
      stdout.writeln('fixtures 예비 실행: DoD 판정 생략 (00-01 승인 후 재실행 필요)');
      return;
    }

    final bad = failingMeasurements(results);
    if (bad.isNotEmpty) {
      stderr.writeln('DoD 미달 레벨: ${bad.map((m) => m.spec.id).join(", ")}');
      exit(1);
    }
  } finally {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync();
  }
}

/// fixtures 표본으로 돌린 리포트 맨 위에 경고 블록을 끼워 넣는다.
/// `docs/reports/02-db-report.md` 가 쓰는 것과 같은 형식(⚠ 인용구)이다.
String _withFixtureWarning(String body) {
  const warning = '> ⚠ 이 리포트는 **예비 실행**이다 — 진짜 측정이 아니다. '
      '`app/assets/words.sqlite` 가 아직 00-01(국립국어원 사전 자료 이용 신청) '
      '승인 대기 중 `tools/fixtures/` 손수 샘플(16단어)이라서 나온 결과다.\n'
      '>\n'
      '> 목적은 이 데스크톱 하네스(`DriftWordRepository`/`AppDatabase` 배선)가 '
      '실제로 도는지 확인하는 것뿐이다. 아래 실패율·p50/p95·DoD 표는 통계적으로 '
      '의미가 없으니 03-05/03-06 DoD 판정 근거로 쓰지 않는다.\n'
      '>\n'
      '> 00-01 승인 후 실데이터로 재빌드된 DB로 `dart run tool/measure_real.dart`'
      ' 를 다시 돌려 이 리포트를 갱신해야 한다.\n';

  final lines = body.split('\n');
  final idx = lines.indexWhere((l) => l.startsWith('## '));
  if (idx < 0) return '$warning\n$body';
  final head = lines.sublist(0, idx).join('\n');
  final rest = lines.sublist(idx).join('\n');
  return '$head\n$warning\n$rest';
}

int _intArg(List<String> args, String name, int fallback) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return fallback;
  return int.tryParse(args[i + 1]) ?? fallback;
}

String _strArg(List<String> args, String name, String fallback) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return fallback;
  return args[i + 1];
}
