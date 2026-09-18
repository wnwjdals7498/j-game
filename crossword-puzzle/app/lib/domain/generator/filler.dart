import 'dart:math';

import '../model/level_spec.dart';
import '../model/puzzle.dart';
import '../model/word_entry.dart';
import '../repository/word_repository.dart';
import 'grid.dart';
import 'grid_rules.dart';
import 'slot_enumerator.dart';

/// 채움 1회 시도의 결과·계측값 (01-06).
class FillStats {
  final bool success;
  final int backtracks;
  final int queries;
  final Map<int, int> achieved; // tier -> 배치 개수

  const FillStats({
    required this.success,
    required this.backtracks,
    required this.queries,
    required this.achieved,
  });
}

/// 채움 + 백트래킹 (01-06).
///
/// 코어가 놓인 [g]에 `LevelSpec.fillQuotas` 만큼 채움 단어를 넣는다.
/// 막히면 되감고, `LevelSpec.backtrackBudget` 을 다 쓰면 실패를 반환한다.
/// **예외를 던지지 않는다.** 성공·실패 모두 [FillStats] 로 나온다.
///
/// 실패하면 [g] 는 채움 전(코어만 놓인) 상태로 정확히 복원된다.
/// 모든 `place` 는 실패 경로에서 짝이 되는 `unplace` 를 거친다.
///
/// **결정성**: 랜덤은 호출자가 넘긴 [rnd] 하나만 쓴다.
class Filler {
  final MutableGrid g;
  final LevelSpec spec;
  final WordRepository repo;
  final Random rnd;
  final int candidateLimit;

  final Map<String, List<WordEntry>> _cache = {};
  late final Map<int, int> _remaining;
  late final Map<int, int> _achieved;
  late final Map<int, int> _minNeeded;
  int _budget;
  int _backtracks = 0;
  int _queries = 0;

  Filler(this.g, this.spec, this.repo, this.rnd, {this.candidateLimit = 30})
      : _budget = spec.backtrackBudget {
    _remaining = {for (final q in spec.fillQuotas) q.tier: q.max};
    _minNeeded = {for (final q in spec.fillQuotas) q.tier: q.min};
    _achieved = {for (final q in spec.fillQuotas) q.tier: 0};
  }

  Future<FillStats> run() async {
    final ok = await _fill();
    return FillStats(
      success: ok,
      backtracks: _backtracks,
      queries: _queries,
      achieved: Map.of(_achieved),
    );
  }

  /// 모든 티어가 `min` 을 채웠는가. 빈 슬롯이 남아 있어도 여기서 멈춘다
  /// (성긴 퍼즐이라 빈 칸이 남는 게 정상).
  bool get _quotaMet =>
      _minNeeded.entries.every((e) => _achieved[e.key]! >= e.value);

  /// 같은 `(length, tiers, fixed)` 질의를 이 시도 동안 캐시한다 (주의점 3).
  ///
  /// `exclude` 는 질의에 넣지 않는다. 격자가 바뀌어도 질의 결과는 그대로라
  /// 캐시 적중률이 크게 오른다(주의점 4). 이미 놓인 표제어는 호출부의
  /// `GridRules.canPlace`(규칙 6 — 같은 표제어 중복 금지)가 걸러낸다.
  ///
  /// 키는 `fixed` 를 **오름차순 직렬화**한다. `Map.toString()` 은 순서 보장이
  /// 없어 쓰지 않는다.
  Future<List<WordEntry>> _candidates(Slot slot, Set<int> tiers) async {
    final key = '${slot.length}|${tiers.toList()..sort()}|'
        '${(slot.fixed.entries.map((e) => '${e.key}=${e.value}').toList()..sort()).join(',')}';
    final hit = _cache[key];
    if (hit != null) return hit;
    _queries++;
    final r = await repo.findByPattern(
      length: slot.length,
      tiers: tiers,
      fixed: slot.fixed,
      limit: candidateLimit,
    );
    _cache[key] = r;
    return r;
  }

