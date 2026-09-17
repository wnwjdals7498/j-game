// 4단계(04-01) 앱 셸: DB 부트스트랩 → Provider 주입 → 라우팅.
//
// 상태 관리는 `ChangeNotifier` + `provider`로 확정했다
// (docs/plan/04-01.app-shell-state.md "결정: 상태 관리" — 화면 4개·상태 객체 3개
// 규모라 Riverpod의 코드 생성·프로바이더 계층이 과하다는 문서의 권고를 따른다).
//
// `DbBootstrap.open()`(03-02)이 최초 실행 시 10MB를 복사해 수 초 걸릴 수 있다.
// `runApp` 앞에서 이를 `await`하면 흰 화면이 뜨므로(04-01 "시작 화면·실패 처리"),
// 문서가 명시한 "2번" 방식대로 `runApp`을 먼저 부르고 `FutureBuilder`로 로딩·에러
// 화면을 보여준다. 그러려면 `MultiProvider`는 부트스트랩이 끝난 뒤에도
// `MaterialApp`의 조상이어야 한다 — 그래야 라우트로 이동한 화면에서도 Provider가
// 보인다(04-01 "막히면": "MultiProvider가 MaterialApp 바깥에 있어야 라우트로
// 이동한 화면에서도 보인다"). 이 두 요구를 동시에 만족하려면 `FutureBuilder`가
// 부트스트랩 성공 시 `MultiProvider(child: MaterialApp(...))`를 반환해야 한다 —
// 문서의 main.dart 스니펫(부트스트랩을 top-level await로 먼저 끝내고
// `MultiProvider`로 감싼 뒤 `runApp`)과 이어지는 "시작 화면" 절(2번: `runApp` 먼저
// + `FutureBuilder`)은 그대로 이어붙이면 서로 모순되므로, 문서가 명시적으로
// 선택한 2번을 기준으로 두 스니펫을 이 형태로 합쳤다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'data/db/db_bootstrap.dart';
import 'data/drift_word_repository.dart';
import 'data/stat_repository.dart';
import 'domain/generator/grid_generator.dart';
import 'ui/bootstrap/bootstrap_pages.dart';
import 'ui/home/home_page.dart';
import 'ui/puzzle/puzzle_page.dart';
import 'ui/result/result_page.dart';
import 'ui/settings/settings_page.dart';
import 'ui/state/app_scope.dart';
import 'ui/state/settings_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 격자가 정사각형이라 가로 모드에서 얻는 게 없다 (04-01 "세로 고정").
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(JGameApp(bootstrap: _bootstrap()));
}

/// DB 부트스트랩(03-02) → 리포지토리 조립. [JGameApp]의 `FutureBuilder`가 기다린다.
Future<AppScope> _bootstrap() async {
  final db = await DbBootstrap.open();
  return AppScope(
    db: db,
    words: DriftWordRepository(db),
    stats: StatRepository(db),
    generator: GridGenerator(DriftWordRepository(db)),
  );
}

/// 화면 4개 라우트 (04-01 "화면 구성"). 퍼즐→결과 전환은 `Navigator.push`로
/// 인자를 넘긴다(04-05) — 여기 등록은 각 화면에 직접 진입할 수 있게만 한다.
Map<String, WidgetBuilder> buildRoutes() => {
      '/': (_) => const HomePage(),
      '/play': (_) => const PuzzlePage(),
      '/result': (_) => const ResultPage(),
      '/settings': (_) => const SettingsPage(),
    };

class JGameApp extends StatelessWidget {
  /// 테스트에서는 실 `DbBootstrap.open()`을 건너뛰고 가짜 [AppScope]를 담은
  /// Future(완료/미완료/에러)를 바로 주입한다 — 04-01 "막히면":
  /// "테스트에서는 AppScope를 직접 주입하고 부트스트랩을 건너뛴다."
  final Future<AppScope> bootstrap;

  const JGameApp({super.key, required this.bootstrap});

  static const _title = '단어 연상 퀴즈';

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppScope>(
      future: bootstrap,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            title: _title,
            home: BootstrapErrorPage(error: snapshot.error!),
          );
        }
        if (!snapshot.hasData) {
          return const MaterialApp(
            title: _title,
            home: BootstrapLoadingPage(),
          );
        }
        return MultiProvider(
          providers: [
            Provider<AppScope>.value(value: snapshot.data!),
            ChangeNotifierProvider(create: (_) => SettingsModel()..load()),
          ],
          child: MaterialApp(
            title: _title,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.indigo,
            ),
            initialRoute: '/',
            routes: buildRoutes(),
          ),
        );
      },
    );
  }
}
