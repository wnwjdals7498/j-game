// 격자 1개를 그리는 CustomPainter (04-02, 번호 레이어는 04-03; 07-03에서 NYT
// 8층 구조로 재정의됨).
//
// 층 순서(아래→위, UI-GUIDE.md 2.2 색 표 + 3.3 E-01~E-03):
// 1 셀 배경(검은 칸/일반 칸) → 2 선택 단어 배경 → 3 커서 셀(E-03) → 4 격자선
// → 5 코어 원 마크 → 6 단어 번호 → 7 입력 음절(E-01 팝) → 8 제출 후 정답/
// 오답 표시. 번호는 셀 좌상단, 음절은 셀 중앙이라 겹치지 않는다.
//
// 색은 전부 `GameColors`(UI-GUIDE 2.2)에서 가져온다. 하드코딩한 색을 쓰면
// 다크 모드에서 안 보인다(INV-05).
//
// 정답/오답은 색만으로 구분하지 않는다(색각 이상 대응, 문서 "정답/오답을
// 색으로만 표시하지 않기"). 셀 우상단에 점(정답)/사선(오답)을 덧그린다.
//
// 격자에는 정답 텍스트를 절대 그리지 않는다 — 제출 후에도 유저가 입력한
// 음절과 O/X만 보여준다. 정답 공개는 결과 화면(04-05) 몫이다
// (문서 "제출 전/후 모드": "격자에는 O/X만 표시하고 정답은 결과 화면에서
// 보여주는 쪽이 깔끔하다").
//
// 모션 인자 3개(`selectionRect`·`cursorOpacity`·`pop`)는 이 커밋에서 받기만
// 하고 정지 기본값을 쓴다 — 애니메이션은 07-03-02다. 시간·곡선은 위젯 몫이고
// 페인터는 그 결과값만 그린다.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/model/puzzle.dart';
import '../../domain/model/submit_result.dart';
import '../theme/tokens.dart';
import 'word_numbering.dart';

class GridPainter extends CustomPainter {
  final Puzzle puzzle;
  final Map<(int, int), String> answers;
  final PlacedWord? selected;
  final (int, int)? focusedCell;
  final SubmitResult? result; // 제출 후에만 non-null
  final GameColors colors;
  final double cell;
  final Rect? selectionRect; // E-02, 이 커밋에선 항상 null
  final double cursorOpacity; // E-03, 기본 1.0
  final Map<(int, int), double> pop; // E-01, 기본 const {}

