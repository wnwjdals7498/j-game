// 07-08-02 1절: 홈 골든 — 레벨 1 클리어(+12) 고정 상태.
//
// `recordSubmit`을 거치지 않고 SQL로 직접 넣는다 — `SubmitResult`를 손으로
// 조립하는 것보다 짧고 점수가 그대로 고정된다(문서 1절). 레벨 1의
// `clearScore`가 0이므로 `first_score 12`면 클리어고, `HomeModel.load`가
// 레벨 1 클리어 → 레벨 2 해제 → 3부터 잠금으로 채운다 — "카드 3상태 모두
// 보임"이 레벨 1~3에서 만족된다.
@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jgame/data/db/app_database.dart';
import 'package:jgame/ui/home/home_page.dart';
import 'package:jgame/ui/state/settings_model.dart';

import 'golden_helpers.dart';

/// 홈 화면 상태 한 줄("누적 정답률", "푼 단어")이 0/0이 아니게 word_stat도
/// 채운다. `submitted_at`·`last_seen`은 0으로 둔다 — `DateTime.now()`가
/// 들어가면 화면에 안 나오더라도 골든이 흔들릴 여지가 남는다(문서 1절).
Future<void> seedClearedLevel1(AppDatabase db) async {
  await db.customStatement(
    'INSERT INTO puzzle_log (level_id, seed, first_score, submitted_at) '
    'VALUES (1, 1000, 12, 0)',
  );
  for (final (hw, c, w) in [
    ('가나', 1, 0),
    ('나라', 1, 0),
    ('다리', 1, 0),
    ('라면', 1, 0),
    ('마루', 1, 0),
    ('바다', 0, 1),
  ]) {
    await db.customStatement(
      'INSERT INTO word_stat (headword, correct, wrong, last_seen) '
      'VALUES (?, ?, ?, 0)',
      [hw, c, w],
    );
  }
}

void main() {
  late Directory tmp;
  var dbSeq = 0;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('home_golden_test_');
    dbSeq = 0;
    // `HomePage`는 initState 후 프레임에서 항상 `SharedPreferences.getInstance()`
    // 를 친다(대기 중인 갱신 안내 확인, home_page.dart `_maybeShowSyncNotice`).
    // 값을 지정해 두지 않으면 플러그인이 없어 예외가 난다 — 다른 UI 테스트
    // 파일(home_screen_test.dart 등)도 같은 이유로 같은 값을 지정해 둔다.
    SharedPreferences.setMockInitialValues({tutorialSeenPrefsKey: true});
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  for (final (name, mode) in [
    ('light', ThemeMode.light),
    ('dark', ThemeMode.dark),
  ]) {
    testWidgets('홈 골든 — $name', (tester) async {
      final db = openGoldenDb(tmp, seq: dbSeq++);
      addTearDown(db.close);
      await seedClearedLevel1(db);

      await pumpGolden(
        tester,
        const HomePage(),
        scope: goldenScope(db),
        themeMode: mode,
      );

      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/home_$name.png'),
      );
    });
  }
}
