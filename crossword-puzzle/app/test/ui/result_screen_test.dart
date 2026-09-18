// test/ui/result_screen_test.dart
//
// 결과 화면 위젯 테스트. 07-06 세 문서에 걸쳐 자란다 — 뼈대(`_result`,
// `pumpHeader`)와 07-06-01 몫 5종을 여기서 만든다. 07-06-02가 2종,
// 07-06-03이 4종을 더해 최종 11종이 된다(07-06-01 "테스트" 절).
//
// `ScoreHeader`는 `PuzzleModel`·`ResultPage` 없이 단독으로 pump한다 —
// result_page.dart 주석의 "표시 전용 위젯" 원칙과 같은 결이다.
//
// 07-06-02가 더하는 두 테스트(E-07 순차 등장·행이 많아도 총 slow)와, 기존
// "감소 모션" 테스트에 더한 단언은 `ResultPage`를 통째로 pump한다 — E-07은
// 페이지 컨트롤러(`_ResultPageState._rows`)가 있어야 재현되기 때문이다.
// 이때 쓰는 픽스처는 순서·번호(submit_test.dart "결과 목록…" 몫)가 아니라
// 등장 타이밍만 본다: `puzzle`은 단어가 없는 최소 유효 격자로 두고, 결과 행은
// `WordResult`가 필요로 하는 `PlacedWord`만 채워 만든다(번호는 `numberCells`가
// 못 채워 `null`이어도 된다, 07-06-02 "12행 픽스처" 절).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jgame/domain/levels.dart';
import 'package:jgame/domain/model/level_spec.dart';
import 'package:jgame/domain/model/puzzle.dart';
import 'package:jgame/domain/model/submit_result.dart';
import 'package:jgame/ui/result/result_page.dart';
import 'package:jgame/ui/result/score_header.dart';
import 'package:jgame/ui/result/unlock_burst.dart';
import 'package:jgame/ui/result/word_result_card.dart';
import 'package:jgame/ui/theme/app_theme.dart';
import 'package:jgame/ui/theme/motion.dart';

/// score/correct/total만 바꿔 가며 [ScoreHeader]를 만드는 헬퍼. 해제 배지·
/// 재제출 안내는 이 문서 몫 테스트의 관심사가 아니므로 기본값(둘 다 아님)을
/// 쓴다 — 그 조합은 `submit_test.dart`의 `결과 화면 (ResultPage)` 그룹이
/// 이미 검증한다.
ScoreHeader _result({required int score, required int correct, required int total}) =>
    ScoreHeader(
      score: score,
      correct: correct,
      total: total,
      isFirstSubmit: true,
      justUnlocked: false,
    );

/// [header]를 라이트 테마 아래 단독으로 pump한다. `GameColors.of`/
/// `GameMotion.of`가 테마를 읽으므로 `buildLightTheme()`이 필요하다
/// (`grid_view_test.dart`(07-03-03)와 같은 패턴).
Future<void> pumpHeader(
  WidgetTester tester,
  ScoreHeader header, {
  bool disableAnimations = false,
}) {
  return tester.pumpWidget(MaterialApp(
    theme: buildLightTheme(),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: Scaffold(body: header),
    ),
  ));
}

/// 트리 안의 `CustomPaint` 중 링 진행값(`progress` getter)을 가진 것을
/// 찾는다. `_RingPainter`는 private이라 타입으로 직접 못 찾으므로, "막히면"
/// 절의 안내대로 `progress` 필드를 동적으로 읽어 판별한다.
double _ringProgress(WidgetTester tester) {
  for (final w in tester.widgetList<CustomPaint>(find.byType(CustomPaint))) {
    final painter = w.painter;
    if (painter == null) continue;
    try {
      return (painter as dynamic).progress as double;
    } catch (_) {
      continue;
    }
  }
  fail('링 페인터(_RingPainter)를 찾지 못했습니다');
}

