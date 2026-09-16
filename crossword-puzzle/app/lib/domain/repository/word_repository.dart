import '../model/word_entry.dart';

abstract class WordRepository {
  /// 패턴 질의.
  ///
  /// [length]  단어 음절 수 (2..5)
  /// [tiers]   허용 티어 집합. 비면 전체 티어
  /// [fixed]   고정된 자리. key=0-based 음절 index, value=음절.
  ///           예) length 3, fixed {1: '가'} → `?가?`
  /// [exclude] 제외할 표제어 (이미 격자에 놓인 단어들)
  /// [limit]   최대 반환 개수
  ///
  /// 반환 순서는 **정해지지 않는다.** 호출자가 Random(seed)로 섞어 쓴다.
  /// 구현은 결정적이어야 한다: 같은 인자 → 같은 리스트(같은 순서).
  /// (3단계 주의: SQL `ORDER BY RANDOM()` 금지. 03-03 참조)
  Future<List<WordEntry>> findByPattern({
    required int length,
    Set<int> tiers = const {},
    Map<int, String> fixed = const {},
    Set<String> exclude = const {},
    int limit = 50,
  });

  /// 코어 후보.
  ///
  /// 통계 점수(`correct - wrong * 2`) **낮은 순**, 동점은 [seed] 기반 랜덤.
  /// [count]보다 넉넉히 돌려준다(권장 count * 4). 생성기가 그중에서 고르고
  /// 실패 시 다른 후보로 교체하기 때문이다.
  Future<List<WordEntry>> coreCandidates({
    required int tier,
    required int count,
    required int seed,
  });
}
