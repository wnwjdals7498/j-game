// 제출 결과를 word_stat에 기록한다 (03-04).
//
// 핵심 제약: **첫 제출만 통계에 반영한다.** 재제출은 결과만 보여주고 통계는
// 바뀌지 않는다 (DESIGN 5절 7번). 판정은 `puzzle_log` 테이블로 한다 —
// schema.sql(03-04)에 03-01 drift 테이블과 함께 추가했다("puzzle_log 테이블
// 방식 결정" 참조).
//
// 단어 UPSERT 여러 개 + puzzle_log INSERT가 한 트랜잭션 안에서 원자적이어야
// 한다. 중간에 앱이 죽어 "통계는 반영됐는데 첫 제출 기록이 없다"가 되면
// 재제출이 이중 반영된다.
import 'package:drift/drift.dart';

import '../domain/model/submit_result.dart';
import 'db/app_database.dart';

class StatRepository {
  final AppDatabase _db;
  const StatRepository(this._db);

  /// 이 퍼즐이 이미 제출된 적 있는가.
  Future<bool> isFirstSubmit(int levelId, int seed) async {
    final r = await _db.customSelect(
      'SELECT 1 FROM puzzle_log WHERE level_id = ? AND seed = ?',
      variables: [Variable.withInt(levelId), Variable.withInt(seed)],
    ).getSingleOrNull();
    return r == null;
  }

  /// 제출 기록. 첫 제출이면 word_stat 반영, 아니면 아무것도 안 한다.
  /// 반환: 실제로 통계에 반영했는지
  Future<bool> recordSubmit({
    required int levelId,
    required int seed,
    required SubmitResult result,
  }) async {
    return _db.transaction(() async {
      if (!await isFirstSubmit(levelId, seed)) return false;

      final now = DateTime.now().millisecondsSinceEpoch;

      for (final r in result.results) {
        final hw = r.word.headword;
        final correct = r.isCorrect ? 1 : 0;
        final wrong = r.isCorrect ? 0 : 1; // blank도 오답 (DESIGN 5절)
        await _db.customStatement(
          'INSERT INTO word_stat (headword, correct, wrong, last_seen) '
          'VALUES (?, ?, ?, ?) '
          'ON CONFLICT(headword) DO UPDATE SET '
          '  correct = correct + excluded.correct, '
          '  wrong = wrong + excluded.wrong, '
          '  last_seen = excluded.last_seen',
          [hw, correct, wrong, now],
        );
      }

      await _db.customStatement(
        'INSERT INTO puzzle_log (level_id, seed, first_score, submitted_at) '
        'VALUES (?, ?, ?, ?)',
        [levelId, seed, result.score, now],
      );
      return true;
    });
  }

  /// 홈 화면 누적 통계 (04-06). `words`는 통계가 있는(=한 번이라도 제출된)
  /// 표제어 수다.
  Future<({int correct, int wrong, int words})> summary() async {
    final r = await _db.customSelect(
      'SELECT COALESCE(SUM(correct), 0) AS correct, '
      '       COALESCE(SUM(wrong), 0) AS wrong, '
      '       COUNT(*) AS words '
      'FROM word_stat',
    ).getSingle();
    return (
      correct: r.read<int>('correct'),
      wrong: r.read<int>('wrong'),
      words: r.read<int>('words'),
    );
  }

  /// 레벨 클리어 여부 (04-06 레벨 해제 규칙). 그 레벨로 첫 제출된 적 없으면
  /// null. 여러 seed로 재도전했을 수 있으므로 그중 최고 점수를 돌려준다.
  Future<int?> bestScore(int levelId) async {
    final r = await _db.customSelect(
      'SELECT MAX(first_score) AS best FROM puzzle_log WHERE level_id = ?',
      variables: [Variable.withInt(levelId)],
    ).getSingle();
    return r.read<int?>('best');
  }

  /// 전체 레벨의 최고 점수를 **한 번의 쿼리**로 조회한다 (04-06 "레벨마다 DB
  /// 조회 1회 → 12회. 홈 진입마다 도는 건 낭비다"). `bestScore`를 레벨 수만큼
  /// 반복 호출하는 N+1을 피하려고 `HomeModel.load`가 이걸 쓴다. 제출 기록이
  /// 없는 레벨은 이 맵에 아예 키가 없다(=null과 동치).
  Future<Map<int, int>> bestScores() async {
    final rows = await _db.customSelect(
      'SELECT level_id, MAX(first_score) AS best FROM puzzle_log GROUP BY level_id',
    ).get();
    return {
      for (final r in rows) r.read<int>('level_id'): r.read<int>('best'),
    };
  }

  /// 디버그·테스트용.
  Future<void> resetAll() async {
    await _db.transaction(() async {
      await _db.customStatement('DELETE FROM word_stat');
      await _db.customStatement('DELETE FROM puzzle_log');
    });
  }
}
