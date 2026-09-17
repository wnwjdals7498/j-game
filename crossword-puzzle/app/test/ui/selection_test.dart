// 04-03 단어 선택·힌트 패널 테스트.
//
// "선택 규칙"·"힌트 선택" 그룹은 `PuzzleModel`을 직접 조작한다(04-02
// grid_view_test.dart와 같은 방식: 실 생성기를 돌리지 않고 `Puzzle`을 손으로
// 만들어 `model.puzzle`에 꽂는다). `AppScope`는 생성자 계약을 채우기 위해서만
// 필요하고 이 그룹의 테스트들은 DB를 실제로 건드리지 않는다.
//
// "힌트 일괄 조회" 그룹만 `tools/schema.sql`(단일 진실)로 만든 실 DB에 대해
// `HintRepository`를 직접 테스트한다 (stat_repository_test.dart 03-04와 같은
// 패턴).
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:jgame/data/db/app_database.dart';
import 'package:jgame/data/hint_repository.dart';
import 'package:jgame/data/stat_repository.dart';
import 'package:jgame/domain/fixtures/dummy_dictionary.dart';
import 'package:jgame/domain/generator/grid_generator.dart';
import 'package:jgame/domain/model/level_spec.dart';
import 'package:jgame/domain/model/puzzle.dart';
import 'package:jgame/ui/puzzle/word_numbering.dart';
import 'package:jgame/ui/state/app_scope.dart';
import 'package:jgame/ui/state/puzzle_model.dart';
import 'package:jgame/ui/state/settings_model.dart';

/// "선택 규칙" 테스트용 격자. 5×3.
/// - '가나다' 가로 (0,0)~(0,2)
/// - '나비야' 세로 (0,1)~(2,1) — (0,1)에서 '가나다'와 교차
/// - '다람쥐' 가로 (2,2)~(2,4) — 다른 단어와 교차 없음
/// - (1,0)은 어느 단어도 지나지 않는 검은 칸
Puzzle _crossPuzzle() {
  const width = 5, height = 3;
  final cells = List.generate(
    height,
    (r) => List.generate(width, (c) {
      if (r == 1 && c == 0) return const Cell.blocked();
      return const Cell.filled('가');
    }),
  );
  return Puzzle(
    levelId: 1,
    width: width,
    height: height,
    cells: cells,
    words: const [
      PlacedWord(
        headword: '가나다',
        row: 0,
        col: 0,
        dir: Direction.across,
        isCore: false,
        tier: 1,
      ),
      PlacedWord(
        headword: '나비야',
        row: 0,
        col: 1,
        dir: Direction.down,
        isCore: true,
        tier: 2,
      ),
      PlacedWord(
        headword: '다람쥐',
        row: 2,
        col: 2,
        dir: Direction.across,
        isCore: false,
        tier: 1,
      ),
    ],
    seed: 1,
    attempts: 1,
  );
}

LevelSpec _spec() => const LevelSpec(
      id: 1,
      name: 'test',
      width: 5,
      height: 3,
      coreTier: 1,
      coreCount: 1,
      fillQuotas: [TierQuota(1, 1, 1)],
    );

