// tool/invariants/runner.dart
//
// rules.dart의 선언(Kind 6종)을 해석해 실제로 파일을 읽고 판정하는 실행기.
// 07-01-02 "산출물": Status·Finding·RuleResult·InvariantReport·runInvariants.

import 'dart:io';
import 'rules.dart';

enum Status { pass, fail, skip }

/// 위반 1건. [line]이 0이면 줄 개념이 없는 검사(depsExact, gitClean, testNamesExist).
class Finding {
  final String path;    // root 기준 상대 경로, 구분자는 항상 '/'
  final int line;       // 1-based
  final String detail;  // 예: '"Colors.amber"' / '누락: 제출'
  const Finding(this.path, this.line, this.detail);
  @override
  String toString() => line > 0 ? '$path:$line $detail' : '$path $detail';
}

class RuleResult {
  final Rule rule;
  final Status status;
  final List<Finding> findings;
  final String? note;   // SKIP 사유
  const RuleResult(this.rule, this.status, {this.findings = const [], this.note});
}

class InvariantReport {
  final List<RuleResult> results;
  const InvariantReport(this.results);

  RuleResult byId(String id) => results.firstWhere((r) => r.rule.id == id);
  int get passed => results.where((r) => r.status == Status.pass).length;
  int get failed => results.where((r) => r.status == Status.fail).length;
  int get skipped => results.where((r) => r.status == Status.skip).length;
  bool get ok => failed == 0;

  String render() {
    final buffer = StringBuffer();
    for (final r in results) {
      final label = switch (r.status) {
        Status.pass => 'PASS',
        Status.fail => 'FAIL',
        Status.skip => 'SKIP',
      };
      final head = StringBuffer('$label ${r.rule.id} ${r.rule.title}');
      if (r.status == Status.skip && r.note != null) {
        head.write(' ${r.note}');
      }
      if (r.status == Status.fail && r.findings.isNotEmpty) {
        head.write(' — ${r.findings.first}');
      }
      buffer.writeln(head.toString());
      if (r.status == Status.fail) {
        for (final f in r.findings.skip(1)) {
          buffer.writeln('     $f');
        }
      }
    }
    buffer.write('$passed passed, $failed failed, $skipped skipped');
    return buffer.toString();
  }
}

/// [root]는 app/ 또는 fixture를 심은 임시 디렉터리. [gitBase]가 null이면
/// Kind.gitClean 규칙은 SKIP.
InvariantReport runInvariants(Directory root, {String? gitBase}) {
  final results = <RuleResult>[
    for (final rule in rules) _evaluate(root, rule, gitBase),
  ];
  return InvariantReport(results);
}

RuleResult _evaluate(Directory root, Rule rule, String? gitBase) {
  switch (rule.kind) {
    case Kind.mustContain:
      return _mustContain(root, rule);
    case Kind.mustNotContain:
      return _mustNotContain(root, rule);
    case Kind.testNamesExist:
      return _testNamesExist(root, rule);
    case Kind.levelsMax:
      return _levelsMax(root, rule);
    case Kind.depsExact:
      return _depsExact(root, rule);
    case Kind.gitClean:
      return _gitClean(root, rule, gitBase);
  }
}

// ---- 파일 수집과 줄 필터 (모든 Kind 공통, 작업 2) ----

class _FileText {
  final String path; // root 기준 상대 경로, '/' 구분자
  final List<String> lines;
  const _FileText(this.path, this.lines);
}

