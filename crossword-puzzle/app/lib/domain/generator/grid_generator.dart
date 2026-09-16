import 'dart:math';

import '../model/level_spec.dart';
import '../model/puzzle.dart';
import '../repository/word_repository.dart';
import 'core_placer.dart';
import 'filler.dart';
import 'grid.dart';
import 'grid_rules.dart';

/// 생성 1회의 계측치. 01-10 하네스와 03-05가 쓴다.
class GenerationStats {
  final int attempts;
  final int totalBacktracks;
  final int totalQueries;
  final Duration elapsed;
  final bool success;
  final String? failReason;

  const GenerationStats({
    required this.attempts,
    required this.totalBacktracks,
    required this.totalQueries,
    required this.elapsed,
    required this.success,
    this.failReason,
  });
}

class GenerationOutcome {
  final Puzzle? puzzle;
  final GenerationStats stats;
  const GenerationOutcome(this.puzzle, this.stats);
}

/// 코어 배치(01-04) + 채움(01-06)을 묶어 [Puzzle] 하나를 만든다 (01-07).
///
/// 실패하면 seed를 바꿔 재시도하고, [LevelSpec.maxAttempts] 를 넘으면 실패다.
/// **결정성은 이 클래스가 최종 보증한다**: 랜덤은 `Random(attemptSeed)` 하나뿐이고
/// 코어·채움이 그것을 공유한다.
class GridGenerator {
  final WordRepository repo;
  const GridGenerator(this.repo);

  /// 실패 시 [GenerationFailed] 를 던진다. 게임 코드가 쓰는 API.
  Future<Puzzle> generate(LevelSpec spec, int seed) async {
    final o = await tryGenerate(spec, seed);
    final p = o.puzzle;
    if (p == null) {
      throw GenerationFailed(
          spec.id, o.stats.attempts, o.stats.failReason ?? 'unknown');
    }
    return p;
  }

  /// 예외 없이 결과+계측을 돌려준다. 하네스(01-10, 03-05)가 쓰는 API.
  ///
  /// 매 시도마다 새 [MutableGrid] 를 만든다. 01-06의 복원이 완벽해도 새로 만드는
  /// 쪽이 재시도 간 오염 가능성이 0이고, 비용은 작다.
  Future<GenerationOutcome> tryGenerate(LevelSpec spec, int seed) async {
    final sw = Stopwatch()..start();
    var backtracks = 0;
    var queries = 0;
    String? lastFail;

    for (var attempt = 1; attempt <= spec.maxAttempts; attempt++) {
      // 첫 시도 seed가 입력 seed와 같아야 generate(spec, 7)이 예측 가능하다.
      final attemptSeed = seed + attempt - 1;
      final rnd = Random(attemptSeed);

      final g = MutableGrid(spec.width, spec.height);

      final cands = await repo.coreCandidates(
        tier: spec.coreTier,
        count: spec.coreCount,
        seed: attemptSeed,
      );

      final core = CorePlacer.place(g, spec, cands, rnd);
      if (core == null) {
        lastFail = 'core placement failed';
        continue;
      }

      final filler = Filler(g, spec, repo, rnd);
      final fs = await filler.run();
      backtracks += fs.backtracks;
      queries += fs.queries;
      if (!fs.success) {
        lastFail = 'fill failed (quota unmet)';
        continue;
      }

      final errors = GridRules.validate(g, allowIsolated: spec.allowIsolated);
      if (errors.isNotEmpty) {
        // 여기 걸리면 생성기 버그다. 조용히 재시도하지 말고 남긴다.
        assert(false, 'validate failed: ${errors.join("; ")}');
        lastFail = 'validate: ${errors.first}';
        continue;
      }

      sw.stop();
      return GenerationOutcome(
        // Puzzle.seed 는 attemptSeed. 이 값으로 재생성하면 1회 시도에 같은 퍼즐.
        g.toPuzzle(levelId: spec.id, seed: attemptSeed, attempts: attempt),
        GenerationStats(
          attempts: attempt,
          totalBacktracks: backtracks,
          totalQueries: queries,
          elapsed: sw.elapsed,
          success: true,
        ),
      );
    }

    sw.stop();
    return GenerationOutcome(
      null,
      GenerationStats(
        attempts: spec.maxAttempts,
        totalBacktracks: backtracks,
        totalQueries: queries,
        elapsed: sw.elapsed,
        success: false,
        failReason: lastFail,
      ),
    );
  }
}
