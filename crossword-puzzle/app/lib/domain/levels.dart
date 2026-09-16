import 'model/level_spec.dart';

/// 레벨 테이블 초안. 실데이터 측정 후 03-06에서 v1 확정.
/// 값을 고치면 01-10 / 03-05 하네스를 다시 돌려 리포트를 갱신한다.
///
/// 아래 `완화:` 주석이 붙은 레벨은 01-09 "막히면" 절에 따라 초안 값을 완화한 것이다.
/// 01-09에서는 seed 1000..20000(20개)만 보고 맞췄지만, 01-10 하네스로 레벨당
/// 1000 seed를 돌리자 7개 레벨이 실패율 1%를 넘어 한 번 더 완화했다.
/// 근거·측정치는 `docs/plan/01-09.levels-table.md` "실제 적용값" 절과
/// `docs/reports/01-dummy-failure.md` 에 있다. 실데이터 기준은 03-06에서 다시 잡는다.
///
/// 초안 12레벨 중 2개(구 2 둘레길 5×5·코어 3, 구 8 돌아섬 7×7·코어 4)는 01-09
/// 완화 사다리를 끝까지 적용해도 1%를 못 넘겨 뺐다. 01-10 "막히면" 절이 허용하는
/// "레벨을 빼도 된다(12→10개)" 다. 아래 id는 1..10으로 다시 매겼다.
const List<LevelSpec> levels = [
  LevelSpec(
    id: 1, name: '첫걸음',
    width: 5, height: 5,
    coreTier: 2, coreCount: 2,
    fillQuotas: [TierQuota(1, 2, 4)],
    backtrackBudget: 150,
  ),
  LevelSpec(
    id: 2, name: '갈림길', // 구 3
    width: 6, height: 6,
    coreTier: 3, coreCount: 3,
    fillQuotas: [TierQuota(1, 2, 3), TierQuota(2, 1, 3)],
    backtrackBudget: 200,
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
  // 완화: fillQuotas min -1 (초안 [(1,3,5), (2,2,4), (3,1,3)]). 초안 1.00% → 0.00%.
  LevelSpec(
    id: 5, name: '엇갈림', // 구 6
    width: 7, height: 7,
    coreTier: 4, coreCount: 3,
    fillQuotas: [TierQuota(1, 2, 5), TierQuota(2, 1, 4), TierQuota(3, 0, 3)],
    backtrackBudget: 300,
  ),
  LevelSpec(
    id: 6, name: '깊은숲', // 구 7
    width: 7, height: 7,
    coreTier: 5, coreCount: 3,
    fillQuotas: [TierQuota(1, 3, 5), TierQuota(2, 2, 4), TierQuota(3, 1, 3)],
    backtrackBudget: 300,
  ),
  // 완화(01-09): fillQuotas min -1 + 코어 4→3 (초안 coreCount 4,
  // fillQuotas [(1,4,6), (2,3,5), (3,2,4)]). 1000 seed에서도 0.00%라 추가 완화 없음.
  LevelSpec(
    id: 7, name: '벼랑끝', // 구 9
    width: 8, height: 8,
    coreTier: 5, coreCount: 3,
    fillQuotas: [TierQuota(1, 3, 6), TierQuota(2, 2, 5), TierQuota(3, 1, 4)],
    backtrackBudget: 400,
  ),
  // 완화: fillQuotas min -2 누적 (초안 [(1,4,6), (2,3,5), (3,2,4)]).
  // 01-09에서 -1, 01-10에서 -1 더. 2.90% → 0.70%.
  LevelSpec(
    id: 8, name: '먼길', // 구 10
    width: 8, height: 8,
    coreTier: 6, coreCount: 4,
    fillQuotas: [TierQuota(1, 2, 6), TierQuota(2, 1, 5), TierQuota(3, 0, 4)],
    backtrackBudget: 400,
  ),
  // 완화: fillQuotas min -2 누적 + 코어 4→3 (초안 [(1,4,6), (2,3,5), (4,1,3)]).
  // min -2까지 내려도 1.10%라 8×8 지침(코어를 4→3)을 함께 적용했다. → 0.10%.
  LevelSpec(
    id: 9, name: '외딴곳', // 구 11
    width: 8, height: 8,
    coreTier: 6, coreCount: 3,
    fillQuotas: [TierQuota(1, 2, 6), TierQuota(2, 1, 5), TierQuota(4, 0, 3)],
    backtrackBudget: 400,
  ),
  // 완화: fillQuotas min -2 누적 + 코어 4→3 (초안 [(1,4,6), (2,3,5), (4,2,4)]).
  // 위와 같은 이유. 4.20% → 0.10%.
  LevelSpec(
    id: 10, name: '마루', // 구 12
    width: 8, height: 8,
    coreTier: 6, coreCount: 3,
    fillQuotas: [TierQuota(1, 2, 6), TierQuota(2, 1, 5), TierQuota(4, 1, 4)],
    backtrackBudget: 400,
  ),
];

/// id로 조회. UI(04-06)가 쓴다.
LevelSpec levelById(int id) => levels.firstWhere((l) => l.id == id);