void main() {
  late Directory tmp;
  late String schemaSql;
  var dbSeq = 0;

  setUpAll(() {
    schemaSql = File('../tools/schema.sql').readAsStringSync();
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('selection_test_');
    dbSeq = 0;
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  AppDatabase openEmptyDb() {
    final path = '${tmp.path}/t${dbSeq++}.sqlite';
    final raw = sqlite3.open(path);
    raw.execute(schemaSql);
    raw.close();
    return AppDatabase(NativeDatabase(File(path)));
  }

  /// 선택·힌트 로직만 보는 테스트용 `PuzzleModel`. `scope`는 생성자 계약을
  /// 채울 뿐 `load()`는 호출하지 않으므로 DB는 비어 있어도 된다.
  PuzzleModel newModel() {
    final db = openEmptyDb();
    addTearDown(db.close);
    final words = InMemoryWordRepository(buildDummyDictionary(seed: 1));
    final scope = AppScope(
      db: db,
      words: words,
      stats: StatRepository(db),
      generator: GridGenerator(words),
      hints: HintRepository(db),
    );
    return PuzzleModel(scope, _spec());
  }

  group('선택 규칙', () {
    late Puzzle puzzle;

    setUp(() {
      puzzle = _crossPuzzle();
    });

    test('단일 단어 셀 탭 → 그 단어 선택', () {
      final model = newModel()..puzzle = puzzle;
      model.selectCell(0, 0);
      expect(model.selected?.headword, '가나다');
    });

    test('교차 셀 첫 탭 → 가로 단어 선택', () {
      final model = newModel()..puzzle = puzzle;
      model.selectCell(0, 1);
      expect(model.selected?.headword, '가나다');
      expect(model.selected?.dir, Direction.across);
    });

    test('교차 셀 두 번째 탭 → 세로 단어로 토글', () {
      final model = newModel()..puzzle = puzzle;
      model.selectCell(0, 1);
      model.selectCell(0, 1);
      expect(model.selected?.headword, '나비야');
      expect(model.selected?.dir, Direction.down);
    });

    test('교차 셀 세 번째 탭 → 다시 가로 (순환)', () {
      final model = newModel()..puzzle = puzzle;
      model.selectCell(0, 1);
      model.selectCell(0, 1);
      model.selectCell(0, 1);
      expect(model.selected?.headword, '가나다');
      expect(model.selected?.dir, Direction.across);
    });

    test('다른 단어 셀 탭 → 새 단어 선택', () {
      final model = newModel()..puzzle = puzzle;
      model.selectCell(0, 0);
      model.selectCell(2, 3); // '다람쥐'만 지나는 셀
      expect(model.selected?.headword, '다람쥐');
    });

    test('검은 칸 탭 → 선택 변화 없음', () {
      final model = newModel()..puzzle = puzzle;
      model.selectCell(0, 0);
      final before = model.selected;
      model.selectCell(1, 0); // 어느 단어도 지나지 않는 칸
      expect(model.selected, same(before));
    });

    test('focusedCell 갱신 → 탭한 셀로', () {
      final model = newModel()..puzzle = puzzle;
      model.selectCell(2, 3);
      expect(model.focusedCell, (2, 3));
    });
  });

  group('힌트 선택', () {
    const word = PlacedWord(
      headword: '나무',
      row: 0,
      col: 0,
      dir: Direction.across,
      isCore: false,
      tier: 1,
    );

    test('힌트 — 기본 모드: 뜻풀이 반환', () {
      final model = newModel();
      model.hints = {
        '나무': const Hint('줄기가 목질로 된 식물.', ['수목', '목본']),
      };
      expect(
        model.hintTextFor(word, HintMode.definition),
        '줄기가 목질로 된 식물.',
      );
    });

    test('힌트 — 연상어 모드, 유의어 있음: 유의어 반환', () {
      final model = newModel();
      model.hints = {
        '나무': const Hint('줄기가 목질로 된 식물.', ['수목', '목본']),
      };
      expect(
        model.hintTextFor(word, HintMode.association),
        '수목, 목본',
      );
    });

    test('힌트 — 연상어 모드, 유의어 없음: 뜻풀이로 폴백', () {
      final model = newModel();
      model.hints = {'나무': const Hint('줄기가 목질로 된 식물.', [])};
      expect(
        model.hintTextFor(word, HintMode.association),
        '줄기가 목질로 된 식물.',
      );
    });

    test('표제어 마스킹: 뜻풀이에 표제어가 없고 ○로 대체', () {
      final model = newModel();
      const apple = PlacedWord(
        headword: '사과',
        row: 0,
        col: 0,
        dir: Direction.across,
        isCore: false,
        tier: 1,
      );
      model.hints = {'사과': const Hint('사과나무의 열매.', [])};
      final text = model.hintTextFor(apple, HintMode.definition);
      expect(text, '○○나무의 열매.');
      expect(text.contains('사과'), isFalse);
    });

    test('힌트 없는 단어: (힌트 없음), 크래시 없음', () {
      final model = newModel();
      const noHint = PlacedWord(
        headword: '모름말',
        row: 0,
        col: 0,
        dir: Direction.across,
        isCore: false,
        tier: 1,
      );
      expect(
        () => model.hintTextFor(noHint, HintMode.definition),
        returnsNormally,
      );
      expect(model.hintTextFor(noHint, HintMode.definition), '(힌트 없음)');
    });
  });

  group('힌트 일괄 조회', () {
    test('단어 수만큼 조회, DB 호출 1회', () async {
      final path = '${tmp.path}/hint.sqlite';
      final raw = sqlite3.open(path);
      raw.execute(schemaSql);
      raw.close();
      final db = _CountingAppDatabase(NativeDatabase(File(path)));
      addTearDown(db.close);

      Future<void> insertWord(String hw, {int tier = 1}) async {
        final s = hw.split('');
        await db.customStatement(
          'INSERT INTO word (headword, len, c1, c2, c3, c4, c5, tier, pos, source) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            hw,
            s.length,
            s[0],
            s.length > 1 ? s[1] : null,
            s.length > 2 ? s[2] : null,
            s.length > 3 ? s[3] : null,
            s.length > 4 ? s[4] : null,
            tier,
            '명사',
            1,
          ],
        );
      }

      Future<void> insertSense(
        String senseId,
        String hw,
        String definition, {
        String? synonyms,
      }) async {
        await db.customStatement(
          'INSERT INTO sense (sense_id, headword, definition, synonyms, source) '
          'VALUES (?, ?, ?, ?, ?)',
          [senseId, hw, definition, synonyms, 1],
        );
      }

      await insertWord('사과');
      await insertWord('나무');
      await insertWord('바나나');
      await insertSense('s1', '사과', '사과나무의 열매.', synonyms: '능금');
      await insertSense('s2', '나무', '줄기가 목질로 된 식물.');
      await insertSense('s3', '바나나', '길쭉하고 노란 열대 과일.');

      db.selectCalls = 0; // 위 준비 과정의 호출은 세지 않는다.
      final repo = HintRepository(db);
      final result = await repo.forWords(['사과', '나무', '바나나']);

      expect(result.length, 3, reason: '단어 수만큼 조회됨');
      expect(result['사과']!.hasSynonyms, isTrue);
      expect(result['나무']!.hasSynonyms, isFalse);
      expect(db.selectCalls, 1, reason: '단어 수와 무관하게 DB 호출은 1회');
    });
  });

  group('번호 매기기', () {
    test('위→아래, 왼→오른쪽. 교차 시작점은 번호 공유', () {
      final p = Puzzle(
        levelId: 1,
        width: 3,
        height: 3,
        cells: List.generate(
          3,
          (_) => List.generate(3, (_) => const Cell.filled('가')),
        ),
        words: const [
          // (0,0)에서 가로·세로가 동시에 시작 → 번호 공유
          PlacedWord(
            headword: '가나다',
            row: 0,
            col: 0,
            dir: Direction.across,
            isCore: false,
            tier: 1,
          ),
          PlacedWord(
            headword: '가마솥',
            row: 0,
            col: 0,
            dir: Direction.down,
            isCore: false,
            tier: 1,
          ),
          PlacedWord(
            headword: '라마',
            row: 2,
            col: 1,
            dir: Direction.across,
            isCore: false,
            tier: 1,
          ),
        ],
        seed: 1,
        attempts: 1,
      );

      final numbers = numberCells(p);
      expect(numbers[(0, 0)], 1, reason: '가장 위·왼쪽 시작 셀이 1번');
      expect(numbers[(2, 1)], 2);
      expect(numbers.length, 2,
          reason: '같은 셀에서 시작하는 두 단어는 번호 하나를 공유');
    });
  });
}

/// `customSelect` 호출 횟수를 세는 테스트 전용 서브클래스
/// (stat_repository_test.dart의 `_FaultyAppDatabase`와 같은 패턴).
class _CountingAppDatabase extends AppDatabase {
  _CountingAppDatabase(super.executor);
  int selectCalls = 0;

  @override
  Selectable<QueryRow> customSelect(
    String query, {
    List<Variable> variables = const [],
    Set<ResultSetImplementation> readsFrom = const {},
  }) {
    selectCalls++;
    return super.customSelect(query, variables: variables, readsFrom: readsFrom);
  }
}
