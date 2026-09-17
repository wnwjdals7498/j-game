// 힌트(뜻풀이·유의어) 조회 (04-03.selection-and-hint.md "힌트 데이터 조회").
//
// `sense` 테이블에서 읽는다. **퍼즐 생성 직후 한 번에 다 읽어 캐시한다** —
// 탭할 때마다 DB를 치면 느리다. 단어가 20~30개라 `IN (...)` 목록이 짧아
// 문제없다.
//
// 표제어 마스킹은 여기서 하지 않는다. DB는 원본을 보존하고, 표시할 때
// (`PuzzleModel.hintTextFor`)가 가린다 — 나중에 마스킹 규칙이 바뀌어도 DB
// 재빌드가 필요 없다.
import 'package:drift/drift.dart';

import 'db/app_database.dart';

class HintRepository {
  final AppDatabase _db;

  const HintRepository(this._db);

  /// 퍼즐의 모든 단어 힌트를 한 번에 조회한다. DB 호출은 [headwords] 개수와
  /// 무관하게 항상 1회다(IN 절 하나짜리 쿼리).
  Future<Map<String, Hint>> forWords(List<String> headwords) async {
    if (headwords.isEmpty) return {};
    final placeholders = List.filled(headwords.length, '?').join(',');
    final rows = await _db.customSelect(
      'SELECT headword, definition, synonyms FROM sense '
      'WHERE headword IN ($placeholders)',
      variables: headwords.map(Variable.withString).toList(),
    ).get();
    return {
      for (final r in rows)
        r.read<String>('headword'): Hint(
          r.read<String>('definition'),
          _parseSynonyms(r.read<String?>('synonyms')),
        ),
    };
  }

  /// `sense.synonyms`는 쉼표 구분 텍스트, 없으면 NULL (tools/schema.sql).
  static List<String> _parseSynonyms(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    return raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }
}

class Hint {
  final String definition;
  final List<String> synonyms;

  const Hint(this.definition, this.synonyms);

  bool get hasSynonyms => synonyms.isNotEmpty;
}
