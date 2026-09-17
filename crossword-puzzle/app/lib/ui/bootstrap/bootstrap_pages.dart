// DB 부트스트랩(03-02) 진행/실패 화면 (04-01 "시작 화면·실패 처리").
//
// `DbBootstrap.open()`은 첫 실행 시 10MB 시드를 복사해 수 초 걸릴 수 있다.
// `runApp` 앞에서 이를 기다리면 흰 화면이 뜨므로, `JGameApp`(main.dart)이
// `runApp`을 먼저 부르고 `FutureBuilder`로 이 두 화면을 보여주는 방식을 쓴다.
import 'package:flutter/material.dart';

/// 부트스트랩 진행 중 화면.
class BootstrapLoadingPage extends StatelessWidget {
  const BootstrapLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('사전 데이터를 준비하는 중입니다…'),
          ],
        ),
      ),
    );
  }
}

/// 부트스트랩 실패 화면. `SchemaMismatch`/`EmptyDatabase`(03-02)를 사람이 읽을 수
/// 있는 메시지로 보여준다.
class BootstrapErrorPage extends StatelessWidget {
  final Object error;
  const BootstrapErrorPage({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 16),
              const Text('앱을 시작할 수 없습니다.'),
              const SizedBox(height: 8),
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('앱을 삭제 후 재설치해 주세요.'),
            ],
          ),
        ),
      ),
    );
  }
}
