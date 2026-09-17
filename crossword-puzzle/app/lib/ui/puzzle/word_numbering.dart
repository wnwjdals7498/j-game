// 단어 번호 매기기 (04-03.selection-and-hint.md "단어 번호 매기기").
//
// 낱말퍼즐 관례: 격자를 위→아래, 왼→오른쪽으로 훑으며 **단어가 시작하는 셀**에
// 번호를 매긴다. 같은 셀에서 가로·세로가 동시에 시작하면 같은 번호를 공유한다.
//
// `GridPainter`(04-02)가 격자 셀 좌상단에 그리고, 힌트 패널이 헤더에 쓴다.
import '../../domain/model/puzzle.dart';

/// 시작 셀 좌표 → 번호(1부터).
Map<(int, int), int> numberCells(Puzzle p) {
  final starts = <(int, int)>{for (final w in p.words) (w.row, w.col)};
  final sorted = starts.toList()
    ..sort((a, b) =>
        a.$1 != b.$1 ? a.$1.compareTo(b.$1) : a.$2.compareTo(b.$2));
  return {for (var i = 0; i < sorted.length; i++) sorted[i]: i + 1};
}
