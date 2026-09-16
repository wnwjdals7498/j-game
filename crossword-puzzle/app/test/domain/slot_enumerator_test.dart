import 'package:test/test.dart';

import 'package:jgame/domain/generator/grid.dart';
import 'package:jgame/domain/generator/grid_rules.dart';
import 'package:jgame/domain/generator/slot_enumerator.dart';
import 'package:jgame/domain/model/puzzle.dart';

import 'fixtures/dummy_dictionary.dart';

/// 테스트용 PlacedWord 생성기. 기본값은 코어·티어1.
PlacedWord pw(
  String headword,
  int row,
  int col,
  Direction dir, {
  bool isCore = true,
  int tier = 1,
}) =>
    PlacedWord(
      headword: headword,
      row: row,
      col: col,
      dir: dir,
      isCore: isCore,
      tier: tier,
    );

/// 슬롯이 덮는 셀 좌표들.
Iterable<(int, int)> cellsOf(Slot s) sync* {
  for (var i = 0; i < s.length; i++) {
    yield s.dir == Direction.across ? (s.row, s.col + i) : (s.row + i, s.col);
  }
}

void main() {
  test('빈 격자: 슬롯 0개 (조건 4)', () {
    final g = MutableGrid(5, 5);
    expect(SlotEnumerator.enumerate(g), isEmpty);
  });

  test('단어 1개: 각 코어 셀을 지나는 세로 슬롯들이 나온다', () {
    final g = MutableGrid(5, 5);
    g.place(pw('사과', 2, 0, Direction.across));

    final slots = SlotEnumerator.enumerate(g);
    expect(slots, isNotEmpty);

    // 사과의 두 셀 각각을 지나는 down 슬롯이 존재한다.
    for (final cell in [(2, 0), (2, 1)]) {
      final through = slots.where((s) =>
          s.dir == Direction.down &&
          cellsOf(s).any((p) => p.$1 == cell.$1 && p.$2 == cell.$2));
      expect(through, isNotEmpty, reason: '$cell 을 지나는 세로 슬롯이 없다');
    }

    // 조건 4: 모든 슬롯은 채워진 칸을 1개 이상 포함한다.
    for (final s in slots) {
      expect(s.crossings, greaterThan(0), reason: s.key);
      expect(s.emptyCount, greaterThan(0), reason: s.key);
    }
  });

  test('열거된 모든 슬롯은 길이가 맞는 단어를 실제로 놓을 수 있다', () async {
    final repo = InMemoryWordRepository(buildDummyDictionary(seed: 1));
    final g = MutableGrid(7, 7);
    g.place(const PlacedWord(
        headword: '가나다',
        row: 3,
        col: 2,
        dir: Direction.across,
        isCore: true,
        tier: 1));

    for (final slot in SlotEnumerator.enumerate(g)) {
      final words = await repo.findByPattern(
          length: slot.length, fixed: slot.fixed, limit: 1);
      if (words.isEmpty) continue; // 사전에 없는 건 슬롯 잘못이 아님
      expect(
        GridRules.canPlace(g, words.first.headword, slot.row, slot.col,
            slot.dir),
        isTrue,
        reason: 'slot ${slot.key} 이 canPlace를 통과하지 못함',
      );
    }
  });

  test('기존 단어를 통째로 품는 슬롯은 열거되지 않는다 (조건 7)', () {
    // 위 핵심 테스트는 사전에 맞는 단어가 없으면 그냥 넘어간다. 여기서는 슬롯마다
    // 제약을 만족하는 단어를 직접 합성해 사전 운에 기대지 않고 canPlace를 확인한다.
    // 조건 7이 없으면 across:3:1:4 / across:3:2:4 같은 슬롯이 나와
    // canPlace의 규칙 2-b(같은 방향 단어 덮어쓰기 금지)에 걸린다.
    final g = MutableGrid(7, 7);
    g.place(pw('가나다', 3, 2, Direction.across));
    g.place(pw('나라', 3, 3, Direction.down));

    final slots = SlotEnumerator.enumerate(g);
    expect(slots, isNotEmpty);
    for (final s in slots) {
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        buf.write(s.fixed[i] ?? '마'); // 빈 자리는 격자에 없는 음절로 채운다
      }
      expect(
        GridRules.canPlace(g, buf.toString(), s.row, s.col, s.dir),
        isTrue,
        reason: 'slot ${s.key} (word=$buf) 이 canPlace를 통과하지 못함',
      );
    }
  });

  test('꽉 찬 구간 제외 (조건 6)', () {
    final g = MutableGrid(5, 5);
    g.place(pw('사과', 2, 0, Direction.across));
    g.place(pw('사자', 2, 0, Direction.down));

    final keys = SlotEnumerator.enumerate(g).map((s) => s.key).toSet();
    // 두 구간 모두 빈 칸 0개라 슬롯이 아니다.
    expect(keys.contains('across:2:0:2'), isFalse);
    expect(keys.contains('down:2:0:2'), isFalse);
    // 빈 칸 0개인 슬롯은 아예 없다.
    for (final s in SlotEnumerator.enumerate(g)) {
      expect(s.emptyCount, greaterThan(0), reason: s.key);
    }
  });

  test('끝막음 위반 제외 (조건 3)', () {
    final g = MutableGrid(5, 5);
    g.place(pw('사과', 2, 0, Direction.across));

    final keys = SlotEnumerator.enumerate(g).map((s) => s.key).toSet();
    // (2,1)~(2,2)는 바로 앞 (2,0)이 '사'라 더 긴 연속이 생긴다.
    expect(keys.contains('across:2:1:2'), isFalse);
    // (2,2)~(2,3)도 바로 앞 (2,1)이 '과'라 막힌다.
    expect(keys.contains('across:2:2:2'), isFalse);
  });

  test('결정성: 두 번 호출하면 같은 순서의 같은 리스트', () {
    final g = MutableGrid(7, 7);
    g.place(pw('사과', 3, 2, Direction.across));
    g.place(pw('사자', 3, 2, Direction.down));

    String dump(List<Slot> slots) =>
        slots.map((s) => '${s.key}#${s.fixed}').join('|');

    final a = SlotEnumerator.enumerate(g);
    final b = SlotEnumerator.enumerate(g);
    expect(dump(a), dump(b));
    expect(a, isNotEmpty);

    // 문서가 정한 순서: (dir, row, col, length) 오름차순
    for (var i = 1; i < a.length; i++) {
      final p = a[i - 1], q = a[i];
      final pk = [p.dir.index, p.row, p.col, p.length];
      final qk = [q.dir.index, q.row, q.col, q.length];
      var cmp = 0;
      for (var k = 0; k < 4 && cmp == 0; k++) {
        cmp = pk[k].compareTo(qk[k]);
      }
      expect(cmp, lessThan(0), reason: '${p.key} 다음에 ${q.key}');
    }
  });

  test('정렬: compareByConstraint는 교차 많은 것을 앞에 둔다', () {
    final g = MutableGrid(7, 7);
    g.place(pw('사과', 3, 2, Direction.across));
    g.place(pw('사자', 3, 2, Direction.down));

    final sorted = SlotEnumerator.enumerate(g)
      ..sort(SlotEnumerator.compareByConstraint);
    expect(sorted, isNotEmpty);
    expect(sorted.map((s) => s.crossings).reduce((a, b) => a > b ? a : b),
        sorted.first.crossings);

    for (var i = 1; i < sorted.length; i++) {
      final p = sorted[i - 1], q = sorted[i];
      expect(p.crossings, greaterThanOrEqualTo(q.crossings));
      if (p.crossings == q.crossings) {
        expect(p.length, lessThanOrEqualTo(q.length));
        if (p.length == q.length) {
          expect(p.key.compareTo(q.key), lessThan(0));
        }
      }
    }
  });

  test('fixed 내용: 교차 셀 index/음절이 격자 값과 일치', () {
    final g = MutableGrid(7, 7);
    g.place(pw('사과', 3, 2, Direction.across));
    g.place(pw('사자', 3, 2, Direction.down));

    for (final s in SlotEnumerator.enumerate(g)) {
      final dr = s.dir == Direction.down ? 1 : 0;
      final dc = s.dir == Direction.across ? 1 : 0;
      for (var i = 0; i < s.length; i++) {
        final rr = s.row + dr * i, cc = s.col + dc * i;
        expect(s.fixed[i], g.at(rr, cc),
            reason: '${s.key} index $i 가 격자 ($rr,$cc)와 다름');
      }
      expect(s.crossings, s.fixed.length);
      expect(s.emptyCount, s.length - s.fixed.length);
    }
  });
}
