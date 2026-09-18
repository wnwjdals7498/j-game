// 04-06 홈 · 설정 · 출처 표기 화면 테스트.
//
// "홈 화면" 그룹은 `tools/schema.sql`(단일 진실)로 만든 빈 실 DB에 필요한 값만
// 손으로 심어(customStatement) `HomeModel`이 만드는 잠금/해제/클리어 3가지
// 상태를 확인한다 — shell_test.dart(04-01)·submit_test.dart(04-05)와 같은
// 패턴이다. 레벨 화면 진입은 더미 사전(01-10)으로 실제 `PuzzlePage`까지
// 띄우되, 내부 퍼즐 생성 성공 여부에 기대지 않고 **위젯 생성자 인자**
// (`spec`/`seed`)만 확인한다 — newSeed()가 현재 시각 기반이라 생성 성공을
// 보장할 수 없기 때문이다(성공 여부는 submit_test.dart 통합 테스트가 이미
// 고정 seed로 검증했다).
//
// "설정 화면"·"출처 및 라이선스 화면" 그룹은 `SettingsModel`(shared_preferences)과
// `assets/LICENSES.md`(= `docs/LICENSES.md`의 자동 복사본, tools/build_sqlite.py
// `_sync_licenses()`)를 검증한다.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:jgame/data/db/app_database.dart';
import 'package:jgame/data/hint_repository.dart';
import 'package:jgame/data/stat_repository.dart';
import 'package:jgame/data/sync/sync_result.dart';
import 'package:jgame/domain/fixtures/dummy_dictionary.dart';
import 'package:jgame/domain/generator/grid_generator.dart';
import 'package:jgame/domain/levels.dart';
import 'package:jgame/ui/home/home_page.dart';
import 'package:jgame/ui/puzzle/puzzle_page.dart';
import 'package:jgame/ui/settings/license_page.dart';
import 'package:jgame/ui/settings/settings_page.dart';
import 'package:jgame/ui/state/app_scope.dart';
import 'package:jgame/ui/state/settings_model.dart';

/// "지금 갱신" 버튼(05-04) 테스트용 가짜. 항상 같은 [SyncResult]를 돌려준다.
class _FakeSyncService implements SyncService {
  _FakeSyncService(this.result);

  final SyncResult result;
  int callCount = 0;

  @override
  Future<SyncResult> sync({bool force = false, bool wifiOnly = true}) async {
    callCount++;
    return result;
  }

  @override
  void dispose() {}
}

