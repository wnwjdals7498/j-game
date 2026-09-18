// 설정·정보 화면 (04-06 "설정·정보 화면"). 힌트 모드, 단어 데이터(DB) 정보,
// 출처·라이선스 표기로 구성된다.
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/db/app_database.dart';
import '../../data/sync/sync_result.dart';
import '../common/section_header.dart';
import '../state/app_scope.dart';
import '../state/settings_model.dart';
import '../theme/fade_through_route.dart';
import '../theme/tokens.dart';
import 'license_page.dart';

/// 06-01 "앱 이름 확정" — `AndroidManifest.xml`의 `android:label`,
/// `main.dart`의 `MaterialApp.title`과 같은 이름을 쓴다.
const _appName = 'J Crossword Puzzle';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          const SectionHeader('화면'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GameSpace.l),
            child: SegmentedButton<ThemeMode>(
              segments: const [                        // showSelectedIcon: false —
                ButtonSegment(value: ThemeMode.system, label: Text('시스템')),  // UI-GUIDE 1절
                ButtonSegment(value: ThemeMode.light, label: Text('라이트')),  // "아이콘으로
                ButtonSegment(value: ThemeMode.dark, label: Text('다크')),    //  빈 곳 채우기" 금지
              ],
              selected: {settings.themeMode},
              showSelectedIcon: false,
              onSelectionChanged: (s) =>
                  context.read<SettingsModel>().setThemeMode(s.first),
            ),
          ),
          SwitchListTile(
            dense: true,
            title: const Text('효과음'),
            subtitle: const Text('기기의 터치음 설정을 따릅니다'),
            value: settings.soundEnabled,
            onChanged: (value) =>
                context.read<SettingsModel>().setSoundEnabled(value),
          ),
          const Divider(),
          const SectionHeader('힌트'),
          RadioGroup<HintMode>(
            groupValue: settings.hintMode,
            onChanged: (mode) {
              if (mode != null) context.read<SettingsModel>().setHintMode(mode);
            },
            child: const Column(
              children: [
                RadioListTile<HintMode>(
                  dense: true,
                  value: HintMode.definition,
                  title: Text('뜻풀이'),
                ),
                RadioListTile<HintMode>(
                  dense: true,
                  value: HintMode.association,
                  title: Text('연상어 (유의어 없으면 뜻풀이)'),
                ),
              ],
            ),
          ),
          const Divider(),
          const SectionHeader('단어 데이터'),
          const _DbInfoSection(),
          const _SyncNowButton(),
          SwitchListTile(
            dense: true,
            title: const Text('Wi-Fi에서만 갱신'),
            value: settings.wifiOnlySync,
            onChanged: (value) =>
                context.read<SettingsModel>().setWifiOnlySync(value),
          ),
          const Divider(),
          const SectionHeader('정보'),
          ListTile(
            dense: true,
            title: const Text('출처 및 라이선스'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              GameRoute(builder: (_) => const LicenseNoticePage()),
            ),
          ),
          const _AppVersionSection(),
        ],
      ),
    );
  }
}

/// DB `meta`(02-09)에서 읽는 3개 값 (04-06 "DB 정보" 표). `last_sync_at`은
/// 여기 없다 — 별도로(`_lastSyncAtMillis`) 읽는다: `db`가 갱신(05-04)으로
/// 닫혀 있어도 `shared_preferences` 값은 영향받지 않으므로, DB 조회 실패가
/// "마지막 갱신" 표시까지 같이 지워버리면 안 된다.
class _DbInfo {
  final String? version; // meta.db_version
  final String? wordCount; // meta.word_count
  final String? builtAt; // meta.built_at

  const _DbInfo({this.version, this.wordCount, this.builtAt});
}

Future<_DbInfo> _loadDbInfo(AppDatabase db) async {
  final values = await Future.wait([
    db.metaValue('db_version'),
    db.metaValue('word_count'),
    db.metaValue('built_at'),
  ]);
  return _DbInfo(version: values[0], wordCount: values[1], builtAt: values[2]);
}

