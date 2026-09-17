// 격자 렌더링 위젯 (04-02). `GestureDetector` + `CustomPaint` 단일 위젯으로
// 격자 전체를 그린다 (04-ui.md "기술 결정": 셀 수십 개를 위젯으로 만들면
// 무겁고 탭 처리도 복잡하다). 탭 좌표 → 셀 변환은 [cellForOffset]이 맡는다.
// 그 결과를 어떤 단어로 이어붙일지(가로 우선 → 재탭 시 세로 등)는 04-03 몫.
//
// 클래스 이름이 `GridView`가 아니라 `PuzzleGridView`인 이유: 이 파일이 import
// 하는 `package:flutter/material.dart`가 이미 스크롤 가능한 `GridView` 위젯을
// 그 이름으로 내보낸다. 문서는 파일 이름(`grid_view.dart`)만 정했고 클래스
// 이름은 정하지 않았으므로, 프레임워크 이름과 겹치지 않는 이름을 골랐다
// (04-02 문서에 없는 세부 결정 — "막히면" 절 대상이 아닌 사소한 이름 충돌).
import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/model/puzzle.dart';
import '../../domain/model/submit_result.dart';
import 'grid_painter.dart';

/// 로컬 탭 좌표를 격자 셀 (row, col)로 바꾼다. 범위 밖이거나 검은 칸이면
/// null. [GridPainter]가 셀 (r, c)를
/// `Rect.fromLTWH(c * cell, r * cell, cell, cell)`로 그리므로 좌표계가
/// 정확히 대응해야 한다.
(int row, int col)? cellForOffset(Offset local, double cell, Puzzle puzzle) {
  final c = (local.dx / cell).floor();
  final r = (local.dy / cell).floor();
  if (r < 0 || r >= puzzle.height || c < 0 || c >= puzzle.width) return null;
  if (puzzle.cellAt(r, c).blocked) return null;
  return (r, c);
}

class PuzzleGridView extends StatelessWidget {
  final Puzzle puzzle;

  /// 격자 셀 → 유저 입력 음절. `PuzzleModel.answers`(04-01)와 같은 타입.
  final Map<(int, int), String> answers;

  /// 현재 선택된 단어. null이면 미선택.
  final PlacedWord? selected;

  /// 제출 후에만 non-null. null이면 제출 전 모드(정답 미노출).
  final SubmitResult? result;

  /// 검은 칸이 아닌 셀을 탭했을 때 호출. 단어 선택 로직은 04-03이 처리한다.
  final void Function(int row, int col) onCellTap;

  const PuzzleGridView({
    super.key,
    required this.puzzle,
    required this.answers,
    required this.selected,
    required this.result,
    required this.onCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        // 격자는 정사각형이고 가용 폭에 맞춘다(문서 "레이아웃 계산"). 높이가
        // 부족한 경우(힌트 패널·입력 필드가 차지) `maxHeight`도 고려해야
        // 잘리지 않는다 — 문서 "막히면": "작은 기기에서 격자가 잘림".
        final side = constraints.maxWidth.clamp(0.0, constraints.maxHeight);
        final cell = side / max(puzzle.width, puzzle.height);
        final size = Size(cell * puzzle.width, cell * puzzle.height);
        return SizedBox(
          width: size.width,
          height: size.height,
          child: GestureDetector(
            onTapDown: (d) => _handleTap(d.localPosition, cell),
            child: CustomPaint(
              painter: GridPainter(
                puzzle: puzzle,
                answers: answers,
                selected: selected,
                result: result,
                colors: colors,
                cell: cell,
              ),
              size: size,
            ),
          ),
        );
      },
    );
  }

  void _handleTap(Offset local, double cell) {
    final hit = cellForOffset(local, cell, puzzle);
    if (hit == null) return;
    onCellTap(hit.$1, hit.$2);
  }
}
