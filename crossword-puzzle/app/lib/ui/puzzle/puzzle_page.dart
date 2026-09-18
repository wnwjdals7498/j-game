// 퍼즐 화면 (04-02~04-05 조립). 격자(04-02)·힌트 패널(04-03)·단어 입력(04-04)·
// 제출(04-05)을 하나의 화면으로 묶는다.
//
// [spec]/[seed]가 없으면(예: `/play` 라우트로 직접 진입) 04-01 스텁과 같은
// 안내만 보여준다 — 실제 진입은 홈(04-06)이 레벨과 새 seed를 정해 이 위젯을
// 직접 생성해 `Navigator.push`한다(main.dart "화면 4개 라우트" 주석). `spec`이
// `PuzzleModel`의 `final` 필드라 레벨이 바뀌면(= "다음 레벨") 이 위젯 자체를
// 새로 만들어야 한다 — 그래서 라우트 인자가 아니라 생성자 파라미터로 받는다.
//
// 07-04-05: 햅틱 H-01~H-03은 전부 여기(페이지 위젯)에서만 부른다 —
// `PuzzleModel`은 플랫폼 서비스를 몰라야 모델 단위 테스트가 바인딩 없이
// 돌아간다.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/levels.dart';
import '../../domain/model/level_spec.dart';
import '../../domain/model/puzzle.dart';
import '../result/result_page.dart';
import '../state/app_scope.dart';
import '../state/puzzle_model.dart';
import '../state/settings_model.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'clue_bar.dart';
import 'grid_view.dart';
import 'puzzle_sheets.dart';
import 'submit_button.dart';
import 'word_input.dart';
import 'word_numbering.dart';

/// 제출 버튼 고정 높이 (UI-GUIDE 2.5 "버튼 규격").
const _submitButtonHeight = 52.0;

/// 키보드가 뜬 상태(`hintMaxLines`가 1로 접힌 이후)의 [ClueBar] 대략 높이 —
/// 헤더 행(아이콘 버튼 탭 영역 48) + 힌트 1줄 + 입력 필드, 픽셀 단위로 정확할
/// 필요는 없다(아래 "왜 세로도 보는가" 참고, 과대추정 쪽으로 안전하다).
const _estimatedClueBarHeight = 180.0;

/// 키보드가 뜬 상태에서 좌우 여백을 접을지 판단하기 위한 추정 셀 크기
/// (07-04-05, 04-02 "셀 크기 하한": 폰트를 줄이지 말고 여백을 줄인다).
///
/// ## 왜 세로도 보는가
/// 격자는 정사각형이고 [PuzzleGridView]가 가로·세로 중 좁은 쪽에 맞춘다(07-03
/// "side = maxWidth.clamp(0, maxHeight)"). 가로 폭만 보는 추정은 화면이 넓고
/// 낮은 상황(작은 폰의 8×8 + 키보드)에서 실제 병목이 세로인데도 "충분하다"고
/// 잘못 판정한다 — 07-08-03 리포트 전 검증에서 실측으로 드러난 문제다. 그래서
/// [availableHeight]도 함께 받아 더 좁은 쪽을 기준으로 삼는다.
double _estimatedCell(
  Puzzle puzzle, {
  required double availableWidth,
  required double availableHeight,
}) {
  final side = min(availableWidth, availableHeight);
  return side / max(puzzle.width, puzzle.height);
}

class PuzzlePage extends StatelessWidget {
  final LevelSpec? spec;
  final int? seed;

  const PuzzlePage({super.key, this.spec, this.seed});

  @override
  Widget build(BuildContext context) {
    final spec = this.spec;
    if (spec == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('퍼즐')),
        body: const Center(child: Text('레벨 정보가 없습니다')),
      );
    }
    return ChangeNotifierProvider<PuzzleModel>(
      create: (context) =>
          PuzzleModel(context.read<AppScope>(), spec)..load(seed ?? newSeed()),
      child: const _PuzzleBody(),
    );
  }
}

class _PuzzleBody extends StatefulWidget {
  const _PuzzleBody();

  @override
  State<_PuzzleBody> createState() => _PuzzleBodyState();
}

