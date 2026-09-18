// 퍼즐 화면 상태 (04-01 골격 · 04-02~04-05의 중심).
//
// `answers`가 셀 좌표 맵인 이유는 01-08(scorer)에 적혀 있다. 교차 셀에서
// 마지막 입력이 이기려면 격자 셀이 단일 진실이어야 한다. 단어별 입력 버퍼를
// 따로 두지 않는다. `Map<(int, int), String>`은 01-08의 `Answers` 타입 별칭과
// 정확히 같은 타입이다.
import 'package:flutter/material.dart';

import '../../data/hint_repository.dart';
import '../../domain/model/level_spec.dart';
import '../../domain/model/puzzle.dart';
import '../../domain/model/submit_result.dart';
import '../../domain/scoring/scorer.dart';
import 'app_scope.dart';
import 'settings_model.dart';

class PuzzleModel extends ChangeNotifier {
  final AppScope scope;
  final LevelSpec spec;

  Puzzle? puzzle;
  bool loading = true;
  Object? error;

  /// 격자 셀 → 유저 입력 음절. 단일 진실 (01-08 Answers와 같은 타입).
  ///
  /// `final`이 아니다 — `setWordInput`이 매번 **새 맵으로 통째로 교체**해야
  /// 한다(04-04 "격자에 분배" 주석 "새 맵 (04-02 shouldRepaint)"). 같은 맵을
  /// 제자리에서 비우고 다시 채우면(`clear()`+`addAll()`) 이전 프레임에서
  /// `GridPainter`가 캡처해 둔 `answers` 필드도 정확히 같은 객체를 가리키고
  /// 있어서 이미 바뀐 값을 보게 된다 — `shouldRepaint`의 `old.answers`와
  /// `answers`가 애초에 동일 인스턴스라 차이를 볼 수 없다. 그래서 필드
  /// 자체를 새 인스턴스로 바꿔야 한다.
  Map<(int, int), String> answers = {};

  /// 현재 선택된 단어. null이면 미선택
  PlacedWord? selected;

  /// 마지막으로 탭한 셀. 04-04 입력 커서 위치 표시에 쓴다.
  (int, int)? focusedCell;

  /// 표제어 → 힌트. `load`가 퍼즐 생성 직후 한 번에 채운다(04-03 "힌트 데이터
  /// 조회") — 탭할 때마다 DB를 치지 않는다.
  Map<String, Hint> hints = {};

  bool submitted = false;
  SubmitResult? result;

  PuzzleModel(this.scope, this.spec);

  Future<void> load(int seed) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      puzzle = await scope.generator.generate(spec, seed);
      hints = await scope.hints
          .forWords(puzzle!.words.map((w) => w.headword).toList());
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// 셀 탭 → 그 셀을 지나는 단어 중 하나 선택 (04-03 "선택 규칙").
  /// 가로 우선, 교차 셀을 다시 탭하면 세로로 토글.
  void selectCell(int r, int c) {
    final here = puzzle!.wordsAt(r, c); // 01-01 Puzzle.wordsAt
    if (here.isEmpty) return;

    if (here.length == 1) {
      selected = here.first;
    } else {
      // 교차 셀. 현재 선택이 이 셀의 단어 중 하나면 다음 것으로 토글
      final i = here.indexWhere((w) => _same(w, selected));
      if (i >= 0) {
        selected = here[(i + 1) % here.length];
      } else {
        // 가로 우선
        selected = here.firstWhere((w) => w.dir == Direction.across,
            orElse: () => here.first);
      }
    }
    focusedCell = (r, c);
    notifyListeners();
  }

  /// 선택된 단어의 힌트 텍스트를 고른다 (04-03 "힌트 선택").
  /// `HintMode`는 `SettingsModel`(04-01)에 있다 — 여기서는 값만 받는다.
  String hintTextFor(PlacedWord w, HintMode mode) {
    final h = hints[w.headword];
    if (h == null) return '(힌트 없음)';
    if (mode == HintMode.association && h.hasSynonyms) {
      return h.synonyms.join(', ');
    }
    return _mask(h.definition, w.headword);
  }

  /// 격자에 단어 입력을 분배한다 (04-04 "격자에 분배"). 교차 셀은 **마지막
  /// 입력이 이긴다** — 이 메서드가 그대로 덮어쓰므로 별도 처리가 필요 없다.
  void setWordInput(PlacedWord w, String text) {
    final next = Map<(int, int), String>.of(answers);
    var i = 0;
    for (final (r, c) in w.cells) {
      if (i < text.length) {
        next[(r, c)] = text[i];
      } else {
        next.remove((r, c)); // 지운 만큼 비운다
      }
      i++;
    }
    answers = next; // 새 맵으로 교체 — 위 `answers` 필드 주석 참고
    notifyListeners();
  }

