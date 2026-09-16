enum Direction { across, down }

/// 격자에 배치된 단어 1개.
class PlacedWord {
  final String headword;
  final int row; // 시작 셀 행 (0-based)
  final int col; // 시작 셀 열 (0-based)
  final Direction dir;
  final bool isCore;
  final int tier;

  const PlacedWord({
    required this.headword,
    required this.row,
    required this.col,
    required this.dir,
    required this.isCore,
    required this.tier,
  });

  int get length => headword.length;

  /// 이 단어가 차지하는 셀 좌표들 (시작→끝 순서)
  Iterable<(int, int)> get cells sync* {
    for (var i = 0; i < length; i++) {
      yield dir == Direction.across ? (row, col + i) : (row + i, col);
    }
  }

  /// i번째 음절
  String syllableAt(int i) => headword[i];
}

/// 격자 셀 1개. blocked == true 면 검은 칸(단어 없음).
class Cell {
  final bool blocked;
  final String? solution; // 정답 음절. blocked면 null

  const Cell.blocked()
      : blocked = true,
        solution = null;
  const Cell.filled(String this.solution) : blocked = false;
}

/// 생성 결과.
class Puzzle {
  final int levelId;
  final int width;
  final int height;
  final List<List<Cell>> cells; // [row][col]
  final List<PlacedWord> words;
  final int seed; // 이 퍼즐을 만든 seed. 재현 키
  final int attempts; // 몇 번째 시도에서 성공했는지 (계측용)

  const Puzzle({
    required this.levelId,
    required this.width,
    required this.height,
    required this.cells,
    required this.words,
    required this.seed,
    required this.attempts,
  });

  Cell cellAt(int r, int c) => cells[r][c];

  Iterable<PlacedWord> get cores => words.where((w) => w.isCore);

  /// (r, c)를 지나는 단어들. UI의 셀 탭 → 단어 선택에 쓴다(04-03).
  List<PlacedWord> wordsAt(int r, int c) =>
      words.where((w) => w.cells.any((p) => p.$1 == r && p.$2 == c)).toList();
}

/// 생성 실패. maxAttempts 소진 시 던진다.
class GenerationFailed implements Exception {
  final int levelId;
  final int attempts;
  final String reason;

  const GenerationFailed(this.levelId, this.attempts, this.reason);

  @override
  String toString() =>
      'GenerationFailed(level=$levelId, attempts=$attempts, $reason)';
}
