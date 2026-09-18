// 07-04-04.puzzle-sheets.md — 튜토리얼 · 제출 확인 · 제출 오류 바텀 시트 (E-12).
//
// 퍼즐 화면에 남아 있던 옛 확인창 세 곳(튜토리얼 안내, 제출 확인, 제출
// 오류 안내)을 바텀 시트로 바꾼다 — UI-GUIDE 4절 "다이얼로그 대신 바텀
// 시트": 파괴적 확인이 아니므로 옛 확인창을 남기지 않는다.
//
// 문구·버튼 라벨은 옛 확인창과 글자 하나도 다르지 않다(INV-09,
// N-09) — 표현(다이얼로그 → 시트)만 바뀐다. 상단 반지름(`GameRadius.panel`)과
// 배경(`surface`)은 `app_theme.dart`의 `bottomSheetTheme`이 이미 주고,
// 등장 애니메이션(E-12, `base`/`curveEmphasized`)은 `showModalBottomSheet`
// 기본 동작이 준다 — 이 파일은 `Duration`을 만들지 않는다(INV-12).
import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// 최초 진입 조작법 안내 (puzzle_page.dart `_maybeShowTutorial`).
Future<void> showTutorialSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      useSafeArea: true,
      builder: (c) => _SheetBody(
        title: '이렇게 플레이해요',
        body: '• 칸을 누르면 그 칸을 지나는 단어가 선택됩니다.\n'
            '• 가로·세로 단어가 만나는 칸을 다시 누르면 방향이 바뀝니다.\n'
            '• 아래 입력창에 단어를 입력하면 칸에 채워집니다.\n'
            '• 다 채웠으면 "제출"을 눌러 채점합니다.',
        actions: [
          _SheetAction(label: '확인', primary: true, onTap: () => Navigator.pop(c)),
        ],
      ),
    );

/// 제출 확인. 취소·바깥 탭·뒤로가기는 전부 false("계속 풀기")로 취급한다
/// (`showModalBottomSheet`가 그 경우 null을 돌려주므로 `?? false`로 받는다).
/// `isDismissible: false`로 막지 않는다 — 제출은 파괴적 동작이 아니다.
Future<bool> showSubmitConfirmSheet(BuildContext context, {required int blanks}) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: false,
    useSafeArea: true,
    builder: (c) => _SheetBody(
      title: '제출하시겠습니까?',
      body: blanks > 0
          ? '빈 칸이 $blanks개 있습니다. 빈 칸은 오답으로 처리됩니다.'
          : '모든 칸을 채웠습니다.',
      actions: [
        // 버튼 순서는 취소 → 확인을 유지한다 — submit_test.dart·
        // play_loop_test.dart가 `find.text('제출').last`로 확인 버튼을 고른다.
        _SheetAction(label: '계속 풀기', primary: false, onTap: () => Navigator.pop(c, false)),
        _SheetAction(label: '제출', primary: true, onTap: () => Navigator.pop(c, true)),
      ],
    ),
  );
  return ok ?? false;
}

/// 제출 중 오류 안내 (puzzle_model.dart `submit`의 `catch`).
Future<void> showSubmitErrorSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      useSafeArea: true,
      builder: (c) => _SheetBody(
        title: '제출할 수 없습니다',
        body: '단어 데이터에 문제가 생겼습니다. 앱을 다시 시작한 뒤 다시 시도해 주세요.',
        actions: [
          _SheetAction(label: '확인', primary: true, onTap: () => Navigator.pop(c)),
        ],
      ),
    );

/// 시트 공통 본문: 제목 + 본문 + 액션 행. 액션이 하나면 폭 전체를 쓰고,
/// 둘이면 보조(취소)가 왼쪽, `Expanded` 두 개 사이 `GameSpace.m` 간격.
class _SheetBody extends StatelessWidget {
  final String title;
  final String body;
  final List<_SheetAction> actions;

  const _SheetBody({required this.title, required this.body, required this.actions});

  @override
  Widget build(BuildContext context) {
    final c = GameColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(GameSpace.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GameType.title.copyWith(color: c.ink)),
          const SizedBox(height: GameSpace.m),
          Text(body, style: GameType.body.copyWith(color: c.ink)),
          const SizedBox(height: GameSpace.xl),
          Row(
            children: actions.length == 1
                ? [Expanded(child: actions.single)]
                : [
                    Expanded(child: actions[0]),
                    const SizedBox(width: GameSpace.m),
                    Expanded(child: actions[1]),
                  ],
          ),
        ],
      ),
    );
  }
}

/// 시트 전용 액션 버튼. `SubmitButton`(07-04-03)과 같은 규격(높이
/// `GameRadius.buttonHeight`, `GameRadius.pill`, 기본 = ink/surface, 보조 =
/// 투명/line `outlineButton`/ink)이지만 상태 전환이 없다 — `SubmitButton`은
/// `active` 애니메이션이 본질이고 라벨이 '제출'로 고정이라 재사용하지 않는다.
class _SheetAction extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;

  const _SheetAction({required this.label, required this.primary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = GameColors.of(context);
    final radius = BorderRadius.circular(GameRadius.pill);
    return SizedBox(
      height: GameRadius.buttonHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: primary ? c.ink : Colors.transparent,
          border: Border.all(
              color: primary ? c.ink : c.line, width: GameRadius.outlineButton),
          borderRadius: radius,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Center(
              child: Text(
                label,
                style: GameType.body.copyWith(
                  fontWeight: primary ? FontWeight.w700 : FontWeight.w600,
                  color: primary ? c.surface : c.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
