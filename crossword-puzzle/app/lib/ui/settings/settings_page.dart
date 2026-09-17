// 설정·정보 화면 (04-06 "설정·정보 화면"). 힌트 모드, 단어 데이터(DB) 정보,
// 출처·라이선스 표기로 구성된다.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/db/app_database.dart';
import '../state/app_scope.dart';
import '../state/settings_model.dart';
import 'license_page.dart';

/// pubspec.yaml `version: 1.0.0+1`과 맞춘 상수 (04-06 "앱 버전 1.0.0 (1)").
/// `package_info_plus` 같은 의존성을 새로 넣지 않는 1차 범위라, pubspec.yaml의
/// version을 바꾸면 이 값도 같이 바꿔야 한다.
const _appVersionName = '1.0.0';
const _appVersionBuildNumber = '1';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          const _SectionHeader('힌트'),
          RadioGroup<HintMode>(
            groupValue: settings.hintMode,
            onChanged: (mode) {
              if (mode != null) context.read<SettingsModel>().setHintMode(mode);
            },
            child: const Column(
              children: [
                RadioListTile<HintMode>(
                  value: HintMode.definition,
                  title: Text('뜻풀이'),
                ),
                RadioListTile<HintMode>(
                  value: HintMode.association,
                  title: Text('연상어 (유의어 없으면 뜻풀이)'),
                ),
              ],
            ),
          ),
          const Divider(),
          const _SectionHeader('단어 데이터'),
          const _DbInfoSection(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: OutlinedButton(
              // 5단계(SyncService)에서 연결한다 (04-06 DoD "갱신 UI 자리가
              // 비활성 상태로 존재").
              onPressed: null,
              child: const Text('지금 갱신'),
            ),
          ),
          SwitchListTile(
            title: const Text('Wi-Fi에서만 갱신'),
            value: settings.wifiOnlySync,
            // 위 버튼과 같은 이유로 비활성 — 값 자체는 이미 저장/로드된다
            // (SettingsModel.setWifiOnlySync는 5단계에서 이 토글에 연결한다).
            onChanged: null,
          ),
          const Divider(),
          const _SectionHeader('정보'),
          ListTile(
            title: const Text('출처 및 라이선스'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LicenseNoticePage()),
            ),
          ),
          ListTile(
            title: const Text('오픈소스 라이선스'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: '단어 연상 퀴즈',
              applicationVersion: _appVersionName,
            ),
          ),
          const ListTile(
            title: Text('앱 버전'),
            trailing: Text('$_appVersionName ($_appVersionBuildNumber)'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

/// DB `meta`(02-09)에서 읽는 4개 값 (04-06 "DB 정보" 표).
class _DbInfo {
  final String? version; // meta.db_version
  final String? wordCount; // meta.word_count
  final String? builtAt; // meta.built_at
  final String? lastSyncAt; // meta.last_sync_at (5단계에서 앱이 기록)

  const _DbInfo({this.version, this.wordCount, this.builtAt, this.lastSyncAt});
}

Future<_DbInfo> _loadDbInfo(AppDatabase db) async {
  final values = await Future.wait([
    db.metaValue('db_version'),
    db.metaValue('word_count'),
    db.metaValue('built_at'),
    db.metaValue('last_sync_at'),
  ]);
  return _DbInfo(
    version: values[0],
    wordCount: values[1],
    builtAt: values[2],
    lastSyncAt: values[3],
  );
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

/// ISO-8601 문자열(`built_at`/`last_sync_at`)에서 날짜 부분(앞 10자)만 보여준다.
String _formatDate(String? raw) {
  if (raw == null || raw.isEmpty) return '-';
  return raw.length >= 10 ? raw.substring(0, 10) : raw;
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
  late final Future<_DbInfo> _future = _loadDbInfo(context.read<AppScope>().db);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DbInfo>(
      future: _future,
      builder: (context, snapshot) {
        final info = snapshot.data;
        return Column(
          children: [
            ListTile(
              title: const Text('버전'),
              trailing: Text(info?.version ?? '-'),
            ),
            ListTile(
              title: const Text('단어 수'),
              trailing: Text(_formatCount(info?.wordCount)),
            ),
            ListTile(
              title: const Text('빌드 시각'),
              trailing: Text(_formatDate(info?.builtAt)),
            ),
            ListTile(
              title: const Text('마지막 갱신'),
              trailing: Text(_formatDate(info?.lastSyncAt)),
            ),
          ],
        );
      },
    );
  }
}