/// [paths]를 순서대로 훑어 파일 목록을 모은다. 디렉터리는 재귀하며 `.dart`만
/// 취하고, 존재하지 않는 항목은 조용히 건너뛴다(빈 fixture에서 크래시 금지).
/// 반환 순서는 상대 경로 오름차순으로 정렬해 출력을 결정적으로 만든다.
List<_FileText> _collect(Directory root, List<String> paths, List<String> exclude) {
  final out = <_FileText>[];
  for (final p in paths) {
    final entityPath = '${root.path}/$p';
    final type = FileSystemEntity.typeSync(entityPath, followLinks: false);
    if (type == FileSystemEntityType.notFound) continue;
    if (type == FileSystemEntityType.directory) {
      final files = Directory(entityPath)
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
      for (final f in files) {
        final rel = _relPath(root, f.path);
        if (_isExcluded(rel, exclude)) continue;
        out.add(_FileText(rel, _readLines(f)));
      }
    } else {
      final rel = _relPath(root, entityPath);
      if (_isExcluded(rel, exclude)) continue;
      out.add(_FileText(rel, _readLines(File(entityPath))));
    }
  }
  out.sort((a, b) => a.path.compareTo(b.path));
  return out;
}

String _relPath(Directory root, String absPath) {
  final rel = absPath.replaceAll('\\', '/');
  final base = root.path.replaceAll('\\', '/');
  var out = rel.startsWith(base) ? rel.substring(base.length) : rel;
  if (out.startsWith('/')) out = out.substring(1);
  return out;
}

bool _isExcluded(String rel, List<String> exclude) => exclude.any(rel.startsWith);

List<String> _readLines(File file) {
  var content = file.readAsStringSync();
  if (content.isNotEmpty && content.codeUnitAt(0) == 0xFEFF) {
    content = content.substring(1); // 선두 BOM 제거
  }
  return content
      .split('\n')
      .map((l) => l.endsWith('\r') ? l.substring(0, l.length - 1) : l)
      .toList();
}

bool _isCommentLine(String line) => line.trimLeft().startsWith('//');

// ---- Kind 6종 (작업 3) ----

RuleResult _mustContain(Directory root, Rule rule) {
  final files = _collect(root, rule.paths, rule.exclude);
  final buffer = StringBuffer();
  for (final f in files) {
    for (final line in f.lines) {
      if (_isCommentLine(line)) continue;
      buffer.writeln(line);
    }
  }
  final content = buffer.toString();
  final findings = <Finding>[
    for (final needle in rule.needles)
      if (!content.contains(needle)) Finding(rule.paths.first, 0, '누락: $needle'),
  ];
  return RuleResult(rule, findings.isEmpty ? Status.pass : Status.fail, findings: findings);
}

RuleResult _mustNotContain(Directory root, Rule rule) {
  final files = _collect(root, rule.paths, rule.exclude);
  final findings = <Finding>[];
  for (final f in files) {
    for (var i = 0; i < f.lines.length; i++) {
      final line = f.lines[i];
      if (_isCommentLine(line)) continue;
      for (final needle in rule.needles) {
        var pos = 0;
        while (true) {
          final idx = line.indexOf(needle, pos);
          if (idx < 0) break;
          pos = idx + needle.length;
          // 식별자 접두 오탐 방지: needle이 단어 문자로 시작하면, 그 앞이 단어
          // 문자로 이어지는 경우(예: "GameColors."의 "Colors.")는 별개 식별자의
          // 일부이지 위반이 아니다. needle이 '.'처럼 연산자로 시작하면 이 검사를
          // 하지 않는다(예: "entry.headword"는 앞이 단어 문자여도 진짜 위반이다).
          if (_isWordChar(needle[0]) && idx > 0 && _isWordChar(line[idx - 1])) {
            continue;
          }
          // INV-05 예외: Colors.transparent는 위반이 아니다.
          if (needle == 'Colors.' && line.startsWith('Colors.transparent', idx)) {
            continue;
          }
          findings.add(Finding(f.path, i + 1, '"${_extendMatch(line, idx, needle)}"'));
        }
      }
    }
  }
  return RuleResult(rule, findings.isEmpty ? Status.pass : Status.fail, findings: findings);
}

