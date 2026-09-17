// 퍼즐 화면 상태 (04-01 골격 · 04-02~04-05의 중심).
//
// `answers`가 셀 좌표 맵인 이유는 01-08(scorer)에 적혀 있다. 교차 셀에서
// 마지막 입력이 이기려면 격자 셀이 단일 진실이어야 한다. 단어별 입력 버퍼를
// 따로 두지 않는다. `Map<(int, int), String>`은 01-08의 `Answers` 타입 별칭과
// 정확히 같은 타입이다.
import 'package:flutter/foundation.dart';

import '../../domain/model/level_spec.dart';
import '../../domain/model/puzzle.dart';
import '../../domain/model/submit_result.dart';
import 'app_scope.dart';

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

  bool submitted = false;
  SubmitResult? result;

  PuzzleModel(this.scope, this.spec);

  Future<void> load(int seed) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      puzzle = await scope.generator.generate(spec, seed);
    } catch (e) {
      error = e;
    } finally {
      loading = false;
      notifyListeners();
    }
  }
}
