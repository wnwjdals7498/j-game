// 격자 1개를 그리는 CustomPainter (04-02, 번호 레이어는 04-03).
//
// 층 순서(아래→위, 04-02.grid-renderer.md "그려야 하는 것" + 04-03 번호):
// 1 검은 칸 배경 → 2 일반 칸 배경 → 3 선택 단어 하이라이트 → 4 셀 테두리 →
// 5 코어 테두리 강조 → 5.5 단어 번호(04-03) → 6 입력 음절 → 7 제출 후
// 정답/오답 표시. 번호는 셀 좌상단, 음절은 셀 중앙이라 겹치지 않는다.
//
// 색은 전부 `ColorScheme`에서 가져온다(문서 "색" 표). 하드코딩한 색을 쓰면
// 다크 모드에서 안 보인다.
//
// 정답/오답은 색만으로 구분하지 않는다(색각 이상 대응, 문서 "정답/오답을
// 색으로만 표시하지 않기"). 셀 우상단에 점(정답)/사선(오답)을 덧그린다.
//
// 격자에는 정답 텍스트를 절대 그리지 않는다 — 제출 후에도 유저가 입력한
// 음절과 O/X만 보여준다. 정답 공개는 결과 화면(04-05) 몫이다
// (문서 "제출 전/후 모드": "격자에는 O/X만 표시하고 정답은 결과 화면에서
// 보여주는 쪽이 깔끔하다").
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/model/puzzle.dart';
import '../../domain/model/submit_result.dart';
import 'word_numbering.dart';

class GridPainter extends CustomPainter {
  final Puzzle puzzle;
  final Map<(int, int), String> answers;
  final PlacedWord? selected;
  final SubmitResult? result; // 제출 후에만 non-null
  final ColorScheme colors;
  final double cell;

  GridPainter({
    required this.puzzle,
    required this.answers,
    required this.selected,
    required this.result,
    required this.colors,
    required this.cell,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final selectedCells = selected == null
        ? const <(int, int)>{}
        : selected!.cells.toSet();
    final outcomeByCell = _outcomeByCell();

    // 1~2층: 검은 칸 / 일반 칸 배경
    for (var r = 0; r < puzzle.height; r++) {
      for (var c = 0; c < puzzle.width; c++) {
        final rect = _cellRect(r, c);
        final blocked = puzzle.cellAt(r, c).blocked;
        canvas.drawRect(
          rect,
          Paint()
            ..color =
                blocked ? colors.surfaceContainerHighest : colors.surface,
        );
      }
    }

    // 3층: 선택된 단어 하이라이트 배경
    if (selectedCells.isNotEmpty) {
      final paint = Paint()..color = colors.primaryContainer;
      for (final (r, c) in selectedCells) {
        canvas.drawRect(_cellRect(r, c), paint);
      }
    }

    // 4층: 셀 테두리 (검은 칸 제외)
    final borderPaint = Paint()
      ..color = colors.outlineVariant
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var r = 0; r < puzzle.height; r++) {
      for (var c = 0; c < puzzle.width; c++) {
        if (puzzle.cellAt(r, c).blocked) continue;
        canvas.drawRect(_cellRect(r, c), borderPaint);
      }
    }

    // 5층: 코어 단어 테두리 강조
    final corePaint = Paint()
      ..color = colors.tertiary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final word in puzzle.cores) {
      for (final (r, c) in word.cells) {
        canvas.drawRect(_cellRect(r, c), corePaint);
      }
    }

    // 5.5층: 단어 번호 (04-03). 좌상단, 셀 크기의 22%.
    for (final entry in numberCells(puzzle).entries) {
      final (r, c) = entry.key;
      _drawNumber(canvas, entry.value, _cellRect(r, c), colors.onSurfaceVariant);
    }

    // 6~7층: 유저가 입력한 음절 + 제출 후 정답/오답 표시
    for (var r = 0; r < puzzle.height; r++) {
      for (var c = 0; c < puzzle.width; c++) {
        if (puzzle.cellAt(r, c).blocked) continue;
        final entered = answers[(r, c)];
        if (entered != null && entered.trim().isNotEmpty) {
          _drawSyllable(canvas, entered, _cellRect(r, c), colors.onSurface);
        }
        final outcome = outcomeByCell[(r, c)];
        if (outcome != null) {
          _drawOutcomeMark(canvas, _cellRect(r, c), outcome);
        }
      }
    }
  }

  Rect _cellRect(int r, int c) => Rect.fromLTWH(c * cell, r * cell, cell, cell);

  /// 제출 결과(단어 단위)를 셀 단위로 펼친다. 교차 셀이 서로 다른 결과를 가진
  /// 단어 두 개에 걸리면 나중에 순회되는 단어가 이긴다 — 01-08 scorer가 이미
  /// 교차 셀에서 "마지막 입력 우선"을 쓰는 것과 같은 결의 타협이다. 문서가
  /// 이 충돌을 별도로 다루지 않아 새 규칙을 만들지 않고 기존 관례를 따랐다.
  Map<(int, int), WordOutcome> _outcomeByCell() {
    final out = <(int, int), WordOutcome>{};
    final r = result;
    if (r == null) return out;
    for (final wr in r.results) {
      for (final pos in wr.word.cells) {
        out[pos] = wr.outcome;
      }
    }
    return out;
  }

  /// 정답(점) / 오답·빈칸(사선)을 셀 우상단에 작게 그린다. 색만으로 구분하지
  /// 않기 위한 장치이므로 모양 자체가 달라야 한다.
  void _drawOutcomeMark(Canvas canvas, Rect rect, WordOutcome outcome) {
    final markSize = cell * 0.18;
    final margin = cell * 0.12;
    final center = Offset(
      rect.right - margin - markSize / 2,
      rect.top + margin + markSize / 2,
    );
    if (outcome == WordOutcome.correct) {
      canvas.drawCircle(center, markSize / 2, Paint()..color = colors.primary);
      return;
    }
    // wrong, blank 둘 다 "오답" 취급 (DESIGN 5절 "빈칸은 오답").
    final half = markSize / 2;
    final linePaint = Paint()
      ..color = colors.error
      ..strokeWidth = (cell * 0.05).clamp(1.0, double.infinity)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center.translate(-half, -half),
      center.translate(half, half),
      linePaint,
    );
  }

  /// 단어 번호를 셀 좌상단에 작게 그린다 (04-03 "단어 번호 매기기").
  /// 안 보이면 문서 "막히면" 절대로 격자에서 빼고 힌트 패널에만 표시한다.
  void _drawNumber(Canvas canvas, int n, Rect rect, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: '$n',
        style: TextStyle(fontSize: cell * 0.22, color: color, height: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final margin = cell * 0.05;
    tp.paint(canvas, Offset(rect.left + margin, rect.top + margin));
  }

  void _drawSyllable(Canvas canvas, String s, Rect rect, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: cell * 0.55,
          color: color,
          fontWeight: FontWeight.w500,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, rect.center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(GridPainter old) =>
      old.puzzle != puzzle ||
      old.selected != selected ||
      old.result != result ||
      !mapEquals(old.answers, answers);
}
