// 힌트 바 (07-04-02.clue-bar.md). 이전에 따로 떠 있던 힌트 표시 위젯과
// `WordInput`을 하나로 합친다 — 배지·힌트 본문·◀▶·입력 필드가 한 덩어리로
// 보이는 NYT Crossword 모바일 레이아웃이다. 힌트 교체는 E-04
// 크로스페이드(UI-GUIDE 3.3)로 움직인다.
//
// `WordInput` 위젯 내부는 건드리지 않는다(07-04 결정, INV-02a) — 이 위젯은
// 그걸 [child]로 받아 감싸기만 한다.
import 'package:flutter/material.dart';

import '../../domain/model/puzzle.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';

class ClueBar extends StatelessWidget {
  /// 현재 선택된 단어. null이면 미선택 상태를 보여준다.
  final PlacedWord? selected;

  /// [selected]의 격자 번호 (`numberCells`). 없으면 번호 없이 표시.
  final int? number;

  /// `PuzzleModel.hintTextFor`가 고른 힌트 본문. [selected]가 null이면 무시.
  final String hintText;

  /// ◀ — 이전 단어로 (`PuzzleModel.selectPrevWord`).
  final VoidCallback onPrev;

  /// ▶ — 다음 단어로 (`PuzzleModel.selectNextWord`).
  final VoidCallback onNext;

  /// `WordInput`을 그대로 받는 슬롯. 여기 새 `Key`를 주면 선택이 바뀔 때마다
  /// 위젯이 재생성돼 포커스가 끊긴다 — 그대로 넘긴다(이 문서 "막히면").
  final Widget child;

  /// 힌트 본문 최대 줄 수. 07-04-05가 키보드가 뜨면 1로 접는다.
  final int hintMaxLines;

  const ClueBar({
    super.key,
    required this.selected,
    required this.number,
    required this.hintText,
    required this.onPrev,
    required this.onNext,
    required this.child,
    this.hintMaxLines = 3,
  });

  static const _unselectedText = '칸을 눌러 단어를 고르세요';

  /// 이전 힌트 표시 위젯의 헤더 문자열과 **같은 형식**을 유지한다:
  /// "가로 3   3글자"(공백 3칸). 화면에는 배지와 길이를 따로 그리므로, 이
  /// 문자열은 헤더 행의 `Semantics(label:)`로 남겨 형식과 접근성 레이블을
  /// 동시에 지킨다.
  static String headerOf(PlacedWord w, int? number) {
    final dirLabel = _dirLabel(w);
    return number == null
        ? '$dirLabel   ${w.length}글자'
        : '$dirLabel $number   ${w.length}글자';
  }

  static String _dirLabel(PlacedWord w) =>
      w.dir == Direction.across ? '가로' : '세로';

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.of(context);
    final motion = GameMotion.of(context);
    final word = selected;

    final headerRow = Row(
      children: [
        IconButton(
          onPressed: word == null ? null : onPrev,
          icon: const Icon(Icons.chevron_left),
          tooltip: '이전 단어',
        ),
        if (word == null)
          Expanded(
            child: Text(_unselectedText,
                style: GameType.body.copyWith(color: colors.inkMuted)),
          )
        else ...[
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: GameSpace.s, vertical: GameSpace.xs),
            decoration: BoxDecoration(
              color: colors.accentSoft,
              borderRadius: BorderRadius.circular(GameRadius.pill),
            ),
            child: Text(
              number == null ? _dirLabel(word) : '${_dirLabel(word)} $number',
              style: GameType.label.copyWith(color: colors.cellInk),
            ),
          ),
          const SizedBox(width: GameSpace.s),
          Expanded(
            child: Text('${word.length}글자',
                style: GameType.label.copyWith(color: colors.inkMuted)),
          ),
        ],
        IconButton(
          onPressed: word == null ? null : onNext,
          icon: const Icon(Icons.chevron_right),
          tooltip: '다음 단어',
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GameSpace.m),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: BorderRadius.circular(GameRadius.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          word == null
              ? headerRow
              : Semantics(label: headerOf(word, number), child: headerRow),
          const SizedBox(height: GameSpace.xs),
          // E-04 힌트 크로스페이드 (UI-GUIDE 3.3): 페이드 + 4dp 상승.
          // 감소 모션에서 `motion.base == Duration.zero`이므로 즉시 끝난다
          // (07-02-02).
          AnimatedSwitcher(
            duration: motion.base,
            switchInCurve: motion.curveStandard,
            switchOutCurve: motion.curveStandard,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.1),
                  end: Offset.zero,
                ).animate(anim),
                child: child,
              ),
            ),
            // 자식 Key가 같으면 교체를 인식하지 못한다(이 문서 "막히면").
            // PlacedWord는 ==를 재정의하지 않으므로(01-01) 위치+방향
            // 문자열로 만든다.
            child: Text(
              hintText,
              key: ValueKey(word == null
                  ? ''
                  : '${word.row},${word.col},${word.dir}'),
              maxLines: hintMaxLines,
              overflow: TextOverflow.ellipsis,
              style: GameType.body.copyWith(color: colors.ink),
            ),
          ),
          const SizedBox(height: GameSpace.s),
          child,
        ],
      ),
    );
  }
}
