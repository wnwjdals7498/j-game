// 힌트 패널 (04-03.selection-and-hint.md "힌트 패널 UI").
//
// 퍼즐 화면 하단, 입력 필드 위에 놓인다(04-04). 이 위젯은 `PuzzleGridView`처럼
// 이미 계산된 값만 받는 표시 전용 위젯이다 — 힌트 텍스트 선택(모드·마스킹)은
// `PuzzleModel.hintTextFor`가 맡는다.
//
// **코어 표시는 넣지 않는다.** 문서 "힌트 패널 UI" 절의 결정: 넣으면 유저가
// 코어에 집중하지만 "이건 네가 틀렸던 단어"라는 정보가 노출된다. 1차는 생략.
import 'package:flutter/material.dart';

import '../../domain/model/puzzle.dart';

class HintPanel extends StatelessWidget {
  /// 현재 선택된 단어. null이면 미선택 상태를 보여준다.
  final PlacedWord? selected;

  /// [selected]의 격자 번호 (04-03 `numberCells`). 없으면 번호 없이 표시.
  final int? number;

  /// `PuzzleModel.hintTextFor`가 고른 힌트 본문. [selected]가 null이면 무시.
  final String hintText;

  const HintPanel({
    super.key,
    required this.selected,
    required this.number,
    required this.hintText,
  });

  static const _unselectedText = '칸을 눌러 단어를 고르세요';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final word = selected;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: word == null
          ? Text(_unselectedText, style: TextStyle(color: colors.onSurfaceVariant))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _header(word),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hintText,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurface),
                ),
              ],
            ),
    );
  }

  /// "가로 3   3글자" 형태. 번호가 없으면 방향·길이만.
  String _header(PlacedWord w) {
    final dirLabel = w.dir == Direction.across ? '가로' : '세로';
    final n = number;
    return n == null ? '$dirLabel   ${w.length}글자' : '$dirLabel $n   ${w.length}글자';
  }
}
