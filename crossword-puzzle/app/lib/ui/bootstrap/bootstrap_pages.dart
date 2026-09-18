// DB 부트스트랩(03-02) 진행/실패 화면 (04-01 "시작 화면·실패 처리").
//
// `DbBootstrap.open()`은 첫 실행 시 10MB 시드를 복사해 수 초 걸릴 수 있다.
// `runApp` 앞에서 이를 기다리면 흰 화면이 뜨므로, `JGameApp`(main.dart)이
// `runApp`을 먼저 부르고 `FutureBuilder`로 이 두 화면을 보여주는 방식을 쓴다.
//
// 07-07-02: 원형 스피너 → 상단 2dp 선형 표시(E-11), 오류 화면 →
// UI-GUIDE 4절 공용 빈 상태. 두 화면 다 아직 테마가 없을 수 있는 시점에도
// 떠야 하므로 `GameLoadingView`/`GameEmptyState`(둘 다 `Theme.of(context)`만
// 읽는다)를 그대로 쓴다.
import 'package:flutter/material.dart';

import '../common/empty_state.dart';
import '../common/loading_view.dart';

/// 부트스트랩 진행 중 화면.
class BootstrapLoadingPage extends StatelessWidget {
  const BootstrapLoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: GameLoadingView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('J Crossword Puzzle', style: t.textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                '사전 데이터를 준비하는 중입니다…',
                style: t.textTheme.bodyLarge
                    ?.copyWith(color: t.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
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
      body: SafeArea(
        child: GameEmptyState(
          title: '앱을 시작할 수 없습니다.',
          message: '$error',
          hint: '앱을 삭제 후 재설치해 주세요.',
        ),
      ),
    );
  }
}
