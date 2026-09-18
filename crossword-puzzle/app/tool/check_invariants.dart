// UI-GUIDE.md 7절 불변 조건(INV-xx) 감시. app/ 에서 실행한다.
// 위반이 하나라도 있으면 exit code 1.
//
//   --git-base <ref>   INV-07(domain/data 무수정)을 이 ref와의 diff로 검사한다.
//                      없으면 INV-07은 SKIP.
import 'dart:io';

import 'invariants/runner.dart';

void main(List<String> args) {
  final report = runInvariants(Directory.current, gitBase: _arg(args, '--git-base'));
  stdout.writeln(report.render());
  if (!report.ok) exit(1);
}

String? _arg(List<String> args, String name) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return null;
  return args[i + 1];
}