/// `ResultPage`가 폴백 화면으로 빠지지 않게 하는 최소 유효 퍼즐. 단어 목록은
/// 비워 둔다 — 이 파일의 테스트는 순서·번호(submit_test.dart "결과 목록…" 몫)가
/// 아니라 E-06/E-07 타이밍만 본다.
Puzzle _emptyPuzzle() => const Puzzle(
      levelId: 1,
      width: 1,
      height: 1,
      cells: [
        [Cell.blocked()],
      ],
      words: [],
      seed: 1,
      attempts: 1,
    );

/// [count]개의 결과 행(전부 정답)을 만든다. `puzzle.words`에는 없는
/// `PlacedWord`를 직접 붙인다 — `numberCells`가 못 채워 번호가 `null`이어도
/// 되기 때문이다(07-06-02 "12행 픽스처" 절). 좌표만 한 줄씩 내려 서로 겹치지
/// 않게 한다.
SubmitResult _rowsResult(int count) => SubmitResult(
      [
        for (var i = 0; i < count; i++)
          WordResult(
            PlacedWord(
                headword: '단어$i',
                row: i,
                col: 0,
                dir: Direction.across,
                isCore: false,
                tier: 1),
            '단어$i',
            WordOutcome.correct,
          ),
      ],
      isFirstSubmit: true,
    );

/// [result]를 담은 `ResultPage`를 라이트 테마 아래 단독으로 pump한다.
///
/// 기본 테스트 표면(800×600)은 결과 행이 여러 개면 다 담기지 않아
/// `ListView`가 화면에 보이는 것만 빌드한다 — 12행 테스트가 마지막 행(E-07의
/// 마지막 구간)을 보려면 전부 빌드돼야 하므로 표면을 넉넉히 키우고, 테스트가
/// 끝나면 되돌린다.
///
/// [spec]은 기본 `levels.first`(다음 레벨 있음) — 07-06-03의 "마지막 레벨"
/// 표시 조건 케이스만 `levels.last`를 넘긴다. `levels.first`는 상수 표현식이
/// 아니라(`const List`의 `.first` getter) 매개변수 기본값으로 못 쓰므로
/// nullable로 받아 본문에서 채운다.
Future<void> _pumpResult(
  WidgetTester tester,
  SubmitResult result, {
  LevelSpec? spec,
  bool disableAnimations = false,
  VoidCallback? onNextLevel,
}) async {
  await tester.binding.setSurfaceSize(const Size(800, 3000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: buildLightTheme(),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: disableAnimations),
      child: ResultPage(
        spec: spec ?? levels.first,
        puzzle: _emptyPuzzle(),
        result: result,
        onNextLevel: onNextLevel,
      ),
    ),
  ));
}

/// E-08 고정: 첫 제출로 해제되는 최소 결과 (정답 1개 → score 1 >= clearScore
/// 기본값 0). [isFirstSubmit]을 false로 주면 "재제출" 케이스가 된다.
SubmitResult _unlockedResult({bool isFirstSubmit = true}) => SubmitResult(
      [
        WordResult(
          const PlacedWord(
              headword: '단어',
              row: 0,
              col: 0,
              dir: Direction.across,
              isCore: false,
              tier: 1),
          '단어',
          WordOutcome.correct,
        ),
      ],
      isFirstSubmit: isFirstSubmit,
    );

/// E-08 고정: 점수 미달 결과 (오답 1개 → score -1 < clearScore 기본값 0).
SubmitResult _belowClearResult() => SubmitResult(
      [
        WordResult(
          const PlacedWord(
              headword: '단어',
              row: 0,
              col: 0,
              dir: Direction.across,
              isCore: false,
              tier: 1),
          '오답',
          WordOutcome.wrong,
        ),
      ],
      isFirstSubmit: true,
    );

/// 결과 행(`WordResultCard`)마다의 `FadeTransition.opacity.value` (등장
/// 진행값). `MaterialApp`/`Scaffold`가 자체 라우트 전환에도 `FadeTransition`을
/// 쓰므로, 트리 전체가 아니라 `WordResultCard` 안의 것만 골라야 한다.
List<double> _rowOpacities(WidgetTester tester) => tester
    .widgetList<FadeTransition>(find.descendant(
        of: find.byType(WordResultCard), matching: find.byType(FadeTransition)))
    .map((w) => w.opacity.value)
    .toList();

