// 04-04 단어 입력(한국어 IME) 테스트.
//
// "committedSyllables" 그룹은 순수 함수 단위 테스트다. `WordInput` 위젯
// 테스트("길이 초과 차단", "선택 전환 시 필드 교체", "미선택 상태")는 위젯을
// 직접 pump해서 확인하고, `PuzzleModel` 관련 그룹(격자 분배·부분 입력·
// 지우기·교차 덮어쓰기·textOf·answers 새 맵·다음 단어 순환)은 selection_test.dart
// (04-03)와 같은 방식으로 `PuzzleModel`을 직접 조작한다 — 실 생성기를 돌리지
// 않고 `Puzzle`을 손으로 만들어 `model.puzzle`에 꽂는다. `AppScope`는 생성자
// 계약을 채우기 위해서만 필요하고 이 테스트들은 DB를 실제로 건드리지 않는다.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:jgame/data/db/app_database.dart';
import 'package:jgame/data/hint_repository.dart';
import 'package:jgame/data/stat_repository.dart';
import 'package:jgame/domain/fixtures/dummy_dictionary.dart';
import 'package:jgame/domain/generator/grid_generator.dart';
import 'package:jgame/domain/model/level_spec.dart';
import 'package:jgame/domain/model/puzzle.dart';
import 'package:jgame/ui/puzzle/word_input.dart';
import 'package:jgame/ui/state/app_scope.dart';
import 'package:jgame/ui/state/puzzle_model.dart';

