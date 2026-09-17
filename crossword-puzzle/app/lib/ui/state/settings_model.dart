// 설정 화면 상태 (04-01 골격). 실제 내용은 04-06(홈·설정 화면)에서 채운다.
import 'package:flutter/foundation.dart';

/// 힌트 표시 모드. 04-03(단어 선택·힌트 패널)이 이 값을 읽어 힌트 텍스트를 고른다.
enum HintMode { definition, association }

/// 설정 상태: 힌트 모드, Wi-Fi 전용 갱신 등.
///
/// `shared_preferences` 연동은 04-06에서 추가한다. 지금은 메모리 기본값만 갖는
/// 골격이라 [load]는 즉시 완료된다.
class SettingsModel extends ChangeNotifier {
  HintMode hintMode = HintMode.definition;
  bool wifiOnlySync = true;

  bool loading = true;

  /// 04-06에서 `shared_preferences`로 저장된 값을 읽어오도록 채운다.
  Future<void> load() async {
    loading = false;
    notifyListeners();
  }
}
