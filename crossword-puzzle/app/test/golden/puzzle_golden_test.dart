// 07-08-02 2~3절: 퍼즐 골든 — 레벨 1·seed 1000, 가로 1 선택 + 첫 단어 완성 +
// 두 번째 단어 부분 입력.
//
// 생성기가 어떤 단어를 어디 놓을지 이 문서가 알 수 없으므로 문자열을
// 하드코딩하지 않는다 — 퍼즐에서 조건에 맞는 단어를 고른 뒤 고른 결과를
// `expect`로 못 박는다(문서 2절).
//
// ## 두 번째 단어를 "선택"하지 않고 직접 입력하는 이유
// 문서 2절 표는 "across[1] 선택 후 headword 앞 1글자"라고 적었지만, 4절 눈
// 검수 6번은 "하늘색 선택 띠가 가로 1 단어 전체를 덮는다"를 요구한다. 모델의
// 선택은 항상 단어 하나뿐이라(`PuzzleModel.selected`), across[1]을 탭으로
// 다시 선택하면 선택 띠가 거기로 옮겨가 6번 항목을 못 맞춘다. 그래서 across[1]
// 부분 입력은 탭 없이 `PuzzleModel.setWordInput`을 직접 불러 만든다 — 실제
// `WordInput.onChanged`가 부르는 것과 같은 메서드라 격자에 반영되는 결과는
// 동일하고, 선택 상태(따라서 선택 띠)만 across[0]에 그대로 남는다.
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jgame/domain/levels.dart';
import 'package:jgame/domain/model/puzzle.dart';
import 'package:jgame/ui/puzzle/grid_view.dart';
import 'package:jgame/ui/puzzle/puzzle_page.dart';
import 'package:jgame/ui/state/puzzle_model.dart';
import 'package:jgame/ui/state/settings_model.dart';

import 'golden_helpers.dart';

/// play_loop_test.dart(04-07)와 같은 방식: 격자 위젯의 실제 렌더 크기로 셀
/// 중심 좌표를 구한다. 고정 좌표를 쓰지 않는다.
Offset _cellCenter(WidgetTester tester, Puzzle puzzle, int row, int col) {
  final topLeft = tester.getTopLeft(find.byType(PuzzleGridView));
  final size = tester.getSize(find.byType(PuzzleGridView));
  final cell = size.width / puzzle.width;
  return topLeft + Offset(cell * (col + 0.5), cell * (row + 0.5));
}

void main() {
  late Directory tmp;
  var dbSeq = 0;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('puzzle_golden_test_');
    dbSeq = 0;
    // 튜토리얼 시트(07-04-04)가 퍼즐 화면을 덮지 않게 이미 본 것으로
    // 표시한다 — puzzle_screen_test.dart·play_loop_test.dart와 같은 이유.
    SharedPreferences.setMockInitialValues({tutorialSeenPrefsKey: true});
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  for (final (name, mode) in [
    ('light', ThemeMode.light),
    ('dark', ThemeMode.dark),
  ]) {
    testWidgets('퍼즐 골든 — $name', (tester) async {
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

      final across = puzzle.words.where((w) => w.dir == Direction.across).toList()
        ..sort((a, b) =>
            a.row != b.row ? a.row.compareTo(b.row) : a.col.compareTo(b.col));
      expect(
        across.length,
        greaterThanOrEqualTo(2),
        reason: '골든 장면은 가로 단어 2개 이상을 전제한다(레벨 1·seed 1000)',
      );
      // 문서 2절 스니펫은 across[0]이 2음절이라고 가정하지만(진행 배지가
      // "1 / N"이 되는 데는 무관하다 — 완성된 단어가 몇 음절이든 필드 하나가
      // 채워지면 filledWordCount는 그대로 1이다), 실제 seed 1000 생성 결과는
      // 그렇지 않다. "막히면" 절의 지시대로 seed는 그대로 두고 선택식만
      // 고친다 — 길이를 못 박지 않고 실제 길이를 그대로 쓴다.
      expect(
        across[1].length,
        greaterThanOrEqualTo(2),
        reason: '두 번째 단어가 1음절이면 1글자만 넣어도 완성돼 버려 '
            '"부분 입력" 장면을 만들 수 없다',
      );

      // 가로 1 선택 — 탭으로 선택해야 선택 띠·커서가 실제로 표시된다.
      final first = across[0];
      final (fr, fc) = first.cells.first;
      await tester.tapAt(_cellCenter(tester, puzzle, fr, fc));
      await tester.pumpAndSettle();
      expect(model.selected, isNotNull);
      expect(model.focusedCell, (fr, fc),
          reason: '커서 = 첫 셀(선택 직후 기본 커서 위치)');

      // 첫 단어 입력 완료.
      await tester.enterText(find.byType(TextField), first.headword);
      await tester.pumpAndSettle();

      // 두 번째 단어 부분 입력(선택 띠는 그대로 across[0]에 둔다 — 위 주석).
      final second = across[1];
      model.setWordInput(second, second.headword.substring(0, 1));
      await tester.pumpAndSettle();

      expect(
        model.filledWordCount,
        1,
        reason: '진행 배지 `1 / N` — 첫 단어만 완전히 채워졌다',
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/puzzle_$name.png'),
      );
    });
  }
}
