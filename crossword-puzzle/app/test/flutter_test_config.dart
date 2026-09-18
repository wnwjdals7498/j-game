// 07-08-01 골든 하네스: `test/` 아래 모든 테스트 실행 전에 1회 돈다.
// `flutter test`는 에셋 번들을 열지 않으므로 pubspec의 `fonts:` 등록이
// 소용없다 — 폰트를 `File`로 읽어 `FontLoader`에 직접 넣는다.
import 'dart:async';
import 'dart:io';

// `dart:typed_data`(ByteData)는 flutter/services.dart가 이미 내보내므로 별도
// import하면 `unnecessary_import` lint로 `flutter analyze`가 깨진다(DoD:
// "flutter analyze 0"). 07-08-01 "막히면"과 같은 급의 문제 — 로직은
// 그대로 두고 중복 import만 뺀다.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jgame/ui/theme/tokens.dart'; // GameType.family = 'Pretendard'

/// 07-02-04가 번들한 3종. 파일명이 다르면 pubspec의 `fonts:`를 보고 맞춘다.
const _fonts = <String>[
  'assets/fonts/Pretendard-Regular.otf',
  'assets/fonts/Pretendard-SemiBold.otf',
  'assets/fonts/Pretendard-Bold.otf',
];

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final files = _fonts.map(File.new).toList();
  if (files.every((f) => f.existsSync())) {
    final loader = FontLoader(GameType.family);
    for (final f in files) {
      loader.addFont(f.readAsBytes().then((b) => ByteData.sublistView(b)));
    }
    await loader.load();
  }
  // 파일이 하나라도 없으면 조용히 시스템 폰트로 간다 — 07-02-04 전에도 기존
  // 테스트가 전부 돌아야 하기 때문이다. 이 폴백은 07-08-02의 "두부 글리프
  // 없음" 눈 검수에서 반드시 드러난다.

  // `Icon(Icons.*)`는 'MaterialIcons' 폰트를 쓰는데, `flutter test`는 SDK가
  // 번들한 이 폰트도 자동으로 안 싣는다 — 골든 6장에서 실제로 두부 글리프가
  // 나온 걸 눈 검수가 잡아서(07-08-02) 추가한다. 새 패키지 없이(INV-11)
  // Flutter SDK 자신이 들고 있는 실제 파일을 읽어 직접 로드한다.
  final materialIcons = _materialIconsFontFile();
  if (materialIcons != null && materialIcons.existsSync()) {
    final loader = FontLoader('MaterialIcons');
    loader.addFont(
        materialIcons.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }

  await testMain();
}

/// `<flutter_root>/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf`.
/// `Platform.resolvedExecutable`이 가리키는 실행 파일이 `flutter_root` 밑
/// 몇 단계인지는 실행 방식에 따라 다르다(`flutter test`는
/// `bin/cache/artifacts/engine/<platform>/flutter_tester(.exe)`, 맨 `dart test`는
/// `bin/cache/dart-sdk/bin/dart(.exe)`) — 고정 단계 수를 세지 않고, 조상
/// 디렉터리를 하나씩 올라가며 그 자리가 `flutter_root`인지(= 그 아래
/// `bin/cache/artifacts/material_fonts/...`가 실제로 있는지)로 판정한다.
/// 못 찾아도(SDK 배치가 다른 환경) 조용히 null을 돌려준다 — Pretendard
/// 폴백과 같은 정책이다.
File? _materialIconsFontFile() {
  try {
    var dir = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 10; i++) {
      final candidate = File(
          '${dir.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if (candidate.existsSync()) return candidate;
      final parent = dir.parent;
      if (parent.path == dir.path) break; // 파일시스템 루트
      dir = parent;
    }
    return null;
  } catch (_) {
    return null;
  }
}
