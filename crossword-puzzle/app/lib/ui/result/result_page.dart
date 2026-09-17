// 결과 화면 (04-05.submit-and-result.md "결과 화면").
//
// 순수 표시 위젯이다. `PuzzleModel`을 직접 들고 있지 않고 필요한 값(스펙·격자·
// 채점 결과·힌트)만 생성자로 받는다 — `submit_test.dart`가 `PuzzleModel`이나
// `Navigator` 없이 이 화면만 단독으로 pump해 검증할 수 있게 하기 위해서다
// (04-04 `WordInput`이 표시 로직만 받는 것과 같은 결이다).
// `PuzzleModel.hintTextFor`와 달리 뜻풀이를 가리지 않는다 — "뜻풀이" 절:
// "마스킹하지 않은 원문. 답을 이미 알았으므로".
//
// [spec]/[puzzle]/[result] 중 하나라도 없으면(예: `/result` 라우트로 직접
// 진입) 04-01 스텁과 동일한 안내만 보여준다. 실제 진입은 `PuzzlePage`가
// `Navigator.push`로 이 값들을 채워 넘긴다(04-05 "제출 흐름").
import 'package:flutter/material.dart';

import '../../data/hint_repository.dart';
import '../../domain/levels.dart';
import '../../domain/model/level_spec.dart';
import '../../domain/model/puzzle.dart';
import '../../domain/model/submit_result.dart';
import '../puzzle/word_numbering.dart';

class ResultPage extends StatelessWidget {
  final LevelSpec? spec;
  final Puzzle? puzzle;
  final SubmitResult? result;

  /// 표제어 → 힌트 (`PuzzleModel.hints`, 04-03). 뜻풀이·유의어 표시에 쓴다.
  final Map<String, Hint> hints;

  /// "다시 풀기" 탭 콜백. 호출부(`PuzzlePage`)가 `PuzzleModel.retry()` +
  /// `Navigator.pop`을 묶어 넘긴다.
  final VoidCallback? onRetry;

  /// "다음 레벨"(마지막 레벨이면 "홈으로") 탭 콜백.
  final VoidCallback? onNextLevel;

  const ResultPage({
    super.key,
    this.spec,
    this.puzzle,
    this.result,
    this.hints = const {},
    this.onRetry,
    this.onNextLevel,
  });

  @override
  Widget build(BuildContext context) {
    final spec = this.spec;
    final puzzle = this.puzzle;
    final result = this.result;
    if (spec == null || puzzle == null || result == null) {
      // 04-01 스텁과 같은 폴백. `/result`로 직접 진입(테스트 포함)했을 때만
      // 보인다 — 실제 플레이 흐름은 항상 값을 채워 넘긴다.
      return Scaffold(
        appBar: AppBar(title: const Text('결과')),
        body: const Center(child: Text('결과 없음')),
      );
    }

    final colors = Theme.of(context).colorScheme;
    final numbers = numberCells(puzzle);
    // 정렬: 번호 순(격자 위→아래, 왼→오른쪽) 유지 — 04-05 "정렬" 절.
    // `puzzle.words`(=Scorer가 순회한 순서)는 코어/채움 배치 순서라 격자
    // 위치 순서와 다를 수 있다.
    final rows = result.results.toList()
      ..sort((a, b) {
        final byRow = a.word.row.compareTo(b.word.row);
        return byRow != 0 ? byRow : a.word.col.compareTo(b.word.col);
      });

    // 레벨 해제 (04-05 "레벨 해제"): score >= clearScore면 다음 레벨 해제.
    // "해제 순간"만 안내한다 — 재제출은 puzzle_log/word_stat에 반영되지 않아
    // (03-04) bestScore가 바뀌지 않으므로, 첫 제출일 때만 배너를 띄운다.
    final next = nextLevelOf(spec);
    final justUnlocked =
        result.isFirstSubmit && result.score >= spec.clearScore && next != null;

    return Scaffold(
      appBar: AppBar(title: Text('레벨 ${spec.id} · ${spec.name}')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${result.correctCount} / ${result.total} 정답'
                  '    점수 ${result.score >= 0 ? '+' : ''}${result.score}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (!result.isFirstSubmit)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 16, color: colors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text('재제출이라 기록에 반영되지 않았습니다',
                            style: TextStyle(color: colors.onSurfaceVariant)),
                      ],
                    ),
                  ),
                if (justUnlocked)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '레벨 ${next.id}이 열렸습니다',
                      style: TextStyle(
                          color: colors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final wr = rows[i];
                return _WordRow(
                  wordResult: wr,
                  number: numbers[(wr.word.row, wr.word.col)],
                  hint: hints[wr.word.headword],
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onRetry,
                    child: const Text('다시 풀기'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: onNextLevel,
                    // 마지막 레벨은 버튼 자체가 "홈으로"를 알린다 — 04-05
                    // "버튼 동작": "마지막 레벨이면 홈으로".
                    child: Text(next == null ? '홈으로' : '다음 레벨'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 결과 목록 한 줄: 상태 아이콘 + 번호·표제어 + (오답/빈칸이면) 입력값 +
/// 뜻풀이(마스킹 없음) + 유의어(있으면).
class _WordRow extends StatelessWidget {
  final WordResult wordResult;
  final int? number;
  final Hint? hint;

  const _WordRow({required this.wordResult, required this.number, required this.hint});

  @override
  Widget build(BuildContext context) {
    final w = wordResult.word;
    final colors = Theme.of(context).colorScheme;
    final (icon, color) = switch (wordResult.outcome) {
      // 색만으로 구분하지 않는다 — 04-02 GridPainter와 같은 원칙, 모양도 다르다.
      WordOutcome.correct => (Icons.check_circle, colors.primary),
      WordOutcome.wrong => (Icons.cancel, colors.error),
      WordOutcome.blank => (Icons.radio_button_unchecked, colors.onSurfaceVariant),
    };
    final dirLabel = w.dir == Direction.across ? '가로' : '세로';
    final label = number == null ? dirLabel : '$dirLabel$number';
    final showEntered = wordResult.outcome != WordOutcome.correct;
    final enteredText =
        wordResult.outcome == WordOutcome.blank ? '(빈칸)' : wordResult.entered;

    return ListTile(
      leading: Icon(icon, color: color),
      // `RichText`를 직접 쓰지 않고 `Text.rich`를 쓴다 — 순수 `RichText`는
      // `find.text`/`find.textContaining`(기본값)이 못 찾는다(`findRichText:
      // true`를 따로 줘야 함). `Text.rich`는 위젯 타입이 `Text`라 그대로 잡힌다.
      title: Text.rich(
        TextSpan(
          style: DefaultTextStyle.of(context)
              .style
              .copyWith(fontWeight: FontWeight.w600),
          children: [
            TextSpan(text: '$label  ${w.headword}'),
            if (showEntered)
              TextSpan(
                text: '    입력: $enteredText',
                style: TextStyle(
                    color: colors.onSurfaceVariant, fontWeight: FontWeight.normal),
              ),
          ],
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hint?.definition ?? '(뜻풀이 없음)'),
          if (hint != null && hint!.hasSynonyms)
            Text(
              '유의어: ${hint!.synonyms.join(', ')}',
              style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
            ),
        ],
      ),
    );
  }
}