  /// 규칙 5: [spec.allowIsolated]가 꺼져 있으면 연결 요소가 반드시 1개여야
  /// 한다. 켜져 있으면(고립 단어 최대 1개) 연결 요소가 1개이거나, 2개이면서
  /// 한쪽이 단어 1개까지 허용한다.
  ///
  /// `canPlace` 가 검사하지 않는 유일한 격자 규칙이라 여기서 막는다. 실제로
  /// 걸리는 경로는: 코어 단계가 고립 슬롯을 썼을 때(01-04
  /// `CorePlaceResult.isolatedUsed`, `allowIsolated: true`인 레벨에서만
  /// 가능) 그 고립 단어에 채움이 교차해 크기가 2로 자라면 `validate`가
  /// 깨지므로 여기서 막는다. `allowIsolated: false`면 코어 단계에서부터
  /// 연결 요소가 항상 1개로 유지되고, `SlotEnumerator`의 슬롯 조건("구간
  /// 안에 채워진 칸이 1개 이상")이 채움도 늘 기존 요소와 맞닿게 강제해서
  /// 이 메서드의 `!spec.allowIsolated` 분기는 사실 도달하지 않는다 —
  /// `CorePlacer._isolationOk`와 판정식을 맞추고 계약을 명시적으로 드러내기
  /// 위한 이중 방어일 뿐이다.
  bool _isolationOk() {
    final comps = GridRules.components(g.placed);
    if (comps.length <= 1) return true;
    if (!spec.allowIsolated) return false;
    if (comps.length > 2) return false;
    return comps.any((c) => c.length == 1);
  }

  /// 되감기 1회 소비. `backtracks` 는 곧 "쓴 예산"이다.
  void _spendBudget() {
    _budget--;
    _backtracks++;
  }

  /// 01-06 알고리즘. 성공이면 배치를 남기고 true, 실패면 되돌리고 false.
  ///
  /// 매 재귀마다 슬롯을 다시 열거한다. 격자가 바뀌면 슬롯이 통째로 달라져
  /// 캐싱하면 오히려 버그가 난다(주의점 1). `slots.first`(MRV) 하나만 시도한다.
  /// 다른 슬롯으로 도망가면 탐색 공간이 폭발한다(주의점 2).
  Future<bool> _fill() async {
    if (_quotaMet) return true;
    if (_budget <= 0) return false;

    final slots = SlotEnumerator.enumerate(g)
      ..sort(SlotEnumerator.compareByConstraint);
    if (slots.isEmpty) return false;

    final slot = slots.first;
    final tiersWanted = <int>{
      for (final e in _remaining.entries)
        if (e.value > 0) e.key,
    };

    // 캐시된 리스트를 그대로 섞으면 캐시가 오염된다. 사본을 섞는다.
    final cands = List.of(await _candidates(slot, tiersWanted))..shuffle(rnd);

    for (final w in cands) {
      if (!GridRules.canPlace(g, w.headword, slot.row, slot.col, slot.dir)) {
        continue;
      }
      // 할당량 밖 티어(= 애초에 remaining에 없는 티어)도 여기서 걸린다.
      if ((_remaining[w.tier] ?? 0) == 0) continue;

      final p = PlacedWord(
        headword: w.headword,
        row: slot.row,
        col: slot.col,
        dir: slot.dir,
        isCore: false,
        tier: w.tier,
      );
      g.place(p);
      if (!_isolationOk()) {
        g.unplace(p);
        continue;
      }
      _remaining[w.tier] = _remaining[w.tier]! - 1;
      _achieved[w.tier] = _achieved[w.tier]! + 1;

      if (await _fill()) return true;

      g.unplace(p);
      _remaining[w.tier] = _remaining[w.tier]! + 1;
      _achieved[w.tier] = _achieved[w.tier]! - 1;
      _spendBudget();
      if (_budget <= 0) return false;
    }

    // 이 슬롯을 아무 단어로도 못 채웠다.
    _spendBudget();
    return false;
  }
}
