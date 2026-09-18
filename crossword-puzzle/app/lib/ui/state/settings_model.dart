// 설정 화면 상태 (04-06). `shared_preferences`에 저장한다 — DB에 넣지 않는 이유는
// 갱신(05-03)으로 DB가 교체돼도 설정이 살아남아야 하기 때문 (04-06 "설정 저장").
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 힌트 표시 모드. 04-03(단어 선택·힌트 패널)이 이 값을 읽어 힌트 텍스트를 고른다.
enum HintMode { definition, association }

const _keyHintMode = 'hintMode';

/// `main.dart`의 자동 갱신(05-04)도 `SettingsModel` 인스턴스 없이 이 키로
/// 직접 읽는다 — 부트스트랩 시점엔 아직 `SettingsModel`이 만들어지기 전이다.
const wifiOnlySyncPrefsKey = 'wifiOnlySync';

/// 첫 퍼즐 화면 진입 시 조작법 안내(칸 두 번 탭 → 방향 전환 등)를 봤는지.
/// 설정 화면에 노출되는 값이 아니라 `puzzle_page.dart`만 보는 1회성 플래그라
/// `SettingsModel` 필드로 두지 않고 이 키만 직접 읽고 쓴다.
const tutorialSeenPrefsKey = 'tutorialSeen';

/// 설정 상태: 힌트 모드, Wi-Fi 전용 갱신 등.
///
/// 저장 항목은 `hintMode`, `wifiOnlySync` 둘뿐이다(04-06 "설정 저장").
/// `wifiOnlySync`는 05-04에서 설정 화면 토글과 `SyncService.sync(wifiOnly:)`
/// 양쪽에 연결됐다.
class SettingsModel extends ChangeNotifier {
  HintMode hintMode = HintMode.definition;
  bool wifiOnlySync = true;

  bool loading = true;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_keyHintMode);
    hintMode =
        savedMode == HintMode.association.name ? HintMode.association : HintMode.definition;
    wifiOnlySync = prefs.getBool(wifiOnlySyncPrefsKey) ?? true;

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
    await prefs.setBool(wifiOnlySyncPrefsKey, value);
  }
}
