/// 채움 단어의 티어별 할당량.
/// min == max 면 "정확히 N개", min < max 면 범위.
/// 범위 허용은 백트래킹 폭발 완화책(01-domain-map-generator.md 리스크 절).
class TierQuota {
  final int tier;
  final int min;
  final int max;

  const TierQuota(this.tier, this.min, this.max);
  const TierQuota.exact(this.tier, int count)
      : min = count,
        max = count;
}

/// 레벨 1개의 생성 파라미터. levels.dart의 const 테이블에 들어간다.
class LevelSpec {
  final int id; // 1부터. 레벨 번호이자 정렬 키
  final String name; // 홈 화면 표시용
  final int width; // 격자 가로 칸 수
  final int height; // 격자 세로 칸 수

  final int coreTier; // 코어 단어 티어
  final int coreCount; // 코어 단어 개수
  final List<TierQuota> fillQuotas; // 채움 단어 티어별 할당량

  final int maxAttempts; // seed를 바꿔 전체 재시작하는 최대 횟수
  final int backtrackBudget; // 한 시도 안에서 허용하는 되감기 총 횟수
  final bool allowIsolated; // 고립 단어 1개 허용 여부 (규칙상 최대 1개)

  const LevelSpec({
    required this.id,
    required this.name,
    required this.width,
    required this.height,
    required this.coreTier,
    required this.coreCount,
    required this.fillQuotas,
    this.maxAttempts = 20,
    this.backtrackBudget = 200,
    this.allowIsolated = true,
  });

  int get minFillCount => fillQuotas.fold(0, (a, q) => a + q.min);
  int get maxFillCount => fillQuotas.fold(0, (a, q) => a + q.max);
  int get minWordCount => coreCount + minFillCount;
}