/// `last_sync_at`은 **`meta`가 아니라 `shared_preferences`에서** 읽는다 —
/// DB 교체(05-03)로 `meta`가 통째로 새 DB 것으로 갈아엎이므로, 갱신 시각을
/// `meta`에 두면 갱신할 때마다 사라진다(05-02 "`last_sync_at` 저장 위치").
Future<int?> _loadLastSyncAtMillis() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getInt(lastSyncAtPrefsKey);
}

/// 천 단위 구분 쉼표만 넣는다 (예: 45678 -> "45,678"). 이 표시 하나만을 위해
/// `intl` 의존성을 새로 넣지 않는다.
String _formatCount(String? raw) {
  if (raw == null) return '-';
  final n = int.tryParse(raw);
  if (n == null) return raw;
  final digits = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return buf.toString();
}

/// ISO-8601 문자열(`built_at`)에서 날짜 부분(앞 10자)만 보여준다.
String _formatDate(String? raw) {
  if (raw == null || raw.isEmpty) return '-';
  return raw.length >= 10 ? raw.substring(0, 10) : raw;
}

/// `last_sync_at`(epoch milliseconds, 05-02 "`last_sync_at` 저장 위치")을
/// 같은 `yyyy-MM-dd` 형식으로 보여준다. `intl` 없이 직접 자릿수를 맞춘다.
String _formatEpochMillis(int? millis) {
  if (millis == null) return '-';
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// `AppDatabase.metaValue`는 매번 DB를 친다 — 화면이 다시 그려질 때마다(예:
/// 힌트 모드 라디오 변경) 새로 조회하지 않도록 `initState`에서 한 번만 연다
/// (main.dart `JGameApp`이 부트스트랩 Future를 생성자로 한 번만 받는 것과 같은
/// 이유).
class _DbInfoSection extends StatefulWidget {
  const _DbInfoSection();

  @override
  State<_DbInfoSection> createState() => _DbInfoSectionState();
}

class _DbInfoSectionState extends State<_DbInfoSection> {
  late final Future<_DbInfo> _dbFuture = _loadDbInfo(context.read<AppScope>().db);
  late final Future<int?> _lastSyncFuture = _loadLastSyncAtMillis();

  @override
  Widget build(BuildContext context) {
    // 마지막 갱신은 `shared_preferences` 값이라 아래 db 조회가 실패해도
    // (갱신(05-04)으로 db가 닫힌 경우 등) 영향받지 않는다 — 그래서 별도
    // FutureBuilder로 늘 그린다.
    final lastSyncTile = FutureBuilder<int?>(
      future: _lastSyncFuture,
      builder: (context, syncSnapshot) => ListTile(
        dense: true,
        title: const Text('마지막 갱신'),
        trailing: Text(_formatEpochMillis(syncSnapshot.data)),
      ),
    );

    return FutureBuilder<_DbInfo>(
      future: _dbFuture,
      builder: (context, dbSnapshot) {
        // "-"로 조용히 넘기지 않고 원인을 알린다(그래도 앱이 멈추진 않는다).
        if (dbSnapshot.hasError) {
          return Column(
            children: [
              const ListTile(
                dense: true,
                title: Text('단어 데이터'),
                subtitle: Text('불러오지 못했습니다. 앱을 다시 시작해 주세요.'),
              ),
              lastSyncTile,
            ],
          );
        }
        final info = dbSnapshot.data;
        return Column(
          children: [
            ListTile(
              dense: true,
              title: const Text('버전'),
              trailing: Text(info?.version ?? '-'),
            ),
            ListTile(
              dense: true,
              title: const Text('단어 수'),
              trailing: Text(_formatCount(info?.wordCount)),
            ),
            ListTile(
              dense: true,
              title: const Text('빌드 시각'),
              trailing: Text(_formatDate(info?.builtAt)),
            ),
            lastSyncTile,
          ],
        );
      },
    );
  }
}

/// "오픈소스 라이선스" 탭 + "앱 버전" 표시 (06-01). 둘 다 `PackageInfo`가
/// 있어야 하므로 하나의 `FutureBuilder`로 묶는다 — `_DbInfoSection`과 같은
/// "한 번만 연다" 패턴(`late final`)이다.
class _AppVersionSection extends StatefulWidget {
  const _AppVersionSection();

  @override
  State<_AppVersionSection> createState() => _AppVersionSectionState();
}

class _AppVersionSectionState extends State<_AppVersionSection> {
  late final Future<PackageInfo> _infoFuture = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: _infoFuture,
      builder: (context, snapshot) {
        final info = snapshot.data;
        return Column(
          children: [
            ListTile(
              dense: true,
              title: const Text('오픈소스 라이선스'),
              trailing: const Icon(Icons.chevron_right),
              onTap: info == null
                  ? null
                  : () => showLicensePage(
                        context: context,
                        applicationName: _appName,
                        applicationVersion: info.version,
                      ),
            ),
            ListTile(
              dense: true,
              title: const Text('앱 버전'),
              trailing: Text(
                info == null ? '-' : '${info.version} (${info.buildNumber})',
              ),
            ),
          ],
        );
      },
    );
  }
}

