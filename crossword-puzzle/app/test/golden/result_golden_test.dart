// 07-08-02 2~3절: 결과 골든 — 레벨 1·seed 1000, 빈 DB(첫 제출)에서 정답·
// 오답·빈칸을 각 1개 이상 만든 뒤 제출해 `ResultPage`를 찍는다.
//
// 생성기가 만드는 단어 수·표제어를 이 문서가 알 수 없으므로 하드코딩하지
// 않는다. 대신 `Scorer.solutionOf`(모든 칸 정답)에서 시작해 두 단어의 칸을
// **딱 1칸씩만** 건드린다 — 그것도 다른 어떤 단어와도 겹치지 않는(교차하지
// 않는) 칸만 골라서. 겹치는 칸을 건드리면 그 칸을 공유하는 다른 단어까지
// 함께 오답/빈칸이 돼 버린다(직접 실행해서 드러난 문제 — 처음엔 단어 전체를
// 정답/오답/삭제로 나눠 채웠더니, 레벨 1처럼 단어가 4개뿐인 작은 격자에서는
// 코어 단어 하나를 흠집 내는 것만으로 그 코어와 교차하는 채움 단어들까지
// 줄줄이 빈칸이 되어 정답이 하나도 안 남았다). 단어마다 "자신만의 칸"
// (다른 단어와 안 겹치는 칸)이 최소 1개는 있다는 전제이고, 그 칸 하나만
// 건드리면 이웃 단어는 전혀 손대지 않고도 그 단어 하나만 오답/빈칸으로
// 만들 수 있다.
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jgame/domain/levels.dart';
import 'package:jgame/domain/model/puzzle.dart';
import 'package:jgame/domain/model/submit_result.dart';
import 'package:jgame/domain/scoring/scorer.dart';
import 'package:jgame/ui/puzzle/grid_view.dart';
import 'package:jgame/ui/puzzle/puzzle_page.dart';
import 'package:jgame/ui/result/result_page.dart';
import 'package:jgame/ui/state/puzzle_model.dart';
import 'package:jgame/ui/state/settings_model.dart';

import 'golden_helpers.dart';

/// 다른 음절로. 한글 완성형 코드포인트를 1 옮겨 항상 원래와 다르게 만든다 —
/// 아래 `expect`가 실제로 달라졌는지 못 박는다.
String _shift(String syllable) =>
    String.fromCharCode(syllable.codeUnitAt(0) + 1);

/// [w]의 칸 중 다른 어떤 단어와도 겹치지 않는(=owners가 1인) 칸 1개.
/// 없으면 null — 격자 전체가 교차 칸뿐인 병적인 경우다.
(int, int)? _exclusiveCellOf(PlacedWord w, Map<(int, int), int> owners) {
  for (final c in w.cells) {
    if (owners[c] == 1) return c;
  }
  return null;
}

void main() {
  late Directory tmp;
  var dbSeq = 0;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('result_golden_test_');
    dbSeq = 0;
    SharedPreferences.setMockInitialValues({tutorialSeenPrefsKey: true});
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  for (final (name, mode) in [
    ('light', ThemeMode.light),
    ('dark', ThemeMode.dark),
  ]) {
    testWidgets('결과 골든 — $name', (tester) async {
      final db = openGoldenDb(tmp, seq: dbSeq++);
      addTearDown(db.close);

      await pumpGolden(
        tester,
        PuzzlePage(spec: levels.first, seed: 1000),
        scope: goldenScope(db),
        themeMode: mode,
      );

      expect(find.byType(PuzzleGridView), findsOneWidget);
      final model = Provider.of<PuzzleModel>(
        tester.element(find.byType(PuzzleGridView)),
        listen: false,
      );
      final puzzle = model.puzzle!;
      final words = puzzle.words;
      expect(
        words.length,
        greaterThanOrEqualTo(3),
        reason: '정답·오답·빈칸을 각 1개 이상 만들려면 단어가 3개 이상이어야 '
            '한다(레벨 1은 코어 2 + 채움 최소 2 = 최소 4개)',
      );

      final owners = <(int, int), int>{};
      for (final w in words) {
        for (final c in w.cells) {
          owners[c] = (owners[c] ?? 0) + 1;
        }
      }

      PlacedWord? wrongWord;
      (int, int)? wrongCell;
      PlacedWord? blankWord;
      (int, int)? blankCell;
      for (final w in words) {
        final cell = _exclusiveCellOf(w, owners);
        if (cell == null) continue;
        if (wrongWord == null) {
          wrongWord = w;
          wrongCell = cell;
        } else {
          blankWord = w;
          blankCell = cell;
          break;
        }
      }
      expect(
        wrongWord != null && blankWord != null,
        isTrue,
        reason: '다른 단어와 안 겹치는 칸을 가진 단어가 2개는 있어야 '
            '이웃을 안 건드리고 오답 1개·빈칸 1개를 만들 수 있다',
      );

      final answers = Map<(int, int), String>.of(Scorer.solutionOf(puzzle));
      final corrupted = _shift(answers[wrongCell]!);
      expect(corrupted, isNot(equals(answers[wrongCell])),
          reason: '오답은 정답과 다른 음절이어야 한다');
      answers[wrongCell!] = corrupted;
      answers.remove(blankCell);
      model.answers = answers;

      // play_loop_test.dart(04-07)·submit_test.dart(04-05)와 같은 방식:
      // 제출 버튼은 라벨로 찾는다(빈칸이 있어도 눌린다 — submit_button.dart).
      await tester.tap(find.text('제출'));
      await tester.pumpAndSettle();
      expect(find.textContaining('빈 칸'), findsOneWidget,
          reason: 'blankWord의 칸을 비웠으니 제출 확인 시트가 빈 칸 문구를 보여준다');
      await tester.tap(find.text('제출').last);
      await tester.pumpAndSettle();

      expect(find.byType(ResultPage), findsOneWidget);
      final result = model.result!;
      final outcomes = result.results.map((r) => r.outcome).toSet();
      expect(outcomes, contains(WordOutcome.correct),
          reason: '정답이 1개 이상이어야 한다(오답·빈칸 단어를 뺀 나머지)');
      expect(outcomes, contains(WordOutcome.wrong),
          reason: '오답이 1개 이상이어야 한다');
      expect(outcomes, contains(WordOutcome.blank),
          reason: '빈칸이 1개 이상이어야 한다');
      expect(result.isFirstSubmit, isTrue,
          reason: '빈 DB에서 시작했으므로 첫 제출이어야 한다');
      expect(result.score, greaterThanOrEqualTo(0),
          reason: '해제 배지가 뜨려면 점수가 레벨 1 clearScore(0) 이상이어야 한다');

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/result_$name.png'),
      );
    });
  }
}
