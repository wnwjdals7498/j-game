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
//
// 07-03-02: `StatefulWidget`으로 바뀌어 컨트롤러 3개(`_pop`·`_selection`·
// `_cursor`)로 E-01~E-03 모션을 움직인다. 시간·곡선은 전부
// `GameMotion.of(context)`에서만 얻는다(INV-12) — 이 파일에 지속시간 리터럴이나
// 곡선 상수 직접 참조가 있으면 안 된다. 상태 클래스는 `FormState`·
// `ScaffoldState`처럼 공개(`PuzzleGridViewState`)다 — 07-03-03이
// `tester.state<...>()`로 `pop`·`selectionRect`·`cursorOpacity`를 읽는다.
import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/model/puzzle.dart';
import '../../domain/model/submit_result.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
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

class PuzzleGridView extends StatefulWidget {
  final Puzzle puzzle;

  /// 격자 셀 → 유저 입력 음절. `PuzzleModel.answers`(04-01)와 같은 타입.
  final Map<(int, int), String> answers;

  /// 현재 선택된 단어. null이면 미선택.
  final PlacedWord? selected;

  /// 제출 후에만 non-null. null이면 제출 전 모드(정답 미노출).
  final SubmitResult? result;

  /// 마지막으로 탭한 셀. 커서 셀 표시(E-03, `GridPainter` 3층)에 쓴다.
  /// null이면 커서를 그리지 않는다. `selected`·`result`와 같은 결로 required —
  /// 호출부에서 빠뜨리면 커서가 조용히 사라진다.
  final (int, int)? focusedCell;

  /// 검은 칸이 아닌 셀을 탭했을 때 호출. 단어 선택 로직은 04-03이 처리한다.
  final void Function(int row, int col) onCellTap;

  const PuzzleGridView({
    super.key,
    required this.puzzle,
    required this.answers,
    required this.selected,
    required this.result,
    required this.focusedCell,
    required this.onCellTap,
  });

  @override
  PuzzleGridViewState createState() => PuzzleGridViewState();
}

