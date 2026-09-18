// 07-01-03. 위반 fixture로 실행기가 실제로 위반을 잡는지 증명하는 자체 테스트.
//
// tool/은 lib/ 밖이라 package:jgame/...로 못 가져온다. 이 파일도 lib/ 밖이므로
// 상대 경로 import를 쓴다(이 저장소에 전례가 없는 첫 사례 — 07-01-03 "작업 4").
import 'dart:io';

import 'package:test/test.dart';

import '../../tool/invariants/runner.dart';

/// fixture 내용을 root 기준 경로에 심은 임시 디렉터리를 만든다.
/// {'lib/ui/bad.dart': 'hardcoded_color.dart'} → `<temp>/lib/ui/bad.dart`
Directory stage(Map<String, String> layout) {
  final root = Directory.systemTemp.createTempSync('inv');
  addTearDown(() {
    try {
      root.deleteSync(recursive: true);
    } catch (_) {
      // Windows: 임시 디렉터리 삭제 실패(핸들이 열려 있음)는 테스트를 깨지 않는다.
    }
  });
  layout.forEach((dest, fixture) {
    final f = File('${root.path}/$dest')..parent.createSync(recursive: true);
    f.writeAsStringSync(
        File('test/tool/fixtures/violations/$fixture').readAsStringSync());
  });
  return root;
}

void main() {
  test('하드코딩 색 검출: 파일:줄이 전부 나온다', () {
    final root = stage({'lib/ui/bad.dart': 'hardcoded_color.dart'});
    final report = runInvariants(root);
    final result = report.byId('INV-05');
    expect(result.status, Status.fail);
    expect(result.findings.length, 2);
    expect(result.findings.first.path, 'lib/ui/bad.dart');
  });

  test('Colors.transparent는 허용', () {
    final root = stage({'lib/ui/ok.dart': 'transparent_ok.dart'});
    final report = runInvariants(root);
    expect(report.byId('INV-05').status, Status.pass);
  });

  test('주석 줄은 무시', () {
    final root = stage({'lib/ui/ok.dart': 'comment_only.dart'});
    final report = runInvariants(root);
    expect(report.byId('INV-05').status, Status.pass);
  });

  test('보호 테스트 누락 검출', () {
    final root = stage({'test/x_test.dart': 'missing_test_name.dart'});
    final report = runInvariants(root);
    final result = report.byId('INV-08');
    expect(result.status, Status.fail);
    expect(result.findings.any((f) => f.detail.contains('완성형만')), isTrue);
  });

  test('의존성 추가 검출', () {
    final root = stage({'pubspec.yaml': 'pubspec_extra_dep.yaml'});
    final report = runInvariants(root);
    final result = report.byId('INV-11');
    expect(result.status, Status.fail);
    expect(result.findings.any((f) => f.detail.contains('lottie')), isTrue);
  });

  test('의존성 제거 검출', () {
    final root = stage({'pubspec.yaml': 'pubspec_missing_dep.yaml'});
    final report = runInvariants(root);
    final result = report.byId('INV-11');
    expect(result.status, Status.fail);
    expect(result.findings.any((f) => f.detail.contains('provider')), isTrue);
  });

  test('격자 상한 초과 검출', () {
    final root = stage({'lib/domain/levels.dart': 'levels_over_max.dart'});
    final report = runInvariants(root);
    final result = report.byId('INV-10');
    expect(result.status, Status.fail);
    expect(result.findings.any((f) => f.detail.contains('9')), isTrue);
  });

  test('실제 저장소: 전부 PASS 또는 SKIP', () {
    final report = runInvariants(Directory.current);
    expect(report.ok, isTrue);
    expect(report.byId('INV-07').status, Status.skip);
  });
}