class _PuzzleBodyState extends State<_PuzzleBody> {
  /// 퍼즐이 뜬 뒤 한 번만 확인하면 되므로, 이미 확인했으면(퍼즐 로딩 중
  /// build가 여러 번 불려도) 다시 SharedPreferences를 안 친다.
  bool _tutorialChecked = false;

  /// 최초 진입 조작법 안내. 첫 퍼즐 화면에서 한 번만 보여준다 — 04-03의
  /// "교차 셀을 다시 탭하면 세로로 토글" 같은, 화면만 봐서는 알기 어려운
  /// 조작을 짚어 준다.
  Future<void> _maybeShowTutorial() async {
    if (_tutorialChecked) return;
    _tutorialChecked = true;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(tutorialSeenPrefsKey) ?? false) return;
    await prefs.setBool(tutorialSeenPrefsKey, true);
    if (!mounted) return;
    await showTutorialSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    final model = context.watch<PuzzleModel>();

    if (model.loading) {
      return Scaffold(
        appBar: AppBar(title: Text(model.spec.name)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final puzzle = model.puzzle;
    if (model.error != null || puzzle == null) {
      return Scaffold(
        appBar: AppBar(title: Text(model.spec.name)),
        body: Center(child: Text('퍼즐을 만들지 못했습니다.\n${model.error}')),
      );
    }

    final hintMode = context.watch<SettingsModel>().hintMode;
    final numbers = numberCells(puzzle);
    final selected = model.selected;

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowTutorial());

    // 07-04-05 키보드 대응: 키보드가 뜨면 힌트를 1줄로 접는다. 그래도
    // 추정 셀이 36dp 미만이면 좌우 여백까지 8로 줄인다(04-02 "셀 크기
    // 하한"). 스크롤·줌은 N-03이 금지하므로 그 이상은 07-08-03 리포트로
    // 넘긴다. `LayoutBuilder`의 constraints는 AppBar·SafeArea·키보드
    // (`resizeToAvoidBottomInset` 기본값 true)를 이미 뺀 값이라, 세로 쪽
    // 병목도 따로 화면 높이를 다시 계산하지 않고 그대로 쓸 수 있다.
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    final hintMaxLines = keyboardUp ? 1 : 3;

    return Scaffold(
      appBar: AppBar(
        title: Text(model.spec.name),
        actions: [
          _ProgressBadge(
            filled: model.filledWordCount,
            total: puzzle.words.length,
            allFilled: model.allFilled,
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final verticalChrome =
                GameSpace.m * 2 /* 외곽 패딩 */ +
                GameSpace.m * 2 /* SizedBox 2개 */ +
                _estimatedClueBarHeight +
                _submitButtonHeight;
            final horizontalPadding =
                keyboardUp &&
                    _estimatedCell(
                          puzzle,
                          availableWidth:
                              constraints.maxWidth - GameSpace.l * 2,
                          availableHeight:
                              constraints.maxHeight - verticalChrome,
                        ) <
                        36
                ? GameSpace.s
                : GameSpace.l;
            return Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: GameSpace.m,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: PuzzleGridView(
                        puzzle: puzzle,
                        answers: model.answers,
                        selected: selected,
                        result: model.result,
                        focusedCell: model.focusedCell,
                        onCellTap: (r, c) {
                          // H-01: 탭으로 선택된 단어가 실제로 바뀔 때만 1회.
                          // `PlacedWord`는 `==`를 재정의하지 않으므로(01-01)
                          // 인스턴스 비교로 판정한다.
                          final before = model.selected;
                          model.selectCell(r, c);
                          if (!identical(model.selected, before)) {
                            HapticFeedback.selectionClick();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: GameSpace.m),
                  ClueBar(
                    selected: selected,
                    number: selected == null
                        ? null
                        : numbers[(selected.row, selected.col)],
                    hintText: selected == null
                        ? ''
                        : model.hintTextFor(selected, hintMode),
                    onPrev: model.selectPrevWord,
                    onNext: model.selectNextWord,
                    hintMaxLines: hintMaxLines,
                    child: WordInput(
                      selected: selected,
                      initialText: selected == null
                          ? ''
                          : model.textOf(selected),
                      onChanged: (text) {
                        // H-02: 이 입력으로 현재 선택된 단어가 방금 꽉 찼을 때만
                        // 1회(직전엔 아니었어야 한다).
                        final w = model.selected;
                        if (w == null) return;
                        final wasFull = model.textOf(w).length == w.length;
                        model.setWordInput(w, text);
                        if (!wasFull && model.textOf(w).length == w.length) {
                          HapticFeedback.lightImpact();
                        }
                      },
                      onNext: model.selectNextWord,
                    ),
                  ),
                  const SizedBox(height: GameSpace.m),
                  SubmitButton(
                    active: model.allFilled,
                    onPressed: () => _handleSubmit(context, model),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// 제출 → (취소 아니면) 결과 화면으로 이동 (04-05 "제출 흐름").
  /// 채점·통계 반영 자체는 `PuzzleModel.submit`이 맡고, 여기서는 그 결과로
  /// 화면을 전환하는 것만 담당한다.
  Future<void> _handleSubmit(BuildContext context, PuzzleModel model) async {
    // H-03: 확인 버튼 탭이 아니라 `submit` 반환 직후 — 제출 확인 시트는
    // `PuzzleModel.submit(context)` 안에서 뜨므로(07-04-04) 페이지는 확인
    // 탭 순간을 볼 수 없다. "결과가 새로 생겼는가"로 판정한다 — 재제출도
    // 새 인스턴스라 울리고, "계속 풀기"·DB 오류 경로는 `result`가 그대로라
    // 울리지 않는다.
    final before = model.result;
    await model.submit(context);
    if (!identical(model.result, before)) HapticFeedback.mediumImpact();
    if (!context.mounted) return;
    final result = model.result;
    if (result == null) return; // 다이얼로그에서 "계속 풀기"를 골랐다.

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ResultPage(
          spec: model.spec,
          puzzle: model.puzzle,
          result: result,
          hints: model.hints,
          onRetry: () {
            model.retry();
            Navigator.of(context).pop();
          },
          onNextLevel: () => _goToNextLevel(context, model.spec),
        ),
      ),
    );
  }

  /// "다음 레벨" (04-05 "버튼 동작"): 다음 레벨을 새 seed로 생성. 결과·현재
  /// 화면을 전부 걷어내고(`pushAndRemoveUntil`) 새 퍼즐 화면 하나만 남긴다 —
  /// 되돌아가도 이미 끝난 퍼즐이 다시 보이지 않게 하기 위함. 마지막 레벨이면
  /// 홈으로 (첫 라우트까지 pop).
  void _goToNextLevel(BuildContext context, LevelSpec current) {
    final next = nextLevelOf(current);
    if (next == null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => PuzzlePage(spec: next, seed: newSeed()),
      ),
      (route) => route.isFirst,
    );
  }
}

/// 진행 배지 (07-04-03 "진행 배지"). AppBar `actions`에 놓는다 — 재사용할
/// 곳이 없어 이 파일 안의 private 위젯으로 둔다.
class _ProgressBadge extends StatelessWidget {
  final int filled; // model.filledWordCount
  final int total; // puzzle.words.length
  final bool allFilled; // model.allFilled — filled == total과 다를 수 있다

  const _ProgressBadge({
    required this.filled,
    required this.total,
    required this.allFilled,
  });

  @override
  Widget build(BuildContext context) {
    final c = GameColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: GameSpace.l),
      child: AnimatedSwitcher(
        duration: GameMotion.of(context).fast, // 배지 교체: fast (UI-GUIDE 3.1)
        child: Row(
          key: ValueKey('$filled/$total/$allFilled'),
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$filled / $total',
              style: GameType.label.copyWith(color: c.inkMuted),
            ),
            if (allFilled) ...[
              const SizedBox(width: GameSpace.xs),
              Icon(
                Icons.check,
                size: GameSpace.l,
                color: c.success,
              ), // 16 = GameSpace.l
            ],
          ],
        ),
      ),
    );
  }
}
