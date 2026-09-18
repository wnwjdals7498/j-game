// 07-04-02.clue-bar.md "테스트 test/ui/puzzle_screen_test.dart" (신규 —
// 13종 중 3종). `play_loop_test.dart`의 `openEmptyDb`/`buildScope`/`wrapApp`/
// `cellCenter` 헬퍼를 같은 모양으로 옮겨 온다. seed는 결정성을 위해 1000.
//
// 더미 DB(`openEmptyDb`)는 `sense` 테이블이 비어 있어 `PuzzleModel.hintTextFor`가
// 어떤 단어를 넣어도 항상 `'(힌트 없음)'`을 돌려준다(hint_repository.dart
// `forWords`가 빈 맵을 캐시). E-04 테스트가 이 상수를 그대로 쓰는 이유다 —
// 값 자체보다 `AnimatedSwitcher`가 이전·다음 자식을 **동시에** 들고 있다가
// (Key가 다르므로) 하나로 정리되는 타이밍을 본다.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:jgame/data/db/app_database.dart';
import 'package:jgame/data/hint_repository.dart';
import 'package:jgame/data/stat_repository.dart';
import 'package:jgame/domain/fixtures/dummy_dictionary.dart';
import 'package:jgame/domain/generator/grid_generator.dart';
import 'package:jgame/domain/levels.dart';
import 'package:jgame/domain/model/puzzle.dart';
import 'package:jgame/domain/scoring/scorer.dart';
import 'package:jgame/ui/puzzle/clue_bar.dart';
import 'package:jgame/ui/puzzle/grid_view.dart';
import 'package:jgame/ui/puzzle/puzzle_page.dart';
import 'package:jgame/ui/puzzle/submit_button.dart';
import 'package:jgame/ui/puzzle/word_numbering.dart';
import 'package:jgame/ui/state/app_scope.dart';
import 'package:jgame/ui/state/puzzle_model.dart';
import 'package:jgame/ui/state/settings_model.dart';
import 'package:jgame/ui/theme/app_theme.dart';
import 'package:jgame/ui/theme/motion.dart';
import 'package:jgame/ui/theme/tokens.dart';

