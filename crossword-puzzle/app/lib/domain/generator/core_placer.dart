import 'dart:math';

import '../model/level_spec.dart';
import '../model/puzzle.dart';
import '../model/word_entry.dart';
import 'grid.dart';
import 'grid_rules.dart';

/// 코어 배치 결과.
class CorePlaceResult {
  /// 고립 슬롯(교차 없이 놓은 단어 1개)을 썼는지. 채움 단계(01-06)가 이어받는다.
  final bool isolatedUsed;

  const CorePlaceResult({required this.isolatedUsed});
}

/// 코어 단어 교차 배치 (01-04).
///
/// 코어는 "유저가 약한 단어"라 [LevelSpec.coreCount] 개가 반드시 다 들어가야 한다.
/// 채움과 달리 타협 없음 — 못 채우면 실패다.
///
/// **결정성**: 모든 셔플은 호출자가 넘긴 [Random] 인스턴스 하나만 쓴다.
/// 새 `Random()` 을 만들지 않는다.
class CorePlacer {
  /// [g]에 코어 [LevelSpec.coreCount]개를 배치한다.
  ///
  /// [candidates] 는 `WordRepository.coreCandidates` 결과(이미 통계순)를 그대로
  /// 받는다. 셔플하지 않고 앞에서부터 쓴다.
  ///
  /// 성공하면 [CorePlaceResult], 실패하면 null. 실패 시 [g]는 오염돼 있을 수
  /// 있으므로 호출자(01-07)가 새 [MutableGrid]로 재시작한다.
  static CorePlaceResult? place(
    MutableGrid g,
    LevelSpec spec,
    List<WordEntry> candidates,
    Random rnd,
  ) {
    var isolatedUsed = false;
    var placedCount = 0;

    for (final w in candidates) {
      if (placedCount >= spec.coreCount) break;

      // 1. 첫 코어: 중앙에서 맨해튼 거리가 가까운 순으로 시도.
      if (placedCount == 0) {
        if (_placeFirstUsable(g, _centerFirstPlacements(g, w))) placedCount++;
        continue;
      }

      // 2. 2번째 이후 코어: 공유 음절 교차 위치를 우선.
      final crossing = crossingPlacements(g, w)..shuffle(rnd);
      if (_placeFirstUsable(g, crossing)) {
        placedCount++;
        continue;
      }

      // 3. 교차 위치가 없는 코어: 고립 슬롯을 한 번만 쓴다.
      if (!spec.allowIsolated || isolatedUsed) continue;
      final free = freePlacements(g, w)..shuffle(rnd);
      if (_placeFirstUsable(g, free)) {
        placedCount++;
        isolatedUsed = true;
      }
    }

    // 4. 후보를 다 써도 coreCount를 못 채우면 실패.
    if (placedCount < spec.coreCount) return null;
    return CorePlaceResult(isolatedUsed: isolatedUsed);
  }

  /// [w]를 [g]의 기존 단어와 교차시킬 수 있는 모든 배치 후보.
  ///
  /// 기존 단어 [p]의 각 셀에 [w]의 같은 음절을 올리고, [p]와 수직인 방향으로
  /// 시작점을 역산한다. `canPlace` 를 통과한 것만 낸다.
  static List<PlacedWord> crossingPlacements(
    MutableGrid g,
    WordEntry w,
  ) {
    final out = <PlacedWord>[];
    // 같은 (row, col, dir) 이 여러 경로로 나올 수 있다. 셔플 결정성을 위해
    // 첫 등장 순서를 유지하며 중복만 걸러낸다.
    final seen = <String>{};
    for (final p in g.placed) {
      final newDir =
          p.dir == Direction.across ? Direction.down : Direction.across;
      var idx = 0;
      for (final (r, c) in p.cells) {
        final s = p.syllableAt(idx++);
        for (var i = 0; i < w.length; i++) {
          if (w.syllableAt(i) != s) continue;
          // w의 i번째가 (r,c)에 오도록 시작점 역산
          final r0 = newDir == Direction.down ? r - i : r;
          final c0 = newDir == Direction.across ? c - i : c;
          if (!g.inBounds(r0, c0)) continue;
          if (!GridRules.canPlace(g, w.headword, r0, c0, newDir)) continue;
          if (!seen.add('${w.headword}:$r0:$c0:${newDir.name}')) continue;
          out.add(PlacedWord(
            headword: w.headword,
            row: r0,
            col: c0,
            dir: newDir,
            isCore: true,
            tier: w.tier,
          ));
        }
      }
    }
    return out;
  }

  /// 교차 없이 놓을 수 있는 모든 배치 후보 (고립 슬롯용).
  ///
  /// 모든 `(r, c, dir)` 을 훑어 `canPlace` 가 참인 것 전부. 교차 후보가 하나도
  /// 없는 [w]에 대해서만 쓰이므로(또는 빈 격자의 첫 코어), 결과는 실제로
  /// 기존 단어와 셀을 공유하지 않는다.
  static List<PlacedWord> freePlacements(MutableGrid g, WordEntry w) {
    final out = <PlacedWord>[];
    for (var r = 0; r < g.height; r++) {
      for (var c = 0; c < g.width; c++) {
        for (final dir in Direction.values) {
          if (!GridRules.canPlace(g, w.headword, r, c, dir)) continue;
          out.add(PlacedWord(
            headword: w.headword,
            row: r,
            col: c,
            dir: dir,
            isCore: true,
            tier: w.tier,
          ));
        }
      }
    }
    return out;
  }

  /// 첫 코어용. 중앙에서 맨해튼 거리가 가까운 순, 동점은 안정적 순서로.
  /// `across` 가 `down` 보다 사전순으로 앞이라 격자 모양이 예측 가능해진다.
  static List<PlacedWord> _centerFirstPlacements(MutableGrid g, WordEntry w) {
    final cr = g.height ~/ 2, cc = g.width ~/ 2;
    return freePlacements(g, w)
      ..sort((a, b) {
        final da = (a.row - cr).abs() + (a.col - cc).abs();
        final db = (b.row - cr).abs() + (b.col - cc).abs();
        if (da != db) return da.compareTo(db);
        return '${a.row}:${a.col}:${a.dir.name}'
            .compareTo('${b.row}:${b.col}:${b.dir.name}');
      });
  }

  /// [options] 를 순서대로 놓아 보고 규칙 5를 유지하는 첫 배치를 확정한다.
  ///
  /// 고립 슬롯은 한 번만 쓰므로 연결 요소는 항상 2개 이하다. 다만 고립 단어에
  /// 뒤 코어가 교차하면 "작은 쪽 크기 1" 이 깨진다(요소 2개 × 크기 2). 그 배치는
  /// `validate` 가 잡는 규칙 5 위반이므로 되돌리고 다음 후보로 넘어간다.
  static bool _placeFirstUsable(MutableGrid g, List<PlacedWord> options) {
    for (final p in options) {
      g.place(p);
      if (_isolationOk(g)) return true;
      g.unplace(p);
    }
    return false;
  }

  /// 규칙 5: 연결 요소가 1개이거나, 2개이면서 둘 중 하나가 단어 1개짜리.
  static bool _isolationOk(MutableGrid g) {
    final comps = GridRules.components(g.placed);
    if (comps.length <= 1) return true;
    if (comps.length > 2) return false;
    return comps.any((c) => c.length == 1);
  }
}