/// "격자 분배"류 테스트용 2×2 격자.
/// - '사과' 가로 (0,0)~(0,1)
/// - '사슴' 세로 (0,0)~(1,0) — (0,0)에서 '사과'와 교차
Puzzle _crossPuzzle() {
  const width = 2, height = 2;
  final cells = List.generate(
    height,
    (r) => List.generate(width, (c) => const Cell.filled('가')),
  );
  return Puzzle(
    levelId: 1,
    width: width,
    height: height,
    cells: cells,
    words: const [
      PlacedWord(
        headword: '사과',
        row: 0,
        col: 0,
        dir: Direction.across,
        isCore: false,
        tier: 1,
      ),
      PlacedWord(
        headword: '사슴',
        row: 0,
        col: 0,
        dir: Direction.down,
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
      width: 2,
      height: 2,
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
    tmp = Directory.systemTemp.createTempSync('word_input_test_');
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

  /// 입력 로직만 보는 테스트용 `PuzzleModel`. `scope`는 생성자 계약을 채울
  /// 뿐 `load()`는 호출하지 않으므로 DB는 비어 있어도 된다(04-03
  /// selection_test.dart와 같은 패턴).
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

  group('committedSyllables — 확정 음절만 남기기', () {
    test('완성형만: 조합 중 자모를 버린다', () {
      expect(committedSyllables('가ㄱㅏ각'), '가각');
    });

    test('영문·숫자 제거', () {
      expect(committedSyllables('가a1나'), '가나');
    });

    test('공백 제거', () {
      expect(committedSyllables('가 나'), '가나');
    });
  });

  group('WordInput 위젯', () {
    const wordA = PlacedWord(
      headword: '사과나무', // 4글자
      row: 0,
      col: 0,
      dir: Direction.across,
      isCore: false,
      tier: 1,
    );
    const wordB = PlacedWord(
      headword: '자두',
      row: 1,
      col: 0,
      dir: Direction.across,
      isCore: false,
      tier: 1,
    );

    Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('길이 초과 차단: 3글자 자리에 4글자 입력 → 3글자로 잘림',
        (tester) async {
      const word3 = PlacedWord(
        headword: '아버지',
        row: 0,
        col: 0,
        dir: Direction.across,
        isCore: false,
        tier: 1,
      );
      String? lastChanged;
      await tester.pumpWidget(wrap(WordInput(
        selected: word3,
        initialText: '',
        onChanged: (s) => lastChanged = s,
        onNext: () {},
      )));

      await tester.enterText(find.byType(TextField), '아바지다'); // 4글자
      await tester.pump();

      expect(lastChanged, '아바지', reason: '3글자 자리를 넘는 입력은 잘려야 한다');
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '아바지');
    });

    testWidgets('선택 전환 시 필드 교체: 다른 단어 선택 → 그 단어의 입력이 필드에',
        (tester) async {
      await tester.pumpWidget(wrap(WordInput(
        selected: wordA,
        initialText: '사과',
        onChanged: (_) {},
        onNext: () {},
      )));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '사과',
      );

      await tester.pumpWidget(wrap(WordInput(
        selected: wordB,
        initialText: '자두',
        onChanged: (_) {},
        onNext: () {},
      )));
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '자두',
        reason: '선택이 바뀌면 필드가 그 단어의 현재 입력으로 교체돼야 한다',
      );
    });

    testWidgets('미선택 상태: 필드 비활성, 힌트 텍스트 표시', (tester) async {
      await tester.pumpWidget(wrap(WordInput(
        selected: null,
        initialText: '',
        onChanged: (_) {},
        onNext: () {},
      )));

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.enabled, isFalse);
      expect(field.decoration?.hintText, '칸을 눌러 단어를 고르세요');
    });
  });

  group('PuzzleModel — 격자 분배', () {
    test('입력 "사과" → 셀 2개에 사, 과', () {
      final model = newModel()..puzzle = _crossPuzzle();
      final word = model.puzzle!.words.first; // '사과' 가로
      model.setWordInput(word, '사과');
      expect(model.answers[(0, 0)], '사');
      expect(model.answers[(0, 1)], '과');
    });

    test('부분 입력 "사" → 첫 칸만, 둘째 칸은 비움', () {
      final model = newModel()..puzzle = _crossPuzzle();
      final word = model.puzzle!.words.first;
      model.setWordInput(word, '사');
      expect(model.answers[(0, 0)], '사');
      expect(model.answers.containsKey((0, 1)), isFalse);
    });

    test('지우기: "사과" → "사" → 둘째 칸 비워짐', () {
      final model = newModel()..puzzle = _crossPuzzle();
      final word = model.puzzle!.words.first;
      model.setWordInput(word, '사과');
      expect(model.answers.containsKey((0, 1)), isTrue);
      model.setWordInput(word, '사');
      expect(model.answers.containsKey((0, 1)), isFalse);
    });

    test('교차 덮어쓰기: 가로 입력 후 세로 입력 → 교차 셀이 세로 값', () {
      final model = newModel()..puzzle = _crossPuzzle();
      final across = model.puzzle!.words[0]; // '사과'
      final down = model.puzzle!.words[1]; // '사슴'

      model.setWordInput(across, '사과');
      expect(model.answers[(0, 0)], '사');

      model.setWordInput(down, '자두'); // (0,0)='자', (1,0)='두'
      expect(model.answers[(0, 0)], '자', reason: '마지막 입력(세로)이 이겨야 한다');
      expect(model.answers[(1, 0)], '두');
    });

    test('textOf 복원: 격자 → 텍스트', () {
      final model = newModel()..puzzle = _crossPuzzle();
      final word = model.puzzle!.words.first;
      model.setWordInput(word, '사과');
      expect(model.textOf(word), '사과');
    });

    test('answers 새 맵: setWordInput 후 이전 맵과 다른 인스턴스', () {
      final model = newModel()..puzzle = _crossPuzzle();
      final word = model.puzzle!.words.first;
      final before = model.answers;
      model.setWordInput(word, '사과');
      expect(identical(model.answers, before), isFalse);
    });
  });

  group('PuzzleModel — 다음 단어 이동', () {
    test('다음 단어 순환: 마지막 → 첫 번째', () {
      final model = newModel()..puzzle = _crossPuzzle();
      final first = model.puzzle!.words[0];
      final last = model.puzzle!.words[1];
      model.selected = last;
      model.selectNextWord();
      expect(model.selected, same(first));
    });
  });
}
