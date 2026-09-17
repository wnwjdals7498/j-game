// 홈 화면 상태 (04-01 골격). 실제 내용은 04-06(홈·설정 화면)에서 채운다.
import 'package:flutter/foundation.dart';

import 'app_scope.dart';

/// 홈 화면 상태: 레벨 목록 + 해제 상태 + 누적 통계.
///
/// 04-06에서 `levels`(01-09/03-06)와 `StatRepository`(03-04)를 읽어 레벨별
/// 잠금/해제·클리어 표시와 누적 통계를 채운다.
class HomeModel extends ChangeNotifier {
  final AppScope scope;

  bool loading = true;

  HomeModel(this.scope);

  /// 04-06에서 레벨 목록·해제 상태·누적 통계 조회 로직을 채운다.
  Future<void> load() async {
    loading = false;
    notifyListeners();
  }
}