/// 매치된 needle 위치에서 실제 토큰 전체(예: 'Colors.' → 'Colors.amber',
/// 'Color(0x' → 'Color(0xFF112233)')로 늘려 보고용 문자열을 만든다.
String _extendMatch(String line, int start, String needle) {
  var end = start + needle.length;
  if (needle.endsWith('.')) {
    while (end < line.length && _isWordChar(line[end])) {
      end++;
    }
  } else if (needle.contains('(') && !needle.contains(')')) {
    final close = line.indexOf(')', end);
    if (close >= 0) end = close + 1;
  }
  return line.substring(start, end);
}

bool _isWordChar(String ch) {
  final c = ch.codeUnitAt(0);
  return (c >= 0x30 && c <= 0x39) ||
      (c >= 0x41 && c <= 0x5A) ||
      (c >= 0x61 && c <= 0x7A) ||
      c == 0x5F;
}

RuleResult _testNamesExist(Directory root, Rule rule) {
  final files = _collect(root, rule.paths, rule.exclude);
  final buffer = StringBuffer();
  for (final f in files) {
    for (final line in f.lines) {
      if (_isCommentLine(line)) continue;
      buffer.writeln(line);
    }
  }
  final content = buffer.toString();
  final findings = <Finding>[
    for (final name in rule.needles)
      if (!content.contains(name)) Finding('test', 0, '누락: $name'),
  ];
  return RuleResult(rule, findings.isEmpty ? Status.pass : Status.fail, findings: findings);
}

final _levelsRe = RegExp(r'(width|height):\s*(\d+)');

RuleResult _levelsMax(Directory root, Rule rule) {
  final files = _collect(root, rule.paths, rule.exclude);
  final max = rule.max!;
  final findings = <Finding>[];
  for (final f in files) {
    for (var i = 0; i < f.lines.length; i++) {
      final line = f.lines[i];
      if (_isCommentLine(line)) continue;
      for (final m in _levelsRe.allMatches(line)) {
        final value = int.parse(m.group(2)!);
        if (value > max) {
          findings.add(Finding(f.path, i + 1, '${m.group(1)}: $value > $max'));
        }
      }
    }
  }
  return RuleResult(rule, findings.isEmpty ? Status.pass : Status.fail, findings: findings);
}

final _depKeyRe = RegExp(r'^  ([A-Za-z0-9_]+):');

RuleResult _depsExact(Directory root, Rule rule) {
  final files = _collect(root, rule.paths, rule.exclude);
  final lines = files.isEmpty ? const <String>[] : files.first.lines;
  final found = <String>{};
  final start = lines.indexWhere((l) => l.trimRight() == 'dependencies:');
  if (start >= 0) {
    for (var i = start + 1; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      if (line.isNotEmpty && line[0] != ' ') break; // 들여쓰기 0: dependencies 블록 끝
      final m = _depKeyRe.firstMatch(line);
      if (m != null) found.add(m.group(1)!);
    }
  }
  final added = found.difference(allowedDeps).toList()..sort();
  final missing = allowedDeps.difference(found).toList()..sort();
  final findings = <Finding>[
    for (final k in added) Finding('pubspec.yaml', 0, '추가됨: $k'),
    for (final k in missing) Finding('pubspec.yaml', 0, '빠짐: $k'),
  ];
  return RuleResult(rule, findings.isEmpty ? Status.pass : Status.fail, findings: findings);
}

RuleResult _gitClean(Directory root, Rule rule, String? gitBase) {
  if (gitBase == null) {
    return RuleResult(rule, Status.skip, note: '(--git-base 없음)');
  }
  final result = Process.runSync(
    'git',
    ['diff', '--name-only', gitBase, '--', ...rule.paths],
    workingDirectory: root.path,
    runInShell: true,
  );
  final out = result.stdout is String ? result.stdout as String : '${result.stdout}';
  final changed = out
      .split(RegExp(r'\r?\n'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .map((l) => l.replaceAll('\\', '/'))
      .toList();
  final findings = <Finding>[for (final c in changed) Finding(c, 0, '수정됨')];
  return RuleResult(rule, findings.isEmpty ? Status.pass : Status.fail, findings: findings);
}
