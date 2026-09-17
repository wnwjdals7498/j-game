// 퍼즐 화면 (04-02~04-05 조립). 격자(04-02)·힌트 패널(04-03)·단어 입력(04-04)·
// 제출(04-05)을 하나의 화면으로 묶는다.
//
// [spec]/[seed]가 없으면(예: `/play` 라우트로 직접 진입) 04-01 스텁과 같은
// 안내만 보여준다 — 실제 진입은 홈(04-06)이 레벨과 새 seed를 정해 이 위젯을
// 직접 생성해 `Navigator.push`한다(main.dart "화면 4개 라우트" 주석). `spec`이
// `PuzzleModel`의 `final` 필드라 레벨이 바뀌면(= "다음 레벨") 이 위젯 자체를
// 새로 만들어야 한다 — 그래서 라우트 인자가 아니라 생성자 파라미터로 받는다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/levels.dart';
import '../../domain/model/level_spec.dart';
import '../result/result_page.dart';
import '../state/app_scope.dart';
import '../state/puzzle_model.dart';
import '../state/settings_model.dart';
import 'grid_view.dart';
import 'hint_panel.dart';
import 'word_input.dart';
import 'word_numbering.dart';

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
      create: (context) => PuzzleModel(context.read<AppScope>(), spec)
        ..load(seed ?? newSeed()),
      child: const _PuzzleBody(),
    );
  }
}

class _PuzzleBody extends StatelessWidget {
  const _PuzzleBody();

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

    return Scaffold(
      appBar: AppBar(title: Text(model.spec.name)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: PuzzleGridView(
                    puzzle: puzzle,
                    answers: model.answers,
                    selected: selected,
                    result: model.result,
                    onCellTap: model.selectCell,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              HintPanel(
                selected: selected,
                number: selected == null ? null : numbers[(selected.row, selected.col)],
                hintText: selected == null ? '' : model.hintTextFor(selected, hintMode),
              ),
              const SizedBox(height: 12),
              WordInput(
                selected: selected,
                initialText: selected == null ? '' : model.textOf(selected),
                onChanged: (text) {
                  final w = model.selected;
                  if (w != null) model.setWordInput(w, text);
                },
                onNext: model.selectNextWord,
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => _handleSubmit(context, model),
                  child: const Text('제출'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 제출 → (취소 아니면) 결과 화면으로 이동 (04-05 "제출 흐름").
  /// 채점·통계 반영 자체는 `PuzzleModel.submit`이 맡고, 여기서는 그 결과로
  /// 화면을 전환하는 것만 담당한다.
  Future<void> _handleSubmit(BuildContext context, PuzzleModel model) async {
    await model.submit(context);
    if (!context.mounted) return;
    final result = model.result;
    if (result == null) return; // 다이얼로그에서 "계속 풀기"를 골랐다.

    await Navigator.of(context).push(MaterialPageRoute(
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
    ));
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
      MaterialPageRoute(builder: (_) => PuzzlePage(spec: next, seed: newSeed())),
      (route) => route.isFirst,
    );
  }
}
