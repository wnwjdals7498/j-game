import '../model/puzzle.dart';
import 'grid.dart';

/// 성긴 낱말퍼즐 격자 규칙 (DESIGN.md 5절 1·2·3, REVIEW.md 5절 (1)).
///
/// 1. 배치한 단어만 유효하다. 검은 칸 개수 제한 없음.
/// 2. 우연히 생기는 연속 금지. 모든 가로·세로 "2칸 이상 연속 구간"은
///    PlacedWord 하나와 정확히 일치해야 한다.
/// 3. 교차 셀의 음절은 두 단어가 같아야 한다.
/// 4. 단어 길이 2~5음절.
/// 5. 고립 단어 최대 1개.
/// 6. 같은 표제어를 한 격자에 두 번 놓지 않는다.
class GridRules {
  /// [g]에 [dir] 방향으로 (r0,c0)부터 [headword]를 놓을 수 있는가.
  static bool canPlace(
    MutableGrid g,
    String headword,
    int r0,
    int c0,
    Direction dir,
  ) {
    final len = headword.length;
    if (len < 2 || len > 5) return false;

    final dr = dir == Direction.down ? 1 : 0;
    final dc = dir == Direction.across ? 1 : 0;

    // 1. 전 구간이 격자 안
    if (!g.inBounds(r0, c0)) return false;
    final rEnd = r0 + dr * (len - 1);
    final cEnd = c0 + dc * (len - 1);
    if (!g.inBounds(rEnd, cEnd)) return false;

    // 2. 앞뒤 끝막음: 진행 방향 바로 앞/뒤 칸은 비어 있거나 격자 밖
    //    (아니면 더 긴 연속이 생겨 규칙 2 위반)
    if (!_emptyOrOutside(g, r0 - dr, c0 - dc)) return false;
    if (!_emptyOrOutside(g, rEnd + dr, cEnd + dc)) return false;

    // 2-b. 같은 방향으로 이미 놓인 단어를 덮지 않는다.
    //      끝막음(2)은 부분 겹침·연장만 막는다. 기존 단어를 통째로 품는 배치는
    //      끝막음을 통과하지만, 놓고 나면 더 긴 연속 하나가 되어 기존 단어가
    //      격자에서 사라진다 (규칙 2 위반).
    //      예) (2,1) across '사과' 위에 (2,0) across '가사과자'
    for (final w in g.placed) {
      if (w.dir != dir) continue;
      for (final (r, c) in w.cells) {
        final off = dr * (r - r0) + dc * (c - c0); // 진행 방향 오프셋
        final perp = dc * (r - r0) + dr * (c - c0); // 수직 방향 오프셋
        if (perp == 0 && off >= 0 && off < len) return false;
      }
    }

    // 3. 각 셀
    for (var i = 0; i < len; i++) {
      final r = r0 + dr * i;
      final c = c0 + dc * i;
      final existing = g.at(r, c);
      final s = headword[i];

      if (existing != null) {
        // 교차. 음절이 같아야 한다 (규칙 3)
        if (existing != s) return false;
        // 이미 채워진 칸이므로 수직 방향 이웃 검사는 불필요.
        // (그 칸을 지나는 수직 단어가 이미 합법적으로 놓여 있다)
      } else {
        // 새로 채우는 칸. 수직 방향 이웃이 비어 있어야 한다.
        // 아니면 이 칸 + 이웃으로 2칸 연속이 새로 생겨 규칙 2 위반.
        if (!_emptyOrOutside(g, r - dc, c - dr)) return false; // 수직 -1
        if (!_emptyOrOutside(g, r + dc, c + dr)) return false; // 수직 +1
      }
    }

    // 4. 같은 표제어 중복 금지 (규칙 6)
    if (g.placedWords.contains(headword)) return false;

    return true;
  }

  static bool _emptyOrOutside(MutableGrid g, int r, int c) =>
      !g.inBounds(r, c) || g.at(r, c) == null;

  /// 위반 사유 리스트. 비어 있으면 유효한 격자.
  static List<String> validate(MutableGrid g, {bool allowIsolated = true}) {
    final errors = <String>[];

    // 규칙 2: 모든 maximal run이 PlacedWord와 일치
    final expected = <String>{}; // "dir:r:c:headword"
    for (final w in g.placed) {
      expected.add('${w.dir.name}:${w.row}:${w.col}:${w.headword}');
    }
    final found = <String>{};

    for (final dir in Direction.values) {
      final outer = dir == Direction.across ? g.height : g.width;
      final inner = dir == Direction.across ? g.width : g.height;
      for (var o = 0; o < outer; o++) {
        var i = 0;
        while (i < inner) {
          final (r, c) = dir == Direction.across ? (o, i) : (i, o);
          if (g.at(r, c) == null) {
            i++;
            continue;
          }
          final buf = StringBuffer();
          final startI = i;
          while (i < inner) {
            final (rr, cc) = dir == Direction.across ? (o, i) : (i, o);
            final s = g.at(rr, cc);
            if (s == null) break;
            buf.write(s);
            i++;
          }
          if (buf.length >= 2) {
            final (sr, sc) =
                dir == Direction.across ? (o, startI) : (startI, o);
            found.add('${dir.name}:$sr:$sc:$buf');
          }
        }
      }
    }

    for (final f in found) {
      if (!expected.contains(f)) errors.add('배치되지 않은 연속: $f');
    }
    for (final e in expected) {
      if (!found.contains(e)) errors.add('격자에 없는 PlacedWord: $e');
    }

    // 규칙 4: 길이
    for (final w in g.placed) {
      if (w.length < 2 || w.length > 5) errors.add('길이 위반: ${w.headword}');
    }

    // 규칙 6: 중복
    final seen = <String>{};
    for (final w in g.placed) {
      if (!seen.add(w.headword)) errors.add('중복 단어: ${w.headword}');
    }

    // 규칙 5: 연결성
    final comps = components(g.placed);
    if (comps.length > 2) {
      errors.add('연결 요소 ${comps.length}개 (최대 2)');
    } else if (comps.length == 2) {
      if (!allowIsolated) {
        errors.add('고립 단어 불허인데 연결 요소 2개');
      } else {
        final small = comps.map((x) => x.length).reduce((a, b) => a < b ? a : b);
        if (small != 1) errors.add('고립 요소 크기가 $small (1이어야 함)');
      }
    }

    return errors;
  }

  /// 단어 그래프의 연결 요소. 셀을 공유하면 같은 요소.
  static List<List<PlacedWord>> components(List<PlacedWord> words) {
    final n = words.length;
    if (n == 0) return [];
    final cellOwners = <(int, int), List<int>>{};
    for (var i = 0; i < n; i++) {
      for (final p in words[i].cells) {
        cellOwners.putIfAbsent(p, () => []).add(i);
      }
    }
    final adj = List.generate(n, (_) => <int>{});
    for (final owners in cellOwners.values) {
      for (var a = 0; a < owners.length; a++) {
        for (var b = a + 1; b < owners.length; b++) {
          adj[owners[a]].add(owners[b]);
          adj[owners[b]].add(owners[a]);
        }
      }
    }
    final seen = List.filled(n, false);
    final out = <List<PlacedWord>>[];
    for (var i = 0; i < n; i++) {
      if (seen[i]) continue;
      final comp = <PlacedWord>[];
      final stack = [i];
      seen[i] = true;
      while (stack.isNotEmpty) {
        final v = stack.removeLast();
        comp.add(words[v]);
        for (final u in adj[v]) {
          if (!seen[u]) {
            seen[u] = true;
            stack.add(u);
          }
        }
      }
      out.add(comp);
    }
    return out;
  }
}