void main() {
  group('결과 화면 (ResultPage) · ScoreHeader', () {
    testWidgets('E-06 카운트업 종료값', (tester) async {
      await pumpHeader(tester, _result(score: 12, correct: 5, total: 7));
      await tester.pumpAndSettle();

      expect(find.text('+12'), findsOneWidget);
      expect(find.text('5 / 7 정답'), findsOneWidget);
    });

    testWidgets('E-06 중간값', (tester) async {
      await pumpHeader(tester, _result(score: 12, correct: 5, total: 7));
      await tester.pump();
      expect(find.text('+0'), findsOneWidget);

      await tester.pump(GameMotion.standard.celebrate ~/ 2);
      expect(find.text('+0'), findsNothing);
      expect(find.text('+12'), findsNothing);
    });

    testWidgets('음수 점수: 0에서 시작해 -3으로', (tester) async {
      await pumpHeader(tester, _result(score: -3, correct: 2, total: 5));
      await tester.pump();
      expect(find.text('+0'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('-3'), findsOneWidget);
    });

    testWidgets('링 진행: 종료 시 correct/total', (tester) async {
      await pumpHeader(tester, _result(score: 12, correct: 5, total: 7));
      await tester.pumpAndSettle();
      expect(_ringProgress(tester), closeTo(5 / 7, 0.001));

      // total == 0이면 링 진행 0, 나눗셈 예외 없음.
      await pumpHeader(tester, _result(score: 0, correct: 0, total: 0));
      await tester.pumpAndSettle();
      expect(_ringProgress(tester), 0.0);
    });

    testWidgets('감소 모션: 첫 프레임에 최종 점수', (tester) async {
      await pumpHeader(tester, _result(score: 12, correct: 5, total: 7),
          disableAnimations: true);
      await tester.pump();
      expect(find.text('+12'), findsOneWidget);

      // 07-06-02 단언 추가: `ResultPage`째로 pump해 결과 행(E-07)도 같은
      // 감소 모션 아래서 첫 프레임부터 전부 opacity 1인지 본다 — 페이지
      // 컨트롤러(`_ResultPageState._rows`)가 있어야 재현되므로 `ScoreHeader`
      // 단독 pump로는 볼 수 없다. `motion.slow == 0`이면 `_rowAnimation`이
      // `kAlwaysCompleteAnimation`으로 빠져야 한다(NaN 없이).
      await _pumpResult(tester, _rowsResult(3), disableAnimations: true);
      await tester.pump();
      expect(find.text('+3'), findsOneWidget);
      final opacities = _rowOpacities(tester);
      expect(opacities.length, 3);
      expect(opacities, everyElement(1.0));
    });
  });

  group('결과 화면 (ResultPage) · E-07 순차 등장', () {
    testWidgets('E-07 순차 등장', (tester) async {
      await _pumpResult(tester, _rowsResult(3));

      // 3행: gap = min(40, (400-150)/2) = 40ms. 행0 구간 0~0.375, 즉 `fast`
      // (150ms)를 pump하면 행0은 딱 끝(opacity ≈ 1), 마지막 행은 아직 진행 중.
      // `closeTo`를 쓰는 이유: 컨트롤러 값(`150/400`)과 행0 구간의 `end`
      // (`(0*40+150)/400`)는 수학적으로 같아도 서로 다른 나눗셈으로 구해져
      // 부동소수 1비트 차이가 날 수 있고, `curveStandard`(`Cubic`)가 그 미세한
      // 차이를 경계 근처에서 조금 증폭한다 — 컨트롤러가 진짜 끝(1.0)에 닿았을
      // 때만 쓰는 `CurvedAnimation`의 0/1 지름길(다음 assert에서 확인)을 아직
      // 못 타서 그렇다.
      await tester.pump(GameMotion.standard.fast);
      final midway = _rowOpacities(tester);
      expect(midway.length, 3);
      expect(midway.first, closeTo(1.0, 1e-3));
      expect(midway.last, lessThan(1.0));

      // 두 번째 pump를 `slow` 길이만큼 더 주는 방식은 (150+400=550ms 누적)
      // 컨트롤러가 "거의 다 끝났지만 부동소수 오차로 1.0에 못 미치는" 상태를
      // 만들어 플레이키했다 — grid_view_test.dart(07-03-03)와 같은 이유로
      // `pumpAndSettle()`을 쓴다(정확히 컨트롤러 길이만큼 pump하다 플레이키해진
      // 경우의 표준 해법). 컨트롤러가 완전히 멈추면 `_rows.value`가 정확히
      // 1.0이 되어 위 지름길을 타므로 여기는 엄격히 1.0과 비교해도 된다.
      await tester.pumpAndSettle();
      expect(_rowOpacities(tester), everyElement(1.0));
    });

    testWidgets('E-07 행이 많아도 총 slow', (tester) async {
      await _pumpResult(tester, _rowsResult(12));

      // 12행: gap이 40ms 상한 대신 (400-150)/11 ≈ 22.7ms로 줄어 마지막 행
      // 구간이 정확히 slow(400ms) 끝에 맞춰진다 — `pump(slow)` 한 번으로 전부
      // 끝나야 한다(07-06-02 4절 표).
      await tester.pump(GameMotion.standard.slow);
      final opacities = _rowOpacities(tester);
      expect(opacities.length, 12);
      expect(opacities, everyElement(1.0));
    });
  });

  group('결과 화면 (ResultPage) · E-08 해제 연출', () {
    testWidgets('E-08 표시 조건', (tester) async {
      // 1절 표: 첫 제출로 해제 → 표시.
      await _pumpResult(tester, _unlockedResult(), disableAnimations: true);
      await tester.pump();
      expect(find.byType(UnlockBurst), findsOneWidget);

      // 재제출 → 없음.
      await _pumpResult(tester, _unlockedResult(isFirstSubmit: false),
          disableAnimations: true);
      await tester.pump();
      expect(find.byType(UnlockBurst), findsNothing);

      // 점수 미달 → 없음.
      await _pumpResult(tester, _belowClearResult(), disableAnimations: true);
      await tester.pump();
      expect(find.byType(UnlockBurst), findsNothing);

      // 마지막 레벨(다음 없음) → 없음.
      await _pumpResult(tester, _unlockedResult(),
          spec: levels.last, disableAnimations: true);
      await tester.pump();
      expect(find.byType(UnlockBurst), findsNothing);
    });

    testWidgets('E-08 1회만 재생', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildLightTheme(),
        home: StatefulBuilder(
          builder: (context, setState) => Column(children: [
            ElevatedButton(
                onPressed: () => setState(() {}),
                child: const Text('rebuild')),
            Expanded(
              child: ResultPage(
                spec: levels.first,
                puzzle: _emptyPuzzle(),
                result: _unlockedResult(),
              ),
            ),
          ]),
        ),
      ));
      await tester.pumpAndSettle();
      expect(
          find.descendant(
              of: find.byType(UnlockBurst), matching: find.byType(SizedBox)),
          findsOneWidget,
          reason: '재생이 끝나면 SizedBox.shrink() 하나로 접힌다');

      // 부모 setState 강제. `UnlockBurst`의 State가 유지되므로 `_started`가
      // true로 남아 재생되지 않는다(07-06-03 "테스트" 절).
      await tester.tap(find.text('rebuild'));
      await tester.pump();

      expect(
          find.descendant(
              of: find.byType(UnlockBurst), matching: find.byType(SizedBox)),
          findsOneWidget,
          reason: '부모 rebuild 후에도 다시 재생되지 않아야 한다');
    });

    test('E-08 결정성', () {
      final a = buildBurstPieces();
      final b = buildBurstPieces();
      expect(a, equals(b));
      expect(a.length, 24);
      for (var i = 0; i < 3; i++) {
        expect(a.where((p) => p.colorIndex == i).length, 8,
            reason: 'colorIndex $i는 정확히 8개');
      }
    });

    testWidgets('E-08이 버튼 탭을 막지 않는다', (tester) async {
      var called = false;
      await _pumpResult(tester, _unlockedResult(),
          onNextLevel: () => called = true);
      await tester.pump();

      await tester.tap(find.text('다음 레벨'));
      expect(called, isTrue);
    });
  });
}