/// "지금 갱신" 버튼 (05-04). `AppScope.syncService`가 `null`이면(웹, 1차
/// 범위 밖) 아무것도 그리지 않는다.
///
/// 성공해도 `_DbInfoSection`(DB에서 읽는 값들)을 다시 조회하지 않는다 —
/// `AppScope.db`는 교체 도중 05-03의 `DbSwapper.swap`이 **닫아버린** 예전
/// 연결이다("옛 값이 보인다" 수준이 아니라 재조회하면 예외가 난다. `_DbInfo`
/// section도 이제 그 실패를 잡아서 안내로 바꾼다). 그래서 성공 시 스낵바로
/// "앱을 다시 시작해 주세요"를 안내하고, 재시작 전까지는 화면을 새로고침
/// 하지 않는다(05-04 "막히면"이 고른 1차 범위: `AppScope` 재구독 대신
/// 재시작 안내).
class _SyncNowButton extends StatefulWidget {
  const _SyncNowButton();

  @override
  State<_SyncNowButton> createState() => _SyncNowButtonState();
}

class _SyncNowButtonState extends State<_SyncNowButton> {
  bool _syncing = false;

  Future<void> _onPressed(SyncService syncService) async {
    setState(() => _syncing = true);
    // force: true라 Wi-Fi 전용 설정과 무관하게 진행한다(05-02 "'지금 갱신'
    // (force: true)은 사용자가 명시적으로 누른 것이므로 이 조건을 무시한다")
    // — 그래서 SettingsModel.wifiOnlySync를 여기서 읽지 않는다.
    final result = await syncService.sync(force: true);
    if (!mounted) return;
    setState(() => _syncing = false);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(_messageFor(result))));
  }

  /// 05-02 "사용자 안내" 표 — 수동 갱신(force)은 결과를 항상 알린다.
  String _messageFor(SyncResult result) {
    switch (result.outcome) {
      case SyncOutcome.success:
        return '단어 ${_formatCount('${result.wordCount ?? 0}')}개로 '
            '갱신했습니다. 앱을 다시 시작해 주세요.';
      case SyncOutcome.skippedUpToDate:
        return '이미 최신입니다.';
      case SyncOutcome.skippedOffline:
        return '네트워크에 연결할 수 없습니다.';
      case SyncOutcome.skippedAppTooOld:
      case SyncOutcome.skippedSchemaIncompatible:
        // 스키마 불일치는 재시도로 풀리지 않는다 — 앱 업데이트가 필요하다는
        // 점에서 skippedAppTooOld와 같은 메시지가 맞다("나중에 다시
        // 시도해 주세요"는 여기선 거짓 안내가 된다).
        return '앱을 업데이트해 주세요.';
      case SyncOutcome.skippedNotDue:
        // force: true라 이 값이 나올 수 없다 — enum 완전성 때문에 남긴다.
        return '갱신에 실패했습니다. 나중에 다시 시도해 주세요.';
      case SyncOutcome.failedDownload:
      case SyncOutcome.failedChecksum:
      case SyncOutcome.failedSanity:
      case SyncOutcome.failedSwap:
        return '갱신에 실패했습니다. 나중에 다시 시도해 주세요.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final syncService = context.read<AppScope>().syncService;
    if (syncService == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: OutlinedButton(
        onPressed: _syncing ? null : () => _onPressed(syncService),
        child: _syncing
            ? const SizedBox(
                width: 64,
                height: 2,
                child: LinearProgressIndicator(minHeight: 2),
              )
            : const Text('지금 갱신'),
      ),
    );
  }
}
