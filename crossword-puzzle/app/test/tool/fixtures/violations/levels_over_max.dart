import 'model/level_spec.dart';

const List<LevelSpec> levels = [
  LevelSpec(
    id: 1, name: '위반',
    width: 9, height: 9,
    coreTier: 2, coreCount: 2,
    fillQuotas: [TierQuota(1, 2, 4)],
    backtrackBudget: 150,
  ),
];
