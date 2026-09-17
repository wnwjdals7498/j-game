// 퍼즐 화면 상태 (04-01 골격 · 04-02~04-05의 중심).
//
// `answers`가 셀 좌표 맵인 이유는 01-08(scorer)에 적혀 있다. 교차 셀에서
// 마지막 입력이 이기려면 격자 셀이 단일 진실이어야 한다. 단어별 입력 버퍼를
// 따로 두지 않는다. `Map<(int, int), String>`은 01-08의 `Answers` 타입 별칭과
// 정확히 같은 타입이다.
import 'package:flutter/foundation.dart';

import '../../data/hint_repository.dart';
import '../../domain/model/level_spec.dart';
import '../../domain/model/puzzle.dart';
import '../../domain/model/submit_result.dart';
import 'app_scope.dart';
import 'settings_model.dart';

class PuzzleModel extends ChangeNotifier {
  final AppScope scope;
  final LevelSpec spec;

  Puzzle? puzzle;
  bool loading = true;
  Object? error;

  /// 격자 셀 → 유저 입력 음절. 단일 진실 (01-08 Answers와 같은 타입)
  final Map<(int, int), String> answers = {};

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
}

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
