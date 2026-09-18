// lib/ui/result/word_result_card.dart
//
// 07-06-02 산출물: 결과 목록 한 줄. 상태 아이콘 + 번호·표제어 + (오답/빈칸이면)
// 입력값 + 뜻풀이(마스킹 없음) + 유의어(있으면). 기존 `_WordRow`(`ListTile`
// 기반, result_page.dart)를 대체한다. 아이콘 3종·문구·정렬 규칙은 그대로 두고
// 색만 토큰으로, 모양만 카드형으로 바꾼다.
//
// 행마다 컨트롤러를 갖지 않는다 — `animation`은 부모(`ResultPage`)가 페이지
// 전체 컨트롤러(`_rows`)에서 구간(`Interval`)만 잘라 매번 새로 만들어 넘긴다
// (E-07 "결과 행 순차 등장", UI-GUIDE 3.3). 알파(`FadeTransition`)와 8dp 상승
// (`Transform.translate`)을 함께 입힌다.
import 'package:flutter/material.dart';

import '../../data/hint_repository.dart';
import '../../domain/model/puzzle.dart';
import '../../domain/model/submit_result.dart';
import '../theme/tokens.dart';

const double _riseDp = 8; // UI-GUIDE 3.3 E-07 "8dp 상승"
const double _iconSize = 20;

class WordResultCard extends StatelessWidget {
  final WordResult wordResult;
  final int? number;
  final Hint? hint;

  /// E-07 구간 애니메이션. 항상 부모가 준다.
  final Animation<double> animation;

  const WordResultCard({
    super.key,
    required this.wordResult,
    required this.number,
    required this.hint,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final c = GameColors.of(context);
    final (icon, color) = switch (wordResult.outcome) {
      // 색만으로 구분하지 않는다 — 04-02 GridPainter와 같은 원칙, 모양도 다르다.
      WordOutcome.correct => (Icons.check_circle, c.success),
      WordOutcome.wrong => (Icons.cancel, c.danger),
      WordOutcome.blank => (Icons.radio_button_unchecked, c.inkMuted),
    };
    final w = wordResult.word;
    final dirLabel = w.dir == Direction.across ? '가로' : '세로';
    final label = number == null ? dirLabel : '$dirLabel$number';
    final showEntered = wordResult.outcome != WordOutcome.correct;
    final enteredText =
        wordResult.outcome == WordOutcome.blank ? '(빈칸)' : wordResult.entered;

    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (_, child) => Transform.translate(
            offset: Offset(0, _riseDp * (1 - animation.value)), child: child),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: GameSpace.l, vertical: GameSpace.m),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, color: color, size: _iconSize),
            const SizedBox(width: GameSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // `RichText`를 직접 쓰지 않고 `Text.rich`를 쓴다 — 순수
                  // `RichText`는 `find.text`/`find.textContaining`(기본값)이
                  // 못 찾는다(`findRichText: true`를 따로 줘야 함). `Text.rich`는
                  // 위젯 타입이 `Text`라 그대로 잡힌다(기존 `_WordRow`와 같은 이유).
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                            text: label,
                            style: GameType.label.copyWith(color: c.ink)),
                        TextSpan(
                            text: '  ${w.headword}',
                            style: GameType.heading.copyWith(color: c.ink)),
                        if (showEntered)
                          TextSpan(
                              text: '    입력: $enteredText',
                              style:
                                  GameType.body.copyWith(color: c.inkMuted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: GameSpace.xs),
                  Text(hint?.definition ?? '(뜻풀이 없음)',
                      style: GameType.body.copyWith(color: c.ink)),
                  if (hint != null && hint!.hasSynonyms)
                    Text('유의어: ${hint!.synonyms.join(', ')}',
                        style: GameType.caption.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
