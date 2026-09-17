// 설정 화면 상태 (04-06). `shared_preferences`에 저장한다 — DB에 넣지 않는 이유는
// 갱신(05-03)으로 DB가 교체돼도 설정이 살아남아야 하기 때문 (04-06 "설정 저장").
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 힌트 표시 모드. 04-03(단어 선택·힌트 패널)이 이 값을 읽어 힌트 텍스트를 고른다.
enum HintMode { definition, association }

const _keyHintMode = 'hintMode';
const _keyWifiOnlySync = 'wifiOnlySync';

/// 설정 상태: 힌트 모드, Wi-Fi 전용 갱신 등.
///
/// 저장 항목은 `hintMode`, `wifiOnlySync` 둘뿐이다(04-06 "설정 저장"). Wi-Fi
/// 전용 갱신은 5단계에서 실제로 연결되기 전까지 화면상 토글이 비활성 상태이지만
/// (04-06 DoD), 값 자체는 여기서 미리 로드해 둔다.
class SettingsModel extends ChangeNotifier {
  HintMode hintMode = HintMode.definition;
  bool wifiOnlySync = true;

  bool loading = true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_keyHintMode);
    hintMode =
        savedMode == HintMode.association.name ? HintMode.association : HintMode.definition;
    wifiOnlySync = prefs.getBool(_keyWifiOnlySync) ?? true;

    loading = false;
    notifyListeners();
  }

  Future<void> setHintMode(HintMode mode) async {
    if (mode == hintMode) return;
    hintMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHintMode, mode.name);
  }

  Future<void> setWifiOnlySync(bool value) async {
    if (value == wifiOnlySync) return;
    wifiOnlySync = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyWifiOnlySync, value);
  }
}
