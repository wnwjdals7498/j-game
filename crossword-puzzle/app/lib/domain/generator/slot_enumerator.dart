import '../model/puzzle.dart';
import 'grid.dart';

/// 채움 단어를 넣을 수 있는 자리 하나 (01-05).
///
/// (시작 좌표, 방향, 길이) + 그 구간에 이미 채워진 칸의 음절 제약.
/// [fixed] 가 그대로 `WordRepository.findByPattern` 의 `fixed` 인자가 된다.
class Slot {
  final int row;
  final int col;
  final Direction dir;
  final int length;
  final Map<int, String> fixed; // 자리 index -> 이미 채워진 음절
  final int crossings; // fixed.length. 정렬 키로 씀

  Slot({
    required this.row,
    required this.col,
    required this.dir,
    required this.length,
    required this.fixed,
  }) : crossings = fixed.length;

  int get emptyCount => length - crossings;

  String get key => '${dir.name}:$row:$col:$length';

  @override
  bool operator ==(Object other) => other is Slot && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'Slot($key, fixed=$fixed)';
}

/// 채움 슬롯 열거 (01-05).
///
/// 순수 기하 계산만 한다. 사전을 모르고, 랜덤을 쓰지 않는다.
class SlotEnumerator {
  /// [g]에서 채울 수 있는 슬롯 전부.
  ///
  /// 조건 (01-05 "슬롯이란"):
  /// 1. 길이 2~5
  /// 2. 구간 전체가 격자 안
  /// 3. 진행 방향 앞뒤 끝막음 칸이 비었거나 격자 밖 (01-03 규칙 2)
  /// 4. 구간 안에 채워진 칸이 1개 이상 — 채움은 항상 기존 단어와 교차한다
  /// 5. 구간 안 빈 칸들은 각각 수직 이웃이 비어 있어야 한다 (규칙 2)
  /// 6. 빈 칸이 0개면 슬롯이 아니다 (넣을 게 없다)
  /// 7. 같은 방향으로 이미 놓인 단어를 구간이 통째로 품지 않는다 (01-03 규칙 2-b)
  ///
  /// 반환 순서는 **결정적**이다: (dir, row, col, length) 오름차순.
  static List<Slot> enumerate(MutableGrid g) {
    final out = <Slot>[];
    for (final dir in Direction.values) {
      final maxR = g.height, maxC = g.width;
      for (var r = 0; r < maxR; r++) {
        for (var c = 0; c < maxC; c++) {
          for (var len = 2; len <= 5; len++) {
            final dr = dir == Direction.down ? 1 : 0;
            final dc = dir == Direction.across ? 1 : 0;
            final rEnd = r + dr * (len - 1);
            final cEnd = c + dc * (len - 1);
            if (!g.inBounds(rEnd, cEnd)) continue;

            // 끝막음 (조건 3)
            if (!_emptyOrOutside(g, r - dr, c - dc)) continue;
            if (!_emptyOrOutside(g, rEnd + dr, cEnd + dc)) continue;

            // 기존 단어 통째로 품기 (조건 7)
            if (_coversPlacedWord(g, r, c, dir, len)) continue;

            final fixed = <int, String>{};
            var ok = true;
            for (var i = 0; i < len; i++) {
              final rr = r + dr * i, cc = c + dc * i;
              final s = g.at(rr, cc);
              if (s != null) {
                fixed[i] = s;
              } else {
                // 빈 칸의 수직 이웃 (조건 5)
                if (!_emptyOrOutside(g, rr - dc, cc - dr) ||
                    !_emptyOrOutside(g, rr + dc, cc + dr)) {
                  ok = false;
                  break;
                }
              }
            }
            if (!ok) continue;
            if (fixed.isEmpty) continue; // 조건 4
            if (fixed.length == len) continue; // 조건 6

            out.add(Slot(row: r, col: c, dir: dir, length: len, fixed: fixed));
          }
        }
      }
    }
    return out; // 루프 순서가 이미 (dir, row, col, length) 오름차순
  }

  /// 제약 강한 순: 교차 많은 것 → 짧은 것 → 안정적 key 순
  static int compareByConstraint(Slot a, Slot b) {
    if (a.crossings != b.crossings) return b.crossings.compareTo(a.crossings);
    if (a.length != b.length) return a.length.compareTo(b.length);
    return a.key.compareTo(b.key);
  }

  static bool _emptyOrOutside(MutableGrid g, int r, int c) =>
      !g.inBounds(r, c) || g.at(r, c) == null;

  /// (r0,c0)부터 [dir] 방향 [len]칸 구간이 같은 방향 기존 단어의 칸을 품는가.
  ///
  /// `GridRules.canPlace` 의 2-b와 같은 식이다. 끝막음(조건 3)이 부분 겹침을 이미
  /// 걸러내므로 여기 걸리는 건 **기존 단어를 통째로 품는 구간**뿐이다. 그런 구간에
  /// 단어를 놓으면 더 긴 연속 하나가 되어 기존 단어가 격자에서 사라진다(규칙 2).
  static bool _coversPlacedWord(
    MutableGrid g,
    int r0,
    int c0,
    Direction dir,
    int len,
  ) {
    final dr = dir == Direction.down ? 1 : 0;
    final dc = dir == Direction.across ? 1 : 0;
    for (final w in g.placed) {
      if (w.dir != dir) continue;
      for (final (r, c) in w.cells) {
        final off = dr * (r - r0) + dc * (c - c0); // 진행 방향 오프셋
        final perp = dc * (r - r0) + dr * (c - c0); // 수직 방향 오프셋
        if (perp == 0 && off >= 0 && off < len) return true;
      }
    }
    return false;
  }
}