class PuzzleGridViewState extends State<PuzzleGridView>
    with TickerProviderStateMixin {
  late final AnimationController _pop;
  late final AnimationController _selection;
  late final AnimationController _cursor;

  /// E-01. 비어 있으면 팝 없음.
  Set<(int, int)> _popCells = {};

  /// null이면 해당 모션이 멈춘 상태.
  Curve? _popCurve;
  Curve? _selectionCurve;

  /// E-02 보간의 양 끝. 셀 단위(열·행) — `cell`은 `LayoutBuilder` 안에서만
  /// 정해지는데 트리거는 `didUpdateWidget`에서 일어나기 때문이다.
  Rect? _prevBounds;
  Rect? _nextBounds;

  /// `LayoutBuilder` 본문에서 갱신되는 마지막 셀 크기.
  double _cell = 0;

  @override
  void initState() {
    super.initState();
    _pop = AnimationController(vsync: this)
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() => _popCells = {});
        }
      });
    _selection = AnimationController(vsync: this)
      ..addListener(() => setState(() {}))
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _prevBounds = null;
            _nextBounds = null;
          });
        }
      });
    _cursor = AnimationController(vsync: this)
      ..value = 1
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pop.dispose();
    _selection.dispose();
    _cursor.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PuzzleGridView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final m = GameMotion.of(context);
    _syncPop(oldWidget, m);
    _syncSelection(oldWidget, m);
    _syncCursor(oldWidget, m);
  }

  /// E-01: 이전이 null/빈 문자열이고 지금은 비어 있지 않은 셀 집합.
  /// 지우기는 발동하지 않는다 — 사라진 키는 `widget.answers`를 도는 이 루프에
  /// 나타나지 않는다.
  void _syncPop(PuzzleGridView old, GameMotion m) {
    final newly = <(int, int)>{};
    for (final e in widget.answers.entries) {
      if (e.value.isEmpty) continue;
      final before = old.answers[e.key];
      if (before == null || before.isEmpty) newly.add(e.key);
    }
    if (newly.isEmpty) return;

    if (m.fast == Duration.zero) {
      _popCells = {};
      _popCurve = null;
      _pop.stop();
    } else {
      _popCells = newly;
      _popCurve = m.curvePop;
      _pop.duration = m.fast;
      _pop.forward(from: 0);
    }
  }

  /// E-02: `old.selected`와 `widget.selected`가 서로 다른 인스턴스이고 둘 다
  /// non-null일 때만 움직인다. `PlacedWord`는 `==`를 재정의하지 않으므로
  /// `identical`(인스턴스 비교)로 판정한다.
  void _syncSelection(PuzzleGridView old, GameMotion m) {
    final prev = old.selected;
    final next = widget.selected;
    if (identical(prev, next)) return;
    if (prev == null || next == null) return;

    if (m.fast == Duration.zero) {
      _prevBounds = null;
      _nextBounds = null;
    } else {
      _prevBounds = _boundsOf(prev);
      _nextBounds = _boundsOf(next);
      _selectionCurve = m.curveStandard;
      _selection.duration = m.fast;
      _selection.forward(from: 0);
    }
  }

  /// E-03: 탭한 셀이 바뀌고 새 값이 non-null일 때만 등장 애니메이션.
  /// `focusedCell`이 null이 되는 경우(다시 풀기)는 `_cursor.value = 1`만 하고
  /// 애니메이션은 돌리지 않는다 — 페인터가 `focusedCell == null`이면 층 3을
  /// 건너뛰므로 알파는 의미가 없다.
  void _syncCursor(PuzzleGridView old, GameMotion m) {
    if (widget.focusedCell == null) {
      _cursor.value = 1;
      return;
    }
    if (widget.focusedCell == old.focusedCell) return;

    if (m.instant == Duration.zero) {
      _cursor.value = 1;
    } else {
      _cursor.duration = m.instant;
      _cursor.forward(from: 0);
    }
  }

  /// `PlacedWord.cells`는 시작→끝 순서이므로 바운딩은 양 끝 셀만으로 구한다.
  Rect _boundsOf(PlacedWord w) {
    final cells = w.cells.toList();
    final first = cells.first;
    final last = cells.last;
    return Rect.fromLTWH(
      first.$2.toDouble(),
      first.$1.toDouble(),
      (last.$2 - first.$2 + 1).toDouble(),
      (last.$1 - first.$1 + 1).toDouble(),
    );
  }

  @visibleForTesting
  Map<(int, int), double> get pop {
    final curve = _popCurve;
    if (_popCells.isEmpty || curve == null) return const {};
    final v = curve.transform(_pop.value);
    return {for (final c in _popCells) c: v};
  }

  @visibleForTesting
  Rect? get selectionRect {
    final a = _prevBounds, b = _nextBounds, curve = _selectionCurve;
    if (a == null || b == null || curve == null) return null;
    final r = Rect.lerp(a, b, curve.transform(_selection.value))!;
    return Rect.fromLTWH(
        r.left * _cell, r.top * _cell, r.width * _cell, r.height * _cell);
  }

  @visibleForTesting
  double get cursorOpacity => _cursor.value;

  @override
  Widget build(BuildContext context) {
    final colors = GameColors.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        // 격자는 정사각형이고 가용 폭에 맞춘다(문서 "레이아웃 계산"). 높이가
        // 부족한 경우(힌트 패널·입력 필드가 차지) `maxHeight`도 고려해야
        // 잘리지 않는다 — 문서 "막히면": "작은 기기에서 격자가 잘림".
        final side = constraints.maxWidth.clamp(0.0, constraints.maxHeight);
        final cell = side / max(widget.puzzle.width, widget.puzzle.height);
        _cell = cell;
        final size =
            Size(cell * widget.puzzle.width, cell * widget.puzzle.height);
        return SizedBox(
          width: size.width,
          height: size.height,
          child: GestureDetector(
            onTapDown: (d) => _handleTap(d.localPosition, cell),
            child: CustomPaint(
              painter: GridPainter(
                puzzle: widget.puzzle,
                answers: widget.answers,
                selected: widget.selected,
                focusedCell: widget.focusedCell,
                result: widget.result,
                colors: colors,
                cell: cell,
                selectionRect: selectionRect,
                cursorOpacity: cursorOpacity,
                pop: pop,
              ),
              size: size,
            ),
          ),
        );
      },
    );
  }

  void _handleTap(Offset local, double cell) {
    final hit = cellForOffset(local, cell, widget.puzzle);
    if (hit == null) return;
    widget.onCellTap(hit.$1, hit.$2);
  }
}
