import 'package:test/test.dart';

import 'package:jgame/domain/generator/grid.dart';
import 'package:jgame/domain/generator/grid_rules.dart';
import 'package:jgame/domain/model/puzzle.dart';

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

void main() {
  group('canPlace', () {
    test('빈 격자 배치', () {
      final g = MutableGrid(5, 5);
      expect(GridRules.canPlace(g, '사과', 2, 0, Direction.across), isTrue);
    });

    test('범위 초과', () {
      final g = MutableGrid(5, 5);
      expect(GridRules.canPlace(g, '사과', 2, 4, Direction.across), isFalse);
    });

    test('교차 성공: 공유 음절 칸에서 수직으로 뻗는다', () {
      final g = MutableGrid(5, 5);
      g.place(pw('사과', 2, 0, Direction.across));
      expect(GridRules.canPlace(g, '사자', 2, 0, Direction.down), isTrue);
    });

    test('교차 음절 불일치', () {
      final g = MutableGrid(5, 5);
      g.place(pw('사과', 2, 0, Direction.across));
      expect(GridRules.canPlace(g, '나무', 2, 0, Direction.down), isFalse);
    });

    test('끝막음 위반: 우연한 4연속을 막는다', () {
      final g = MutableGrid(5, 5);
      g.place(const PlacedWord(
          headword: '사과',
          row: 2,
          col: 0,
          dir: Direction.across,
          isCore: true,
          tier: 1));
      expect(GridRules.canPlace(g, '나무', 2, 2, Direction.across), isFalse);
    });

    test('나란히 붙기 금지: 세로 2연속이 생긴다', () {
      final g = MutableGrid(5, 5);
      g.place(pw('사과', 2, 0, Direction.across));
      expect(GridRules.canPlace(g, '나무', 3, 0, Direction.across), isFalse);
    });

    test('중복 단어', () {
      final g = MutableGrid(5, 5);
      g.place(pw('사과', 2, 0, Direction.across));
      expect(GridRules.canPlace(g, '사과', 0, 0, Direction.across), isFalse);
    });

    test('덮어쓰기 금지: 같은 방향 단어를 품으면 그 단어가 사라진다', () {
      final g = MutableGrid(5, 5);
      g.place(pw('사과', 2, 1, Direction.across));
      // (2,0)~(2,3) 에 '가사과자' 를 놓으면 가로 연속이 '가사과자' 하나가 되어
      // 기존 '사과' 가 격자에서 사라진다 (규칙 2 위반).
      expect(GridRules.canPlace(g, '가사과자', 2, 0, Direction.across), isFalse);

      // 강제로 놓으면 실제로 validate가 규칙 2 위반을 잡는다 (위 금지의 근거).
      g.place(pw('가사과자', 2, 0, Direction.across));
      expect(
        GridRules.validate(g).any((e) => e.contains('격자에 없는 PlacedWord')),
        isTrue,
      );
    });
  });

  group('validate', () {
    test('정상: 교차 배치 2단어', () {
      final g = MutableGrid(5, 5);
      g.place(pw('사과', 2, 0, Direction.across));
      g.place(pw('사자', 2, 0, Direction.down));
      expect(GridRules.validate(g), isEmpty);
    });

    test('우연 연속 탐지: place로 규칙을 어기게 강제 배치', () {
      final g = MutableGrid(5, 5);
      g.place(pw('사과', 2, 0, Direction.across));
      g.place(pw('나무', 2, 2, Direction.across)); // canPlace를 건너뛴 강제 배치
      final errors = GridRules.validate(g);
      expect(errors, isNotEmpty);
      expect(errors.any((e) => e.contains('사과나무')), isTrue);
    });

    test('고립 2개: 연결 요소 3개는 에러', () {
      final g = MutableGrid(5, 5);
      g.place(pw('사과', 0, 0, Direction.across));
      g.place(pw('사자', 0, 0, Direction.down));
      g.place(pw('나무', 3, 0, Direction.across));
      g.place(pw('바다', 3, 3, Direction.across));
      final errors = GridRules.validate(g);
      expect(errors, isNotEmpty);
      expect(errors.any((e) => e.contains('연결 요소')), isTrue);
    });
  });

  group('components', () {
    test('교차 2개 + 떨어진 1개', () {
      final g = MutableGrid(5, 5);
      g.place(pw('사과', 2, 0, Direction.across));
      g.place(pw('사자', 2, 0, Direction.down));
      g.place(pw('나무', 0, 3, Direction.across));
      final comps = GridRules.components(g.placed);
      expect(comps.length, 2);
      final small = comps.map((c) => c.length).reduce((a, b) => a < b ? a : b);
      expect(small, 1);
      // 고립 1개는 허용이므로 validate는 통과한다.
      expect(GridRules.validate(g), isEmpty);
    });
  });

  group('unplace', () {
    test('복원: place → unplace 하면 이전 상태와 동일', () {
      final g = MutableGrid(5, 5);
      final before = [
        for (final row in g.syllables) List<String?>.from(row),
      ];
      final a = pw('사과', 2, 0, Direction.across);
      g.place(a);
      g.unplace(a);
      expect(g.syllables, before);
      expect(g.placed, isEmpty);
    });

    test('unplace는 교차 셀을 남긴다', () {
      final g = MutableGrid(5, 5);
      const a = PlacedWord(
          headword: '사과',
          row: 2,
          col: 0,
          dir: Direction.across,
          isCore: true,
          tier: 1);
      const b = PlacedWord(
          headword: '사자',
          row: 2,
          col: 0,
          dir: Direction.down,
          isCore: true,
          tier: 1);
      g.place(a);
      g.place(b);
      g.unplace(b);
      expect(g.at(2, 0), '사'); // a가 아직 쓰는 칸
      expect(g.at(3, 0), isNull); // b만 쓰던 칸
    });
  });
}