  /// 선택된 단어의 현재 입력을 텍스트로 복원한다 (선택 전환 시 필드에 싣기
  /// 위함). 중간이 비면 거기까지만 반환한다 — 04-04 "부분 입력 허용"의 1차
  /// 방식("`사_과`처럼 가운데가 빈 상태를 텍스트 필드로 표현할 수 없다").
  String textOf(PlacedWord w) {
    final buf = StringBuffer();
    for (final (r, c) in w.cells) {
      final s = answers[(r, c)];
      if (s == null || s.isEmpty) break;
      buf.write(s);
    }
    return buf.toString();
  }

  /// 다음 단어로 이동한다. 번호 순(`puzzle.words` 순서, 04-03 numberCells가
  /// 훑는 순서와 일치)으로 단순 순환한다 — "빈 단어만 순회" 옵션은 04-04
  /// "다음 단어로 이동" 절이 1차 범위 밖으로 미뤘다.
  void selectNextWord() {
    if (puzzle == null) return;
    final order = puzzle!.words;
    if (order.isEmpty) return;
    final i = order.indexWhere((w) => _same(w, selected));
    selected = order[(i + 1) % order.length];
    notifyListeners();
  }

  /// 제출 (04-05 "제출 흐름"). 확인 다이얼로그 → 일괄 채점 → 통계 반영.
  /// `isFirstSubmit`를 먼저 조회해 [SubmitResult]에 담는다 — `recordSubmit`도
  /// 내부에서 다시 확인하지만(03-04), 결과 화면이 "이번 제출은 통계에 반영되지
  /// 않았습니다"를 표시하려면 값이 필요하다.
  Future<void> submit(BuildContext context) async {
    final blanks = Scorer.blankCellCount(puzzle!, answers); // 01-08

    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('제출하시겠습니까?'),
        content: Text(blanks > 0
            ? '빈 칸이 $blanks개 있습니다. 빈 칸은 오답으로 처리됩니다.'
            : '모든 칸을 채웠습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('계속 풀기')),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('제출')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final isFirst =
          await scope.stats.isFirstSubmit(puzzle!.levelId, puzzle!.seed);
      final r = Scorer.score(puzzle!, answers, isFirstSubmit: isFirst);
      await scope.stats.recordSubmit(
          levelId: puzzle!.levelId, seed: puzzle!.seed, result: r);

      submitted = true;
      result = r;
      notifyListeners();
    } catch (e) {
      // 갱신(05-04)으로 DB 연결이 닫힌 경우 등 — `submitted`/`result`를 세우지
      // 않는다. `_handleSubmit`(puzzle_page.dart)이 `result == null`을 "계속
      // 풀기"와 같은 경로로 처리해 결과 화면으로 넘어가지 않으므로, 통계를
      // 반영 못 한 채로 반영된 것처럼 보이는 일은 없다 — 대신 원인을 알린다.
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('제출할 수 없습니다'),
          content: const Text(
              '단어 데이터에 문제가 생겼습니다. 앱을 다시 시작한 뒤 다시 시도해 주세요.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('확인')),
          ],
        ),
      );
    }
  }

  /// "다시 풀기" (04-05 "버튼 동작"): 같은 seed로 같은 퍼즐 재도전.
  /// `puzzle`/`hints`는 그대로 둔다 — 같은 (levelId, seed)면 생성기가 결정적으로
  /// 같은 격자를 만들므로(01-07) 다시 생성할 필요가 없다. 입력·제출 상태만
  /// 초기화한다. `answers`를 `.clear()`가 아니라 **새 맵으로 교체**하는 이유는
  /// 위 `answers` 필드 주석과 같다 — 같은 인스턴스를 제자리에서 비우면
  /// `GridPainter.shouldRepaint`가 옛 참조와 새 참조가 동일 객체라 차이를 못
  /// 본다.
  void retry() {
    answers = {};
    selected = null;
    focusedCell = null;
    submitted = false;
    result = null;
    notifyListeners();
  }
}

/// 새 퍼즐 seed (04-05 "seed 생성 규칙"). `Puzzle.seed`가 `word_stat`의 첫 제출
/// 판정 키(03-04)이므로 "다음 레벨"마다 매번 달라야 한다.
int newSeed() => DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;

/// `PlacedWord`는 `==`를 재정의하지 않았다(01-01). 위치+방향으로 비교한다.
/// 같은 표제어가 한 격자에 두 번 안 나오므로(01-03 규칙 6) `headword` 비교도
/// 되지만, 위치 비교가 더 명시적이다. (04-04 `selectNextWord`도 재사용)
bool _same(PlacedWord a, PlacedWord? b) =>
    b != null && a.row == b.row && a.col == b.col && a.dir == b.dir;

/// 뜻풀이에 표제어 자체가 드러나면 안 된다 (04-03 "힌트에 답이 새면 안 된다").
/// `사과: 사과나무의 열매` 처럼 흔하다. 표제어를 마스킹한다.
/// 02단계에서 미리 마스킹하지 않는 이유는 `HintRepository` 주석 참고.
String _mask(String definition, String headword) =>
    definition.replaceAll(headword, '○' * headword.length);
