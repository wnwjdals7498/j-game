// WordRepository(01-02)의 drift 구현 (03-03).
//
// **결정성이 가장 중요한 제약이다.** 01-07 GridGenerator의 DoD가
// "같은 (spec, repository 내용, seed) → 같은 Puzzle" 이므로, findByPattern은
// SQL `ORDER BY RANDOM()` 을 쓰지 않는다. 대신 `headword` 로 안정 정렬해
// 반환하고, 섞는 것은 호출자(01-06 Filler)가 Random(seed)로 한다.
import 'dart:math';

import 'package:drift/drift.dart';

import '../domain/model/word_entry.dart';
import '../domain/repository/word_repository.dart';
import 'db/app_database.dart';

/// `WordRepository` 를 실 SQLite(drift)로 구현한다.
///
/// `word` 테이블은 음절을 `c1..c5` 컬럼으로 펼쳐 두었고(02-09), `(len, tier, cN)`
/// 복합 인덱스가 자리별로 하나씩 있다(DESIGN 4절). `fixed` 의 0-based 음절
/// index를 1-based `cN` 컬럼으로 변환하는 지점이 이 클래스의 유일한 함정이다.
class DriftWordRepository implements WordRepository {
  final AppDatabase _db;

  const DriftWordRepository(this._db);

  @override
  Future<List<WordEntry>> findByPattern({
    required int length,
    Set<int> tiers = const {},
    Map<int, String> fixed = const {},
    Set<String> exclude = const {},
    int limit = 50,
  }) async {
    final where = <String>['len = ?'];
    final args = <Variable>[Variable.withInt(length)];

    if (tiers.isNotEmpty) {
      final sorted = tiers.toList()..sort(); // 결정성: 키 순서 고정
      where.add('tier IN (${List.filled(sorted.length, '?').join(',')})');
      args.addAll(sorted.map(Variable.withInt));
    }

    // fixed는 key 오름차순으로 적용 (SQL 텍스트를 안정화 → 준비된 문 캐시 적중)
    final keys = fixed.keys.toList()..sort();
    for (final i in keys) {
      where.add('c${i + 1} = ?'); // 0-based index → c1..c5
      args.add(Variable.withString(fixed[i]!));
    }

    // exclude는 SQL에 넣지 않는다. 아래 클래스 문서 "exclude 처리" 참고
    where.add('headword IS NOT NULL');

    final sql = 'SELECT headword, len, tier, pos FROM word '
        'WHERE ${where.join(' AND ')} '
        'ORDER BY headword '
        'LIMIT ?';
    args.add(Variable.withInt(limit + exclude.length));

    final rows = await _db.customSelect(sql, variables: args).get();

    final out = <WordEntry>[];
    for (final r in rows) {
      final hw = r.read<String>('headword');
      if (exclude.contains(hw)) continue;
      out.add(WordEntry(
        headword: hw,
        tier: r.read<int>('tier'),
        pos: r.read<String>('pos'),
      ));
      if (out.length >= limit) break;
    }
    return out;
  }

  @override
  Future<List<WordEntry>> coreCandidates({
    required int tier,
    required int count,
    required int seed,
  }) async {
    const sql = '''
      SELECT w.headword, w.tier, w.pos,
             COALESCE(s.correct, 0) - COALESCE(s.wrong, 0) * 2 AS score
      FROM word w
      LEFT JOIN word_stat s ON s.headword = w.headword
      WHERE w.tier = ?
      ORDER BY score ASC, w.headword ASC
      LIMIT ?
    ''';

    // 동점 랜덤을 위해 넉넉히 가져온다
    final take = count * 12;
    final rows = await _db.customSelect(sql, variables: [
      Variable.withInt(tier),
      Variable.withInt(take),
    ]).get();

    // 점수별로 묶어 그룹 안에서만 셔플 → 점수 순서는 유지, 동점만 랜덤
    final byScore = <int, List<WordEntry>>{};
    for (final r in rows) {
      byScore.putIfAbsent(r.read<int>('score'), () => []).add(WordEntry(
            headword: r.read<String>('headword'),
            tier: r.read<int>('tier'),
            pos: r.read<String>('pos'),
          ));
    }
    final rnd = Random(seed);
    final out = <WordEntry>[];
    for (final score in byScore.keys.toList()..sort()) {
      final g = byScore[score]!..shuffle(rnd);
      out.addAll(g);
    }
    return out.take(count * 4).toList();
  }

  /// `(len, tier, cN)` 인덱스가 실제로 잡히는지 확인하는 진단용 헬퍼 (03-03).
  /// 게임 로직은 쓰지 않는다 — 테스트·실기기 확인 전용.
  Future<List<String>> explainPattern() async {
    final rows = await _db.customSelect(
      'EXPLAIN QUERY PLAN SELECT headword FROM word '
      'WHERE len = ? AND tier IN (1,2) AND c2 = ?',
      variables: [Variable.withInt(3), Variable.withString('가')],
    ).get();
    return rows.map((r) => r.data.values.join(' ')).toList();
  }
}