void main() {
  late Directory tmp;
  late String schemaSql;
  var dbSeq = 0;

  setUpAll(() {
    schemaSql = File('../tools/schema.sql').readAsStringSync();
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('home_settings_test_');
    dbSeq = 0;
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  AppDatabase openEmptyDb() {
    final path = '${tmp.path}/t${dbSeq++}.sqlite';
    final raw = sqlite3.open(path);
    raw.execute(schemaSql);
    raw.close();
    return AppDatabase(NativeDatabase(File(path)));
  }

  /// shell_test.dart(04-01)·submit_test.dart(04-05)와 같은 패턴: 더미 사전으로
  /// 성공하는 [AppScope]를 만든다. [syncService]를 생략하면(대부분의 기존
  /// 테스트) `null`이다 — 05-04의 "지금 갱신" 버튼이 안 그려지는 그 경로다.
  AppScope buildScope(AppDatabase db, {SyncService? syncService}) {
    final words = InMemoryWordRepository(buildDummyDictionary(seed: 1));
    return AppScope(
      db: db,
      words: words,
      stats: StatRepository(db),
      generator: GridGenerator(words),
      hints: HintRepository(db),
      syncService: syncService,
    );
  }

  Widget wrapHome(AppScope scope) => MultiProvider(
        providers: [
          Provider<AppScope>.value(value: scope),
          ChangeNotifierProvider(create: (_) => SettingsModel()),
        ],
        child: const MaterialApp(home: HomePage()),
      );

  /// 기본 테스트 뷰포트(약 800×600)로는 레벨 10줄 + 통계 헤더가 다 안 들어가
  /// `ListView`가 화면 밖 항목을 아예 빌드하지 않는다(레이지 리스트라 완전히
  /// 잘림 — `Offstage`가 아니라 위젯 트리에 없다). 전부 렌더되도록 세로로
  /// 넉넉한 화면을 쓴다.
  Future<void> useTallViewport(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Widget wrapSettings(AppScope scope, SettingsModel settings) => MultiProvider(
        providers: [
          Provider<AppScope>.value(value: scope),
          ChangeNotifierProvider<SettingsModel>.value(value: settings),
        ],
        child: MaterialApp(home: const SettingsPage()),
      );

  group('홈 화면', () {
    testWidgets('레벨 목록 렌더: levels.length개 행', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(wrapHome(buildScope(db)));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsNWidgets(levels.length));
    });

    testWidgets('레벨 1 항상 해제: 통계 없어도 탭 가능', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb(); // 통계 전혀 없음
      addTearDown(db.close);

      await tester.pumpWidget(wrapHome(buildScope(db)));
      await tester.pumpAndSettle();

      await tester.tap(find.text(levels.first.name));
      await tester.pumpAndSettle();

      final page = tester.widget<PuzzlePage>(find.byType(PuzzlePage));
      expect(page.spec?.id, levels.first.id);
    });

    testWidgets('잠금 표시: 이전 레벨 미클리어 → 자물쇠', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb(); // 통계 없음 → 레벨 1만 해제
      addTearDown(db.close);

      await tester.pumpWidget(wrapHome(buildScope(db)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.lock), findsNWidgets(levels.length - 1));
    });

    testWidgets('클리어 표시: bestScore >= clearScore → ★ + 점수', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);
      // 레벨 1만 클리어(score=3 >= clearScore 0) → 레벨 2가 해제되지만
      // 아직 미클리어, 레벨 3부터는 여전히 잠김.
      await db.customStatement(
        'INSERT INTO puzzle_log (level_id, seed, first_score, submitted_at) '
        'VALUES (?, ?, ?, ?)',
        [levels.first.id, 1, 3, 0],
      );

      await tester.pumpWidget(wrapHome(buildScope(db)));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.text('+3'), findsOneWidget);
      expect(find.text('─'), findsOneWidget, reason: '레벨 2: 해제됐으나 미클리어');
      expect(find.byIcon(Icons.lock), findsNWidgets(levels.length - 2));
    });

    testWidgets('잠긴 레벨 탭: 이동 안 함, 스낵바 안내', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(wrapHome(buildScope(db)));
      await tester.pumpAndSettle();

      await tester.tap(find.text(levels[1].name)); // 레벨 2, 통계 없어 잠김
      await tester.pump(); // 스낵바 등장 프레임만 먼저 확인

      expect(find.byType(PuzzlePage), findsNothing);
      expect(find.textContaining('클리어해야'), findsOneWidget);

      // 스낵바 자동 닫힘 타이머를 여기서 다 흘려보낸다 — 안 하면 이 테스트가
      // 끝나도 타이머가 남아 있어서 다음 테스트의 pumpAndSettle이 엉뚱하게
      // 오래 걸리거나 실패할 수 있다.
      await tester.pumpAndSettle();
    });

    testWidgets('해제 레벨 탭: 퍼즐 화면으로, 새 seed', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(wrapHome(buildScope(db)));
      await tester.pumpAndSettle();

      await tester.tap(find.text(levels.first.name));
      await tester.pumpAndSettle();

      final page = tester.widget<PuzzlePage>(find.byType(PuzzlePage));
      expect(page.spec?.id, levels.first.id);
      expect(page.seed, inInclusiveRange(0, 0x7FFFFFFF), reason: 'newSeed()로 새로 생성');
    });

    testWidgets('누적 통계: summary() 값 표시', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO word_stat (headword, correct, wrong, last_seen) "
        "VALUES ('가나', 3, 1, 0)",
      );

      await tester.pumpWidget(wrapHome(buildScope(db)));
      await tester.pumpAndSettle();

      expect(find.text('75%'), findsOneWidget, reason: 'correct 3 / (3+1) = 75%');
      expect(find.text('1개'), findsOneWidget, reason: 'word_stat 행 1개');
    });
  });

  group('설정 화면', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('힌트 모드 변경: SettingsModel 저장, 재시작 후 유지', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);
      final settings = SettingsModel();
      await settings.load();

      await tester.pumpWidget(wrapSettings(buildScope(db), settings));
      await tester.pumpAndSettle();
      expect(settings.hintMode, HintMode.definition);

      await tester.tap(find.text('연상어 (유의어 없으면 뜻풀이)'));
      await tester.pumpAndSettle();
      expect(settings.hintMode, HintMode.association);

      // "재시작"은 새 SettingsModel 인스턴스로 흉내 낸다 — shared_preferences
      // mock 저장소(SharedPreferences.setMockInitialValues)는 테스트 프로세스
      // 동안 공유되므로, 새 인스턴스가 같은 값을 읽으면 저장이 된 것이다.
      final restarted = SettingsModel();
      await restarted.load();
      expect(restarted.hintMode, HintMode.association);
    });

    testWidgets('DB 정보: meta 값 표시', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO meta (key, value) VALUES "
        "('db_version', '3'), ('word_count', '45678'), "
        "('built_at', '2026-09-16T00:00:00.000Z')",
      );

      await tester.pumpWidget(wrapSettings(buildScope(db), SettingsModel()));
      await tester.pumpAndSettle();

      expect(find.text('3'), findsOneWidget, reason: 'db_version');
      expect(find.text('45,678'), findsOneWidget, reason: 'word_count, 천 단위 구분');
      expect(find.text('2026-09-16'), findsOneWidget, reason: 'built_at 날짜 부분');
    });

    testWidgets('오픈소스 라이선스: showLicensePage 진입', (tester) async {
      await useTallViewport(tester);
      final db = openEmptyDb();
      addTearDown(db.close);

      await tester.pumpWidget(wrapSettings(buildScope(db), SettingsModel()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('오픈소스 라이선스'));
      await tester.pumpAndSettle();

      expect(find.byType(LicensePage), findsOneWidget);
    });

    group('지금 갱신 버튼 (05-04)', () {
      testWidgets('AppScope.syncService가 null이면(웹) 버튼이 안 보임',
          (tester) async {
        await useTallViewport(tester);
        final db = openEmptyDb();
        addTearDown(db.close);

        await tester.pumpWidget(wrapSettings(buildScope(db), SettingsModel()));
        await tester.pumpAndSettle();

        expect(find.text('지금 갱신'), findsNothing);
      });

      testWidgets('성공: 단어 수 표시 + 재시작 안내 스낵바', (tester) async {
        await useTallViewport(tester);
        final db = openEmptyDb();
        addTearDown(db.close);
        final sync = _FakeSyncService(
            const SyncResult(SyncOutcome.success, wordCount: 45678));

        await tester.pumpWidget(
            wrapSettings(buildScope(db, syncService: sync), SettingsModel()));
        await tester.pumpAndSettle();

        expect(find.text('지금 갱신'), findsOneWidget);
        await tester.tap(find.text('지금 갱신'));
        await tester.pump(); // 스낵바 등장 프레임만 먼저 확인

        expect(sync.callCount, 1);
        expect(find.textContaining('45,678개로'), findsOneWidget);
        expect(find.textContaining('다시 시작'), findsOneWidget);

        await tester.pumpAndSettle(); // 스낵바 타이머 정리
      });

      testWidgets('스키마 불일치: "재시도"가 아니라 "업데이트" 안내',
          (tester) async {
        // 재시도로는 안 풀리는 상태를 재시도하라고 안내하면 사용자가 영원히
        // 헛수고한다 — 05-04 리뷰에서 지적된 메시지 버킷 오류의 회귀 테스트.
        await useTallViewport(tester);
        final db = openEmptyDb();
        addTearDown(db.close);
        final sync =
            _FakeSyncService(const SyncResult(SyncOutcome.skippedSchemaIncompatible));

        await tester.pumpWidget(
            wrapSettings(buildScope(db, syncService: sync), SettingsModel()));
        await tester.pumpAndSettle();

        await tester.tap(find.text('지금 갱신'));
        await tester.pump();

        expect(find.textContaining('업데이트'), findsOneWidget);
        expect(find.textContaining('다시 시도'), findsNothing);

        await tester.pumpAndSettle();
      });

      testWidgets('Wi-Fi에서만 갱신 토글: SettingsModel 저장, 재시작 후 유지',
          (tester) async {
        await useTallViewport(tester);
        final db = openEmptyDb();
        addTearDown(db.close);
        final settings = SettingsModel();
        await settings.load();

        await tester.pumpWidget(wrapSettings(buildScope(db), settings));
        await tester.pumpAndSettle();
        expect(settings.wifiOnlySync, isTrue);

        await tester.tap(find.text('Wi-Fi에서만 갱신'));
        await tester.pumpAndSettle();
        expect(settings.wifiOnlySync, isFalse);

        final restarted = SettingsModel();
        await restarted.load();
        expect(restarted.wifiOnlySync, isFalse);
      });
    });
  });

  group('출처 및 라이선스 화면 (필수)', () {
    // `SelectableText`(내부 `EditableText`)는 화면을 두 번째로 새로 pump하면
    // 앞 테스트의 제스처 인식용 타이머가 아직 안 끝난 상태로 겹쳐 다음
    // `pumpAndSettle`이 멈춰버리는 경우가 있었다 — 그래서 같은 화면을 여러
    // testWidgets에 나눠 두 번 띄우지 않고, 04-06 "테스트" 표의 두 항목("4개
    // 자료명이 전부 보임"·"라이선스 문구: assets/LICENSES.md와 동일")을 한
    // 화면 인스턴스에서 함께 확인한다.
    testWidgets('4개 자료명이 전부 보임 + assets/LICENSES.md와 동일한 문구', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: LicenseNoticePage()));
      await tester.pumpAndSettle();

      expect(find.textContaining('한국어기초사전'), findsOneWidget);
      expect(find.textContaining('표준국어대사전'), findsOneWidget);
      expect(find.textContaining('현대 국어 사용 빈도 조사 2'), findsOneWidget);
      expect(find.textContaining('한국어 학습용 어휘 목록'), findsOneWidget);

      final expected = File('assets/LICENSES.md').readAsStringSync();
      final widget = tester.widget<SelectableText>(find.byType(SelectableText));
      expect(widget.data, expected);
    });
  });
}
