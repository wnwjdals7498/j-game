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

  /// `coreCandidates`의 SQL 단계 후보 창 크기. `tool/tune_core.dart`로 실 DB
  /// 스윕한 값 — 원래(`count*12`≈36)보다 넓히되 티어 전체(수천 행)까지는
  /// 안 간다. 자세한 이유는 `coreCandidates` 본문 주석.
  static const _coreCandidatePoolSize = 200;

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
    // 예전엔 `LIMIT count*12`(count=3이면 36)를 걸었는데, 점수가 대부분
    // 0으로 묶여 있으면(막 시작한 기기, 또는 word_stat이 몇 단어만 건드린
    // 상태) `ORDER BY score ASC, headword ASC`의 동점 tie-break가 결국
    // "표제어 알파벳순 앞쪽"으로 고정돼 버린다. 한글은 초성 '가'가 가장
    // 앞이라 이 앞쪽 구간이 '가OO'류 단어로 심하게 쏠려(06단계 실기기 확인
    // 중 재현 — tier 3 알파벳 앞쪽 40개 중 39개가 '가'로 시작) word_stat이
    // 하필 그 쏠린 구간의 두 단어를 낮은 점수로 고정하면, 그 둘과 서로
    // 음절이 겹치는 세 번째 후보가 이 좁은 창 안에 없어 core placement가
    // 매 시도(seed)마다 결정적으로 실패했다(고립 단어 금지 이후, 01-03
    // 규칙 5). **LIMIT을 아예 없애 티어 전체를 가져오면 반대로 악화된다**
    // — '가'로 시작하는 무리가 서로 첫 음절을 공유해 오히려 교차가 쉬웠던
    // 것이라, 진짜 무작위 표본은 서로 겹치는 음절을 찾을 확률이 더 낮다.
    // `tool/tune_core.dart`(실 DB 스윕, `docs/reports/03-real-failure.md`
    // "2026-09-18" 절)로 (SQL LIMIT, 최종 개수 배수) 여러 조합을 실측한
    // 결과 (200, count*20)만 레벨 6·7(t5×3, 가장 빡빡한 조합)까지
    // 1000/1000 통과했다 — limit 없음은 6·7에서 20% 실패, (200, count*10)도
    // 1000회 기준 2% 실패로 DoD(1%)를 못 넘었다.
    const sql = '''
      SELECT w.headword, w.tier, w.pos,
             COALESCE(s.correct, 0) - COALESCE(s.wrong, 0) * 2 AS score
      FROM word w
      LEFT JOIN word_stat s ON s.headword = w.headword
      WHERE w.tier = ?
      ORDER BY score ASC, w.headword ASC
      LIMIT ?
    ''';

    final rows = await _db.customSelect(sql, variables: [
      Variable.withInt(tier),
      Variable.withInt(_coreCandidatePoolSize),
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
    // count*4 → count*20: CorePlacer가 훑을 후보 폭도 같이 넓혀야
    // 위 셔플 확장이 실제로 연결 가능한 조합을 찾을 기회로 이어진다.
    return out.take(count * 20).toList();
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
