import 'model/level_spec.dart';

/// 레벨 테이블 v1 (데스크톱 기준, 2026-09-17).
///
/// **데스크톱 기준 잠정 확정, 실기기 확인 대기(HUMAN).** 03-05/03-06 DoD는 실기기
/// 100회 측정이 최종 판정이지만, 이 세션에는 Android 실기기가 없어 돌릴 수 없었다.
/// 아래 값은 `dart run tool/measure_real.dart --runs 1000`(데스크톱, 실 DB) 결과만
/// 반영한 것이고, 실기기 측정·`EXPLAIN QUERY PLAN` 실기기 확인은 사람이 앱 안
/// "벤치마크" 화면으로 마저 해야 한다. 값을 고치면 `dart run tool/measure_real.dart`
/// 를 다시 돌려 `docs/reports/03-real-failure.md` 를 갱신한다.
///
/// ## 이전 단계와의 관계
///
/// 01-09/01-10은 더미 사전(음절 풀 40개) 기준 초안이었다. 00-01 승인 후 실데이터
/// (26,000단어)로 `words.sqlite`가 재빌드되면서 03-05가 처음으로 진짜 측정을 했고,
/// 이 파일은 그 결과로 03-06이 확정한 v1이다. 아래 `완화(실데이터):` 주석이 붙은
/// 레벨은 03-06에서 조정한 것이고, 주석이 없는 레벨(1, 3, 4, 9)은 01-09/01-10
/// 더미 기준 값 그대로 실데이터에서도 통과했다.
///
/// 더미 기준 값의 유도 과정(01-09 "막히면" 절, 01-10 하네스 완화)은
/// `docs/plan/01-09.levels-table.md` "실제 적용값" 절과 `docs/reports/01-dummy-failure.md`
/// 에 있다. 실데이터 조정 근거·측정치는 `docs/reports/03-real-failure.md` "조치" 절.
///
/// 초안 12레벨 중 2개(구 2 둘레길 5×5·코어 3, 구 8 돌아섬 7×7·코어 4)는 이미 01-09
/// 단계에서 빠졌다(더미 기준으로도 1%를 못 넘김). 실데이터 재측정에서는 남은 10개
/// 전부 손잡이 조정만으로 1% 미만을 달성해 추가로 뺀 레벨은 없다.
const List<LevelSpec> levels = [
  LevelSpec(
    id: 1, name: '첫걸음',
    width: 5, height: 5,
    coreTier: 2, coreCount: 2,
    fillQuotas: [TierQuota(1, 2, 4)],
    backtrackBudget: 150,
  ),
  // 완화(실데이터): 더미 기준 [(1,2,3),(2,1,3)] backtrackBudget 200 → 실측 25.00%
  // (200 seed). 1번(budget→500)은 무변화(25.00%), 2번(min-1,max+1)으로 0.00%.
  LevelSpec(
    id: 2, name: '갈림길', // 구 3
    width: 6, height: 6,
    coreTier: 3, coreCount: 3,
    fillQuotas: [TierQuota(1, 1, 4), TierQuota(2, 0, 4)],
    backtrackBudget: 500,
  ),
  // 완화: fillQuotas min -1 (초안 [(1,2,4), (2,2,4)]). 초안 1.00% → 0.20%.
  LevelSpec(
    id: 3, name: '어스름', // 구 4
    width: 6, height: 6,
    coreTier: 3, coreCount: 3,
    fillQuotas: [TierQuota(1, 1, 4), TierQuota(2, 1, 4)],
    backtrackBudget: 200,
  ),
  // 완화: fillQuotas min -1 (초안 [(1,2,4), (2,2,4)]). 초안 1.10% → 0.10%.
  LevelSpec(
    id: 4, name: '들머리', // 구 5
    width: 6, height: 6,
    coreTier: 4, coreCount: 3,
    fillQuotas: [TierQuota(1, 1, 4), TierQuota(2, 1, 4)],
    backtrackBudget: 200,
  ),
  // 완화(실데이터): 더미 기준 [(1,2,5),(2,1,4),(3,0,3)] budget 300 → 실측 14.00%
  // (200 seed). 1번(budget→700)은 무변화, 2번(min-1,max+1)으로 0.00%.
  LevelSpec(
    id: 5, name: '엇갈림', // 구 6
    width: 7, height: 7,
    coreTier: 4, coreCount: 3,
    fillQuotas: [TierQuota(1, 1, 6), TierQuota(2, 0, 5), TierQuota(3, 0, 4)],
    backtrackBudget: 700,
  ),
  // 완화(실데이터): 더미 기준 [(1,3,5),(2,2,4),(3,1,3)] budget 300 → 실측 19.00%
  // (200 seed). 1번(budget→700) 19.00%→17.00%, 2번(min-1,max+1) 17.00%→2.00%,
  // 2번을 한 단계 더(min-1,max+1 재적용) 0.00%.
  LevelSpec(
    id: 6, name: '깊은숲', // 구 7
    width: 7, height: 7,
    coreTier: 5, coreCount: 3,
    fillQuotas: [TierQuota(1, 1, 7), TierQuota(2, 0, 6), TierQuota(3, 0, 5)],
    backtrackBudget: 700,
  ),
  // 완화(01-09, 더미 기준): fillQuotas min -1 + 코어 4→3.
  // 완화(실데이터): budget 400 → 실측 6.00% (200 seed). 1번(budget→800) 무변화,
  // 2번(min-1,max+1) 0.50%, 2번을 한 단계 더 0.00%.
  LevelSpec(
    id: 7, name: '벼랑끝', // 구 9
    width: 8, height: 8,
    coreTier: 5, coreCount: 3,
    fillQuotas: [TierQuota(1, 1, 8), TierQuota(2, 0, 7), TierQuota(3, 0, 6)],
    backtrackBudget: 800,
  ),
  // 완화(01-09/01-10, 더미 기준): fillQuotas min -2 누적.
  // 완화(실데이터): 더미 기준 coreCount 4, budget 400 → 실측 34.50% (200 seed).
  // 1번(budget→900) 무변화, 2번(min-1,max+1) 15.50% — 평균 되감기(3.4)·평균 질의
  // (4.5)가 낮은데 실패율만 높아 병목이 채움이 아니라 코어 배치(coreCandidates
  // 티어6이 coreCount 4개를 서로 교차 가능하게 놓을 조합이 부족)로 판정, 3·4번
  // (채움 티어)은 건너뛰고 5번(coreCount 4→3)을 적용해 0.00%.
  LevelSpec(
    id: 8, name: '먼길', // 구 10
    width: 8, height: 8,
    coreTier: 6, coreCount: 3,
    fillQuotas: [TierQuota(1, 1, 7), TierQuota(2, 0, 6), TierQuota(3, 0, 5)],
    backtrackBudget: 900,
  ),
  // 완화(01-09/01-10, 더미 기준): fillQuotas min -2 누적 + 코어 4→3.
  // 실데이터 재측정(1000 seed): 0.40% — 그대로 통과해 추가 조정 없음. 평균
  // 되감기(48.2)가 8/10(3.3~3.4)보다 훨씬 높다 — 채움 티어에 4를 쓰는데
  // (02-db-report) 티어4는 3음절이 3,571/3,640개로 편중돼 다른 길이 슬롯에서
  // 후보가 얇다. 1% 밑이라 이번엔 손대지 않지만 04단계에서 체감이 나쁘면
  // 이 코멘트를 참고해 채움 티어를 3으로 바꿔본다.
  LevelSpec(
    id: 9, name: '외딴곳', // 구 11
    width: 8, height: 8,
    coreTier: 6, coreCount: 3,
    fillQuotas: [TierQuota(1, 2, 6), TierQuota(2, 1, 5), TierQuota(4, 0, 3)],
    backtrackBudget: 400,
  ),
  // 완화(01-09/01-10, 더미 기준): fillQuotas min -2 누적 + 코어 4→3.
  // 완화(실데이터): budget 400 → 실측 51.50% (200 seed). 1번(budget→900)
  // 51.50%→47.00%(약함), 2번(min-1,max+1) 0.00%.
  LevelSpec(
    id: 10, name: '마루', // 구 12
    width: 8, height: 8,
    coreTier: 6, coreCount: 3,
    fillQuotas: [TierQuota(1, 1, 7), TierQuota(2, 0, 6), TierQuota(4, 0, 5)],
    backtrackBudget: 900,
  ),
];

/// id로 조회. UI(04-06)가 쓴다.
LevelSpec levelById(int id) => levels.firstWhere((l) => l.id == id);

/// [current]의 다음 레벨. 마지막 레벨이면 null (04-05 "버튼 동작":
/// "다음 레벨을 새 seed로 생성. 마지막 레벨이면 홈으로").
LevelSpec? nextLevelOf(LevelSpec current) {
  final i = levels.indexWhere((l) => l.id == current.id);
  if (i < 0 || i + 1 >= levels.length) return null;
  return levels[i + 1];
}
