import '../model/puzzle.dart';

/// 생성 중에 쓰는 가변 격자. 완성되면 Puzzle로 굳힌다.
class MutableGrid {
  final int width;
  final int height;
  final List<List<String?>> syllables; // [row][col], null = 빈 칸
  final List<PlacedWord> placed = [];

  MutableGrid(this.width, this.height)
      : syllables =
            List.generate(height, (_) => List<String?>.filled(width, null));

  bool inBounds(int r, int c) => r >= 0 && r < height && c >= 0 && c < width;

  String? at(int r, int c) => inBounds(r, c) ? syllables[r][c] : null;

  bool isEmpty(int r, int c) => inBounds(r, c) && syllables[r][c] == null;

  /// 이미 놓인 표제어 집합. findByPattern의 exclude로 넘긴다.
  Set<String> get placedWords => placed.map((w) => w.headword).toSet();

  /// 합법성은 호출자가 GridRules.canPlace로 미리 확인한다. 여기선 검사하지 않는다.
  void place(PlacedWord w) {
    var i = 0;
    for (final (r, c) in w.cells) {
      syllables[r][c] = w.syllableAt(i++);
    }
    placed.add(w);
  }

  /// place의 역연산. 백트래킹용.
  /// 다른 단어가 공유하지 않는 셀만 비운다.
  ///
  /// [placed.remove]는 PlacedWord의 `==`를 쓴다. 01-01의 PlacedWord는 `==`를
  /// 재정의하지 않으므로 **place에 넘겼던 동일 인스턴스**여야 제거된다.
  void unplace(PlacedWord w) {
    assert(placed.contains(w), 'unplace는 place에 넘긴 동일 인스턴스여야 한다: ${w.headword}');
    placed.remove(w);
    final stillUsed = <(int, int)>{};
    for (final o in placed) {
      stillUsed.addAll(o.cells);
    }
    for (final (r, c) in w.cells) {
      if (!stillUsed.contains((r, c))) syllables[r][c] = null;
    }
  }

  Puzzle toPuzzle({
    required int levelId,
    required int seed,
    required int attempts,
  }) {
    final cells = List.generate(
      height,
      (r) => List.generate(width, (c) {
        final s = syllables[r][c];
        return s == null ? const Cell.blocked() : Cell.filled(s);
      }),
    );
    return Puzzle(
      levelId: levelId,
      width: width,
      height: height,
      cells: cells,
      words: List.unmodifiable(placed),
      seed: seed,
      attempts: attempts,
    );
  }
}
