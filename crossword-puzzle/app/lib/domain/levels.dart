import 'model/level_spec.dart';

/// 레벨 테이블 초안. 실데이터 측정 후 03-06에서 v1 확정.
/// 값을 고치면 01-10 / 03-05 하네스를 다시 돌려 리포트를 갱신한다.
///
/// 아래 `완화:` 주석이 붙은 레벨은 01-09 "막히면" 절에 따라 초안 값을 완화한 것이다.
/// 더미 사전 기준 seed 1000..20000 이 전부 성공하도록 맞췄고, 실데이터 기준은
/// 03-05 측정 후 03-06에서 다시 잡는다.
const List<LevelSpec> levels = [
  LevelSpec(
    id: 1, name: '첫걸음',
    width: 5, height: 5,
    coreTier: 2, coreCount: 2,
    fillQuotas: [TierQuota(1, 2, 4)],
    backtrackBudget: 150,
  ),
  // 완화: fillQuotas min -1 (초안 [TierQuota(1, 2, 4)]).
  // 5×5에 코어 3개가 들어가면 남는 슬롯이 적어 채움 2개를 강제할 수 없었다.
  LevelSpec(
    id: 2, name: '둘레길',
    width: 5, height: 5,
    coreTier: 2, coreCount: 3,
    fillQuotas: [TierQuota(1, 1, 4)],
    backtrackBudget: 150,
  ),
  LevelSpec(
    id: 3, name: '갈림길',
    width: 6, height: 6,
    coreTier: 3, coreCount: 3,
    fillQuotas: [TierQuota(1, 2, 3), TierQuota(2, 1, 3)],
    backtrackBudget: 200,
  ),
  LevelSpec(
    id: 4, name: '어스름',
    width: 6, height: 6,
    coreTier: 3, coreCount: 3,
    fillQuotas: [TierQuota(1, 2, 4), TierQuota(2, 2, 4)],
    backtrackBudget: 200,
  ),
  LevelSpec(
    id: 5, name: '들머리',
    width: 6, height: 6,
    coreTier: 4, coreCount: 3,
    fillQuotas: [TierQuota(1, 2, 4), TierQuota(2, 2, 4)],
    backtrackBudget: 200,
  ),
  LevelSpec(
    id: 6, name: '엇갈림',
    width: 7, height: 7,
    coreTier: 4, coreCount: 3,
    fillQuotas: [TierQuota(1, 3, 5), TierQuota(2, 2, 4), TierQuota(3, 1, 3)],
    backtrackBudget: 300,
  ),
  LevelSpec(
    id: 7, name: '깊은숲',
    width: 7, height: 7,
    coreTier: 5, coreCount: 3,
    fillQuotas: [TierQuota(1, 3, 5), TierQuota(2, 2, 4), TierQuota(3, 1, 3)],
    backtrackBudget: 300,
  ),
  // 완화: fillQuotas min -1 (초안 [(1,3,5), (2,2,4), (3,1,3)]).
  LevelSpec(
    id: 8, name: '돌아섬',
    width: 7, height: 7,
    coreTier: 5, coreCount: 4,
    fillQuotas: [TierQuota(1, 2, 5), TierQuota(2, 1, 4), TierQuota(3, 0, 3)],
    backtrackBudget: 300,
  ),
  // 완화: fillQuotas min -1 + 코어 4→3 (초안 coreCount 4).
  // min만 낮춰서는 2개 seed가 계속 실패했다. 8×8은 코어가 많을수록 교차 위치가
  // 안 나온다는 01-09 "막히면" 지침을 이 레벨에 적용했다.
  LevelSpec(
    id: 9, name: '벼랑끝',
    width: 8, height: 8,
    coreTier: 5, coreCount: 3,
    fillQuotas: [TierQuota(1, 3, 6), TierQuota(2, 2, 5), TierQuota(3, 1, 4)],
    backtrackBudget: 400,
  ),
  // 완화: fillQuotas min -1 (초안 [(1,4,6), (2,3,5), (3,2,4)]).
  LevelSpec(
    id: 10, name: '먼길',
    width: 8, height: 8,
    coreTier: 6, coreCount: 4,
    fillQuotas: [TierQuota(1, 3, 6), TierQuota(2, 2, 5), TierQuota(3, 1, 4)],
    backtrackBudget: 400,
  ),
  // 완화: fillQuotas min -1 (초안 [(1,4,6), (2,3,5), (4,1,3)]).
  LevelSpec(
    id: 11, name: '외딴곳',
    width: 8, height: 8,
    coreTier: 6, coreCount: 4,
    fillQuotas: [TierQuota(1, 3, 6), TierQuota(2, 2, 5), TierQuota(4, 0, 3)],
    backtrackBudget: 400,
  ),
  // 완화: fillQuotas min -1 (초안 [(1,4,6), (2,3,5), (4,2,4)]).
  LevelSpec(
    id: 12, name: '마루',
    width: 8, height: 8,
    coreTier: 6, coreCount: 4,
    fillQuotas: [TierQuota(1, 3, 6), TierQuota(2, 2, 5), TierQuota(4, 1, 4)],
    backtrackBudget: 400,
  ),
];

/// id로 조회. UI(04-06)가 쓴다.
LevelSpec levelById(int id) => levels.firstWhere((l) => l.id == id);