void main() {
  late Directory tmp;
  late String schemaSql;
  var dbSeq = 0;

  setUpAll(() {
    schemaSql = File('../tools/schema.sql').readAsStringSync();
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('puzzle_screen_test_');
    dbSeq = 0;
    // 튜토리얼 시트(07-04-04)가 뜨지 않게 이미 본 것으로 표시한다 — 이
    // 파일의 나머지 테스트는 튜토리얼과 무관하다. 튜토리얼 자체를 보는
    // 테스트는 아래에서 값을 다시 지정한다.
    SharedPreferences.setMockInitialValues({tutorialSeenPrefsKey: true});
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

  AppScope buildScope(AppDatabase db) {
    final words = InMemoryWordRepository(buildDummyDictionary(seed: 1));
    return AppScope(
      db: db,
      words: words,
      stats: StatRepository(db),
      generator: GridGenerator(words),
      hints: HintRepository(db),
    );
  }

  Widget wrapApp(AppScope scope, Widget child) => MultiProvider(
        providers: [
          Provider<AppScope>.value(value: scope),
          ChangeNotifierProvider(create: (_) => SettingsModel()),
        ],
        child: MaterialApp(
          theme: buildLightTheme(), // ClueBar가 GameColors.of(context)를 읽는다
          home: child,
        ),
      );

  /// 격자 위 (row, col) 셀 중앙의 화면 좌표. play_loop_test.dart(04-07)의
  /// `cellCenter`와 같은 방식 — 고정 좌표 대신 위젯의 실제 렌더 크기로
  /// 계산한다.
  Offset cellCenter(WidgetTester tester, Puzzle puzzle, int row, int col) {
    final topLeft = tester.getTopLeft(find.byType(PuzzleGridView));
    final size = tester.getSize(find.byType(PuzzleGridView));
    final cell = size.width / puzzle.width;
    return topLeft + Offset(cell * (col + 0.5), cell * (row + 0.5));
  }

  /// H-01 테스트 전용 2×2 교차 격자 — word_input_test.dart(04-04)의
  /// `_crossPuzzle`과 같은 모양. 실제 생성기 결과는 격자마다 교차 구조가
  /// 달라 "교차 셀이 아닌 칸"이 항상 한 단어에만 속한다고 보장할 수
  /// 없다 — 탭 위치별 기대 동작(선택 변경/토글/유지)을 명확히 고정하기
  /// 위해 손으로 만든 격자로 `model.puzzle`을 교체한다.
  /// - '사과' 가로 (0,0)~(0,1)
  /// - '사슴' 세로 (0,0)~(1,0) — (0,0)에서 교차
  Puzzle crossPuzzle() {
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

  /// 07-04-05 "햅틱 테스트 방법": `HapticFeedback.*`는 `SystemChannels.platform`의
  /// `HapticFeedback.vibrate` 메서드 호출이다. `pumpWidget` **전에** 걸어야
  /// 등록 이후의 호출을 받는다("막히면"). 세기별 인자 문자열은 플랫폼·버전에
  /// 따라 다를 수 있으므로 횟수만 센다.
  List<String?> recordHapticCalls(WidgetTester tester) {
    final calls = <String?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          calls.add(call.arguments as String?);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    return calls;
  }

  group('ClueBar (07-04-02)', () {
    testWidgets('ClueBar 미선택: 안내 문구와 비활성 화살표', (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(
          wrapApp(buildScope(db), PuzzlePage(spec: levels.first, seed: 1000)));
      await tester.pumpAndSettle();

      // 진입 직후 아직 아무 칸도 탭하지 않았으므로 미선택 상태다.
      expect(
        find.descendant(
            of: find.byType(ClueBar), matching: find.text('칸을 눌러 단어를 고르세요')),
        findsNWidgets(2),
        reason: 'ClueBar 본문 1 + WordInput의 TextField 힌트 1 (둘 다 의도된 INV-09 문구)',
      );

      final prev = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_left));
      final next = tester.widget<IconButton>(
          find.widgetWithIcon(IconButton, Icons.chevron_right));
      expect(prev.onPressed, isNull);
      expect(next.onPressed, isNull);
    });

    testWidgets('◀ ▶: 다음·이전 단어로 이동', (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(
          wrapApp(buildScope(db), PuzzlePage(spec: levels.first, seed: 1000)));
      await tester.pumpAndSettle();

      final model = Provider.of<PuzzleModel>(
          tester.element(find.byType(PuzzleGridView)),
          listen: false);
      final puzzle = model.puzzle!;
      final numbers = numberCells(puzzle);

      // 모델 상태를 직접 세팅해 시작점을 고정한다 — 탭으로 고르면 교차 셀
      // 규칙(04-03 "가로 우선")상 words[0]이 아닌 단어가 선택될 수 있다.
      model.selected = puzzle.words[0];
      model.notifyListeners();
      await tester.pump();

      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_right));
      await tester.pumpAndSettle();

      final wordB = puzzle.words[1];
      expect(model.selected, same(wordB));
      final dirLabel = wordB.dir == Direction.across ? '가로' : '세로';
      final number = numbers[(wordB.row, wordB.col)];
      final badgeText = number == null ? dirLabel : '$dirLabel $number';
      expect(
        find.descendant(
            of: find.byType(ClueBar), matching: find.text(badgeText)),
        findsOneWidget,
        reason: '▶ 이동 후 배지가 새로 선택된 단어의 방향·번호를 보여줘야 한다',
      );

      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(model.selected, same(puzzle.words.last));
    });

    testWidgets('E-04: 힌트가 크로스페이드로 교체된다', (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(
          wrapApp(buildScope(db), PuzzlePage(spec: levels.first, seed: 1000)));
      await tester.pumpAndSettle();

      final model = Provider.of<PuzzleModel>(
          tester.element(find.byType(PuzzleGridView)),
          listen: false);
      final puzzle = model.puzzle!;

      model.selected = puzzle.words[0];
      model.notifyListeners();
      await tester.pump();

      // 더미 DB엔 sense 행이 없어 A·B 둘 다 같은 힌트 문구를 받는다 — 그래도
      // AnimatedSwitcher는 Key가 다른 두 자식을 별개로 취급하므로, 전환 중
      // 이 문구를 가진 Text가 정확히 2개(이전·다음) 동시에 존재해야 한다.
      const hintText = '(힌트 없음)';

      await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_right));
      // 전환 중간 지점 하나만 콕 집어 확인한다 — 바로 뒤 `pump()`(경과 시간
      // 0)는 이 SDK의 fake-async 시계에서 그 프레임에 진행 중인 전환을 바로
      // 끝내버릴 수 있어(프레임 경계 특이 동작) 대신 grid_view_test.dart
      // (E-01/E-02)와 같은 방식으로 `base`의 절반만큼만 흘려보낸다.
      await tester.pump(GameMotion.standard.base ~/ 2);

      expect(
        find.descendant(
            of: find.byType(ClueBar), matching: find.text(hintText)),
        findsNWidgets(2),
        reason: 'E-04 전환 중엔 이전 단어·다음 단어의 힌트 Text가 동시에 있어야 한다',
      );

      // 전환이 끝났는지는 정확한 지속 시간만큼 `pump`하는 대신
      // `pumpAndSettle()`로 확인한다 — 남은 시간만큼만 `pump`하면 전환이
      // "끝났다"는 상태(dismissed)는 됐어도 그 상태 변화로 옛 항목을 트리에서
      // 지우는 `setState`가 아직 다음 프레임에 반영되지 않아 위젯이 한 프레임
      // 더 남아 있을 수 있다(프레임 경계 특이 동작, grid motion 테스트들과
      // 달리 여기선 위젯 트리 자체의 존재 여부를 보므로 이 차이가 드러난다).
      await tester.pumpAndSettle();

      expect(
        find.descendant(
            of: find.byType(ClueBar), matching: find.text(hintText)),
        findsOneWidget,
        reason: '전환이 끝나면 다음 단어의 힌트 Text 하나만 남아야 한다',
      );
    });
  });

  group('진행 배지 · SubmitButton (07-04-03)', () {
    testWidgets('진행 배지 초기값: 0 / N', (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(
          wrapApp(buildScope(db), PuzzlePage(spec: levels.first, seed: 1000)));
      await tester.pumpAndSettle();

      final model = Provider.of<PuzzleModel>(
          tester.element(find.byType(PuzzleGridView)),
          listen: false);
      final total = model.puzzle!.words.length;

      expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.text('0 / $total')),
        findsOneWidget,
      );
      expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.byIcon(Icons.check)),
        findsNothing,
      );
    });

    testWidgets('진행 배지 갱신: 한 단어 완성 → 1 / N', (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(
          wrapApp(buildScope(db), PuzzlePage(spec: levels.first, seed: 1000)));
      await tester.pumpAndSettle();

      final model = Provider.of<PuzzleModel>(
          tester.element(find.byType(PuzzleGridView)),
          listen: false);
      final puzzle = model.puzzle!;
      final total = puzzle.words.length;
      final word = puzzle.words.first;
      final (r0, c0) = word.cells.first;

      // grid_view_test.dart · play_loop_test.dart의 `cellCenter`와 같은 방식:
      // 고정 좌표 대신 위젯의 실제 렌더 크기로 계산한다.
      final topLeft = tester.getTopLeft(find.byType(PuzzleGridView));
      final size = tester.getSize(find.byType(PuzzleGridView));
      final cell = size.width / puzzle.width;
      await tester
          .tapAt(topLeft + Offset(cell * (c0 + 0.5), cell * (r0 + 0.5)));
      await tester.pumpAndSettle();

      final selected = model.selected!;
      final answer = selected.cells
          .map((c) => puzzle.cellAt(c.$1, c.$2).solution!)
          .join();
      await tester.enterText(find.byType(TextField), answer);
      await tester.pump(GameMotion.standard.fast);

      expect(
        find.descendant(
            of: find.byType(AppBar), matching: find.text('1 / $total')),
        findsOneWidget,
      );
    });

    testWidgets('제출 버튼 보조 → 기본', (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(
          wrapApp(buildScope(db), PuzzlePage(spec: levels.first, seed: 1000)));
      await tester.pumpAndSettle();

      final model = Provider.of<PuzzleModel>(
          tester.element(find.byType(PuzzleGridView)),
          listen: false);
      final puzzle = model.puzzle!;

      Container submitContainer() => tester.widget<Container>(find.descendant(
          of: find.byType(SubmitButton), matching: find.byType(Container)));

      final before = submitContainer().decoration as BoxDecoration;
      expect(before.color, Colors.transparent);

      model.answers = Scorer.solutionOf(puzzle);
      model.notifyListeners();
      // `pump(motion.base)`을 그대로 쓰면 상태 변화(→ active: true)에 따른
      // 위젯 재빌드가 이 프레임의 애니메이션 tick *다음*에 일어나 —
      // `AnimatedContainer`가 새 목표를 인식하고 컨트롤러를 리셋하는 시점이
      // 같은 프레임의 tick 이후라 — 이번 pump 안에서는 보간이 전혀
      // 진행되지 않는다(시작값 그대로). E-04 테스트의 "프레임 경계 특이
      // 동작"과 같은 종류의 문제라 같은 해법을 쓴다: `pumpAndSettle()`로
      // 전환이 끝난 뒤의 값을 읽는다.
      await tester.pumpAndSettle();

      final after = submitContainer().decoration as BoxDecoration;
      expect(after.color, GameColors.light.ink);
    });
  });

  group('바텀 시트 (07-04-04)', () {
    testWidgets('제출 버튼은 빈칸이 있어도 눌린다', (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(
          wrapApp(buildScope(db), PuzzlePage(spec: levels.first, seed: 1000)));
      await tester.pumpAndSettle();

      // 아무 칸도 채우지 않은 채로 바로 제출 — E-05 규칙대로 눌려야 한다.
      await tester.tap(find.text('제출'));
      await tester.pumpAndSettle();

      expect(find.textContaining('빈 칸이'), findsOneWidget);
    });

    testWidgets('제출 확인이 바텀 시트다', (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(
          wrapApp(buildScope(db), PuzzlePage(spec: levels.first, seed: 1000)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('제출'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('계속 풀기'), findsOneWidget);
      // 페이지의 SubmitButton(가려짐) + 시트 확인 버튼 = 2. `.last`가 시트
      // 쪽을 가리킨다는 문서 계약("시트 안에 '제출'이 두 번 나오면 안
      // 된다")을 실제로 지키는지도 함께 확인한다.
      expect(find.text('제출'), findsNWidgets(2));
    });

    testWidgets('튜토리얼이 바텀 시트다', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(
          wrapApp(buildScope(db), PuzzlePage(spec: levels.first, seed: 1000)));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('이렇게 플레이해요'), findsOneWidget);
    });
  });

  group('햅틱 (07-04-05)', () {
    testWidgets('H-01: 단어 선택이 바뀌면 햅틱 1회', (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);
      final calls = recordHapticCalls(tester); // pumpWidget 전에 걸어야 한다.

      await tester.pumpWidget(
          wrapApp(buildScope(db), PuzzlePage(spec: levels.first, seed: 1000)));
      await tester.pumpAndSettle();

      // 탭 위치별 기대 동작을 명확히 고정하기 위해 손으로 만든 2×2 교차
      // 격자로 바꾼다(위 `crossPuzzle` 주석 참고).
      final model = Provider.of<PuzzleModel>(
          tester.element(find.byType(PuzzleGridView)), listen: false);
      final puzzle = crossPuzzle();
      model.puzzle = puzzle;
      model.answers = {};
      model.selected = null;
      model.notifyListeners();
      await tester.pump();

      final wordA = puzzle.words[0]; // '사과' 가로 (0,0)(0,1)
      final wordB = puzzle.words[1]; // '사슴' 세로 (0,0)(1,0)

      // 1) 미선택 → wordA 전용 칸(0,1) 탭: "선택 변경"이므로 1회.
      await tester.tapAt(cellCenter(tester, puzzle, 0, 1));
      await tester.pumpAndSettle();
      expect(model.selected, same(wordA));
      expect(calls.length, 1, reason: '다른 단어 셀 탭 → 1회');

      // 2) 교차 셀(0,0) 재탭: wordA가 선택된 상태에서 그 교차 칸을 탭하면
      //    04-03 "선택 규칙"대로 방향이 토글돼 wordB로 바뀐다 → 다시 1회.
      await tester.tapAt(cellCenter(tester, puzzle, 0, 0));
      await tester.pumpAndSettle();
      expect(model.selected, same(wordB));
      expect(calls.length, 2, reason: '교차 셀 재탭(방향 토글) → 1회 추가');

      // 3) wordB 전용 칸(1,0) 탭: 선택된 단어 인스턴스가 그대로이므로
      //    추가 호출 없음.
      await tester.tapAt(cellCenter(tester, puzzle, 1, 0));
      await tester.pumpAndSettle();
      expect(model.selected, same(wordB));
      expect(calls.length, 2, reason: '같은 단어의 다른 칸 탭 → 0회 추가');
    });

    testWidgets('H-02: 단어를 다 채우면 햅틱 1회', (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);
      final calls = recordHapticCalls(tester);

      await tester.pumpWidget(
          wrapApp(buildScope(db), PuzzlePage(spec: levels.first, seed: 1000)));
      await tester.pumpAndSettle();

      final model = Provider.of<PuzzleModel>(
          tester.element(find.byType(PuzzleGridView)), listen: false);
      final puzzle = model.puzzle!;
      final word = puzzle.words.first;
      final (r0, c0) = word.cells.first;

      await tester.tapAt(cellCenter(tester, puzzle, r0, c0));
      await tester.pumpAndSettle();
      expect(model.selected, same(word));
      final afterSelect = calls.length; // H-01(선택) 몫 — 이 테스트의 대상이 아니다.

      final answer =
          word.cells.map((c) => puzzle.cellAt(c.$1, c.$2).solution!).join();

      // 중간 음절: 마지막 한 글자를 남긴다 → 아직 안 울려야 한다.
      await tester.enterText(
          find.byType(TextField), answer.substring(0, answer.length - 1));
      await tester.pump();
      expect(calls.length, afterSelect, reason: '중간 음절에서는 0회');

      // 마지막 음절: 완성 → 1회.
      await tester.enterText(find.byType(TextField), answer);
      await tester.pump();
      expect(calls.length, afterSelect + 1, reason: '마지막 음절 입력에서 1회');
    });

    testWidgets('H-03: 제출 확정에 햅틱 1회', (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);
      final calls = recordHapticCalls(tester);

      await tester.pumpWidget(
          wrapApp(buildScope(db), PuzzlePage(spec: levels.first, seed: 1000)));
      await tester.pumpAndSettle();

      // "계속 풀기": result가 그대로이므로 울리지 않는다.
      await tester.tap(find.text('제출'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('계속 풀기'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty, reason: '계속 풀기 → 0회');

      // 제출 확정: result가 새로 생기므로 1회.
      await tester.tap(find.text('제출'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('제출').last);
      await tester.pumpAndSettle();
      expect(calls.length, 1, reason: '제출 확정 → 1회');
    });
  });

  group('감소 모션 (07-04-05)', () {
    testWidgets('감소 모션: E-04·E-05가 즉시 최종 상태', (tester) async {
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(wrapApp(
        buildScope(db),
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: PuzzlePage(spec: levels.first, seed: 1000),
        ),
      ));
      await tester.pumpAndSettle();

      final model = Provider.of<PuzzleModel>(
          tester.element(find.byType(PuzzleGridView)), listen: false);
      final puzzle = model.puzzle!;

      // E-04: disableAnimations면 힌트 전환이 pump() 한 프레임으로 끝나야
      // 한다 — 더미 DB엔 sense 행이 없어 두 단어 모두 같은 문구를 받지만
      // (E-04 테스트와 같은 근거), 위젯 개수로 "하나만 남았는지"를 본다.
      model.selected = puzzle.words[0];
      model.notifyListeners();
      await tester.pump();
      model.selected = puzzle.words[1];
      model.notifyListeners();
      await tester.pump();

      final newHint = model.hintTextFor(puzzle.words[1], HintMode.definition);
      expect(
        find.descendant(of: find.byType(ClueBar), matching: find.text(newHint)),
        findsOneWidget,
        reason: 'disableAnimations면 E-04가 즉시 끝나 새 힌트 하나만 남아야 한다',
      );

      // E-05: 전부 채우면 제출 버튼 배경도 pump() 한 프레임으로 `ink`가
      // 돼야 한다.
      model.answers = Scorer.solutionOf(puzzle);
      model.notifyListeners();
      await tester.pump();

      final container = tester.widget<Container>(find.descendant(
          of: find.byType(SubmitButton), matching: find.byType(Container)));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, GameColors.light.ink);
    });
  });
}