  GridPainter({
    required this.puzzle,
    required this.answers,
    required this.selected,
    required this.focusedCell,
    required this.result,
    required this.colors,
    required this.cell,
    this.selectionRect,
    this.cursorOpacity = 1.0,
    this.pop = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outcomeByCell = _outcomeByCell();

    // 1층: 셀 배경 (검은 칸 / 일반 칸)
    for (var r = 0; r < puzzle.height; r++) {
      for (var c = 0; c < puzzle.width; c++) {
        final blocked = puzzle.cellAt(r, c).blocked;
        canvas.drawRect(
          _cellRect(r, c),
          Paint()..color = blocked ? colors.cellBlocked : colors.cellFill,
        );
      }
    }

    // 2층: 선택 단어 배경. `selectionRect`가 없으면 선택된 단어의 칸만,
    // 있으면(E-02 보간 중, 07-03-02) 그 사각형과 겹치는 칸 전부(검은 칸 제외).
    final selectionCells = <(int, int)>{};
    final selRect = selectionRect;
    if (selRect == null) {
      final s = selected;
      if (s != null) selectionCells.addAll(s.cells);
    } else {
      for (var r = 0; r < puzzle.height; r++) {
        for (var c = 0; c < puzzle.width; c++) {
          if (puzzle.cellAt(r, c).blocked) continue;
          if (selRect.overlaps(_cellRect(r, c))) selectionCells.add((r, c));
        }
      }
    }
    if (selectionCells.isNotEmpty) {
      final paint = Paint()..color = colors.accentSoft;
      for (final (r, c) in selectionCells) {
        canvas.drawRect(_cellRect(r, c), paint);
      }
    }

    // 3층: 커서 셀(E-03). 선택 단어 배경 위에 그려 항상 위에 보인다 — 커서는
    // 늘 선택 단어 안에 있으므로 "하늘색 줄 안의 노랑 한 칸"이 정상 모습이다.
    final fc = focusedCell;
    if (fc != null && !puzzle.cellAt(fc.$1, fc.$2).blocked) {
      canvas.drawRect(
        _cellRect(fc.$1, fc.$2),
        Paint()
          ..color = colors.accent.withValues(
            alpha: cursorOpacity.clamp(0.0, 1.0),
          ),
      );
    }

    // 4층: 격자선 (검은 칸 제외).
    final borderPaint = Paint()
      ..color = colors.gridLine
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var r = 0; r < puzzle.height; r++) {
      for (var c = 0; c < puzzle.width; c++) {
        if (puzzle.cellAt(r, c).blocked) continue;
        canvas.drawRect(_cellRect(r, c), borderPaint);
      }
    }
    // 외곽 2px. `Padding(1)`을 두지 않고 페인터가 안쪽으로 들여 그린다 —
    // 위젯 렌더 크기가 `cell * width`로 유지되어야 `cellForOffset`·
    // `cellCenter` 좌표계와 어긋나지 않는다(07-03-01 "격자 외곽 2px가 잘리지
    // 않게"). stroke는 경로 중심 기준 양쪽 1px이므로 `deflate(1)`이 정확히
    // [0, 2] 구간을 채운다.
    final gridRect =
        Rect.fromLTWH(0, 0, cell * puzzle.width, cell * puzzle.height);
    canvas.drawRect(
      gridRect.deflate(1),
      Paint()
        ..color = colors.gridLine
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // 5층: 코어 단어 셀의 원형 마크. 번호(6층)·음절(7층)보다 아래라 겹쳐도
    // 읽힌다.
    final corePaint = Paint()
      ..color = colors.cellCoreMark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final word in puzzle.cores) {
      for (final (r, c) in word.cells) {
        canvas.drawCircle(_cellRect(r, c).center, cell * 0.82 / 2, corePaint);
      }
    }

    // 6층: 단어 번호 (04-03). 좌상단, 셀 크기의 22%.
    for (final entry in numberCells(puzzle).entries) {
      final (r, c) = entry.key;
      _drawNumber(canvas, entry.value, _cellRect(r, c), colors.inkMuted);
    }

    // 7층: 유저가 입력한 음절(E-01 팝) + 8층: 제출 후 정답/오답 표시.
    for (var r = 0; r < puzzle.height; r++) {
      for (var c = 0; c < puzzle.width; c++) {
        if (puzzle.cellAt(r, c).blocked) continue;
        final entered = answers[(r, c)];
        if (entered != null && entered.trim().isNotEmpty) {
          final ink = fc == (r, c) ? colors.cellInkOnAccent : colors.cellInk;
          _drawSyllable(
            canvas,
            entered,
            _cellRect(r, c),
            ink,
            pop[(r, c)] ?? 1.0,
          );
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
      canvas.drawCircle(center, markSize / 2, Paint()..color = colors.success);
      return;
    }
    // wrong, blank 둘 다 "오답" 취급 (DESIGN 5절 "빈칸은 오답").
    final half = markSize / 2;
    final linePaint = Paint()
      ..color = colors.danger
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
        style: GameType.cellNumber(cell).copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final margin = cell * 0.05;
    tp.paint(canvas, Offset(rect.left + margin, rect.top + margin));
  }

  /// 셀 중앙에 음절 1개를 그린다. [p]는 E-01 팝 진행값(기본 1.0, 완성 크기).
  /// `p >= 1.0`이면 변환 없이 그대로 그리고, 그보다 작으면 셀 중심을 기준으로
  /// `0.7 + 0.3 * p` 배율로 축소해 그린다. 시간에 따라 커지는 곡선 자체는
  /// 위젯(07-03-02) 몫이다 — 페인터는 시간도 곡선도 모른다.
  void _drawSyllable(
    Canvas canvas,
    String s,
    Rect rect,
    Color color,
    double p,
  ) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: GameType.cellSyllable(cell).copyWith(color: color),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final at = rect.center - Offset(tp.width / 2, tp.height / 2);
    if (p >= 1.0) {
      tp.paint(canvas, at);
      return;
    }
    canvas.save();
    canvas.translate(rect.center.dx, rect.center.dy);
    canvas.scale(0.7 + 0.3 * p);
    canvas.translate(-rect.center.dx, -rect.center.dy);
    tp.paint(canvas, at);
    canvas.restore();
  }

  @override
  bool shouldRepaint(GridPainter old) =>
      old.puzzle != puzzle ||
      old.selected != selected ||
      old.focusedCell != focusedCell ||
      old.result != result ||
      old.selectionRect != selectionRect ||
      old.cursorOpacity != cursorOpacity ||
      old.cell != cell ||
      old.colors != colors ||
      !mapEquals(old.answers, answers) ||
      !mapEquals(old.pop, pop);
}
