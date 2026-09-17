// 출처 및 라이선스 화면 (04-06 "출처 및 라이선스 화면 — 필수").
//
// CC BY-SA 2.0 KR 등 표기 의무 이행 화면. 긴 전문은 `app/assets/LICENSES.md`에
// 번들해 asset으로 그대로 보여준다. 이 파일은 `docs/LICENSES.md`의 사본이고
// `tools/build_sqlite.py`의 `_sync_licenses()`가 `python -m tools build`마다
// 자동으로 복사한다(04-06 "복사를 자동화한다" — 두 파일이 갈라지면 의무 위반).
//
// **`docs/LICENSES.md`는 아직 초안이다** — 00-01(이용 신청, HUMAN)이 각 사이트가
// 요구하는 표기 원문을 확정하기 전까지 `docs/plan/00-01.data-request.md` "docs/
// LICENSES.md 초안 틀"의 자리표시자(`(여기에 사이트가 요구하는 표기 원문 그대로)`
// 등)를 그대로 담고 있다. 04-06은 그 틀을 창작하지 않고 그대로 복사해 화면·복사
// 자동화만 만든다 — 표기 원문 확정은 00-01의 몫이다.
//
// 마크다운 렌더링(`flutter_markdown`)도 링크 탭(`url_launcher`)도 의존성을
// 늘리므로 문서가 명시적으로 미룬 선택이다(04-06 "마크다운 렌더링"/"막히면":
// "1차는 SelectableText로 충분하다"). `SelectableText`로 원문을 그대로 보여주면
// 링크도 복사 가능한 텍스트로 남아 있어 의존성 없이 표기 의무를 충족한다.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class LicenseNoticePage extends StatelessWidget {
  const LicenseNoticePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('출처 및 라이선스')),
      body: FutureBuilder<String>(
        future: loadLicenseText(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('출처 표기를 불러오지 못했습니다.\n${snapshot.error}'),
            );
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(snapshot.data ?? ''),
          );
        },
      ),
    );
  }
}

/// `assets/LICENSES.md`(= `docs/LICENSES.md`의 사본)를 그대로 읽는다.
Future<String> loadLicenseText() => rootBundle.loadString('assets/LICENSES.md');
