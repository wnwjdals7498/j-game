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
//
// `StatefulWidget`이다 — E-07(결과 행 순차 등장, UI-GUIDE 3.3)이 페이지
// 전체에서 컨트롤러 하나를 갖고, 행마다는 그 컨트롤러의 구간(`Interval`)만
// 잘라 쓴다(07-06-02 "행마다 컨트롤러를 만들지 않는다"). props 계약은 그대로다
// — `submit_test.dart`는 여전히 생성자 값만으로 pump한다.
import 'dart:math';

import 'package:flutter/material.dart';

import '../../data/hint_repository.dart';
import '../../domain/levels.dart';
import '../../domain/model/level_spec.dart';
import '../../domain/model/puzzle.dart';
import '../../domain/model/submit_result.dart';
import '../puzzle/word_numbering.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'score_header.dart';
import 'unlock_burst.dart';
import 'word_result_card.dart';

class ResultPage extends StatefulWidget {
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
  State<ResultPage> createState() => _ResultPageState();
}

// UI-GUIDE 3.3 E-07 "행마다 40ms 간격". 행 수가 많아도 총 길이가 `slow`를
// 넘지 않도록 아래 `_gapCapMs`보다 좁게 줄어든다(07-06-02 4절).
const double _gapCapMs = 40;

class _ResultPageState extends State<ResultPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rows = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    // GameMotion.of는 context가 필요해 initState에서 못 쓴다.
    super.didChangeDependencies();
    final motion = GameMotion.of(context);
    _rows.duration = motion.slow;
    if (!_started && widget.result != null) {
      _started = true;
      _rows.forward();
    }
  }

  @override
  void dispose() {
    _rows.dispose();
    super.dispose();
  }

  /// [i]번째 행(전체 [rows]개 중)이 쓸 구간 애니메이션. 행당 `fast`, 행 간격
  /// `_gapCapMs` 이하, 총 길이는 항상 `slow` 이하로 맞춘다.
  ///
  /// 감소 모션 함정: `motion.slow`가 `Duration.zero`면 `gap`도 `begin`도 `end`도
  /// 0이 되어 `Interval(0, 0).transform(1)`이 `0/0 = NaN`을 낸다 —
  /// `kAlwaysCompleteAnimation`으로 미리 빠져나간다.
  Animation<double> _rowAnimation(GameMotion motion, int i, int rows) {
    final slowMs = motion.slow.inMilliseconds.toDouble();
    if (slowMs == 0) return kAlwaysCompleteAnimation;
    final fastMs = motion.fast.inMilliseconds.toDouble();
    final gap = min(_gapCapMs, (slowMs - fastMs) / max(rows - 1, 1));
    final begin = (i * gap) / slowMs;
    final end = ((i * gap) + fastMs) / slowMs;
    return CurvedAnimation(
        parent: _rows,
        curve: Interval(begin.clamp(0, 1), end.clamp(0, 1),
            curve: motion.curveStandard));
  }

  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    final puzzle = widget.puzzle;
    final result = widget.result;
    if (spec == null || puzzle == null || result == null) {
      // 04-01 스텁과 같은 폴백. `/result`로 직접 진입(테스트 포함)했을 때만
      // 보인다 — 실제 플레이 흐름은 항상 값을 채워 넘긴다.
      return Scaffold(
        appBar: AppBar(title: const Text('결과')),
        body: const Center(child: Text('결과 없음')),
      );
    }

    final motion = GameMotion.of(context);
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

    final header = ScoreHeader(
      score: result.score, correct: result.correctCount, total: result.total,
      isFirstSubmit: result.isFirstSubmit,
      justUnlocked: justUnlocked, unlockedLevelId: next?.id,
    );

    return Scaffold(
      appBar: AppBar(title: Text('레벨 ${spec.id} · ${spec.name}')),
      body: Column(
        children: [
          // E-08: 헤더만 Stack으로 감싸 해제 연출을 얹는다. 목록·버튼은 그대로다
          // (07-06-03 "ResultPage 연결"). 비위치 자식이 헤더 하나뿐이라 Stack
          // 크기는 헤더 크기가 되고, Positioned.fill이 그 위를 덮는다.
          justUnlocked
              ? Stack(children: [
                  header,
                  Positioned.fill(child: const UnlockBurst()),
                ])
              : header,
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: GameSpace.xs),
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) => WordResultCard(
                wordResult: rows[i],
                number: numbers[(rows[i].word.row, rows[i].word.col)],
                hint: widget.hints[rows[i].word.headword],
                animation: _rowAnimation(motion, i, rows.length),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onRetry,
                    child: const Text('다시 풀기'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: widget.onNextLevel,
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
