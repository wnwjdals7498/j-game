// StatRepository(03-04) 테스트.
//
// word_stat/puzzle_log 순수 로직 테스트(첫 제출·재제출·누적 등)는 사전 데이터가
// 필요 없으므로 `tools/schema.sql`(단일 진실)로 직접 빈 DB를 만든다 —
// bootstrap_test.dart(03-02)와 같은 패턴이라 계약이 바뀌면 이 테스트도 자동으로
// 따라간다. "복습 루프" 통합 테스트만 실 `assets/words.sqlite` + GridGenerator를
// 쓴다 — word_repository_test.dart(03-03)와 같은 패턴.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:jgame/data/db/app_database.dart';
import 'package:jgame/data/drift_word_repository.dart';
import 'package:jgame/data/stat_repository.dart';
import 'package:jgame/domain/generator/grid_generator.dart';
import 'package:jgame/domain/levels.dart';
import 'package:jgame/domain/model/puzzle.dart';
import 'package:jgame/domain/model/submit_result.dart';
import 'package:jgame/domain/scoring/scorer.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

/// 순수 로직 테스트용. 실제 격자 배치는 필요 없고 headword/outcome만 쓴다.
PlacedWord _word(String headword) => PlacedWord(
      headword: headword,
      row: 0,
      col: 0,
      dir: Direction.across,
      isCore: false,
      tier: 1,
    );

/// headword -> outcome 맵으로 [SubmitResult]를 만든다.
SubmitResult _result(Map<String, WordOutcome> outcomes) {
  final results = outcomes.entries
      .map((e) => WordResult(_word(e.key), e.key, e.value))
      .toList();
  return SubmitResult(results, isFirstSubmit: true);
}

/// `puzzle_log` INSERT 시점에 일부러 예외를 던지는 테스트 전용 서브클래스.
/// [armed]가 true일 때만 발동해, 트랜잭션 도중 실패가 전부 롤백되는지 본다.
class _FaultyAppDatabase extends AppDatabase {
  _FaultyAppDatabase(super.executor);
  bool armed = false;

  @override
  Future<void> customStatement(String statement, [List<dynamic>? args]) {
    if (armed && statement.contains('INSERT INTO puzzle_log')) {
      throw Exception('injected failure (test)');
    }
    return super.customStatement(statement, args);
  }
}

void main() {
  late Directory tmp;
  late String schemaSql;

  setUpAll(() {
    // tools/schema.sql(02-09)이 단일 진실이다 (03-01 bootstrap_test.dart와 동일 근거).
    schemaSql = File('../tools/schema.sql').readAsStringSync();
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('stat_repository_test_');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  AppDatabase openEmpty(String path) {
    final raw = sqlite3.open(path);
    raw.execute(schemaSql);
    raw.close();
    return AppDatabase(NativeDatabase(File(path)));
  }

  group('recordSubmit', () {
    late AppDatabase db;
    late StatRepository stats;

    setUp(() {
      db = openEmpty('${tmp.path}/t.sqlite');
      stats = StatRepository(db);
    });

    tearDown(() => db.close());

    Future<QueryRow> statRow(String headword) => db.customSelect(
          'SELECT correct, wrong, last_seen FROM word_stat WHERE headword = ?',
          variables: [Variable.withString(headword)],
        ).getSingle();

    test('첫 제출 반영: word_stat에 행 생성, correct/wrong 정확', () async {
      final ok = await stats.recordSubmit(
        levelId: 1,
        seed: 1,
        result: _result({'가나': WordOutcome.correct, '다라': WordOutcome.wrong}),
      );
      expect(ok, isTrue);

      final ok1 = await statRow('가나');
      expect(ok1.read<int>('correct'), 1);
      expect(ok1.read<int>('wrong'), 0);

      final ok2 = await statRow('다라');
      expect(ok2.read<int>('correct'), 0);
      expect(ok2.read<int>('wrong'), 1);
    });

    test('재제출 미반영: 같은 (levelId, seed) 두 번 → 두 번째는 false, 값 불변',
        () async {
      await stats.recordSubmit(
        levelId: 1,
        seed: 1,
        result: _result({'가나': WordOutcome.correct}),
      );
      final before = await statRow('가나');

      final ok = await stats.recordSubmit(
        levelId: 1,
        seed: 1,
        result: _result({'가나': WordOutcome.wrong}),
      );
      expect(ok, isFalse);

      final after = await statRow('가나');
      expect(after.read<int>('correct'), before.read<int>('correct'));
      expect(after.read<int>('wrong'), before.read<int>('wrong'));
    });

    test('다른 seed는 반영: 같은 레벨 다른 seed → true', () async {
      await stats.recordSubmit(
        levelId: 1,
        seed: 1,
        result: _result({'가나': WordOutcome.correct}),
      );
      final ok = await stats.recordSubmit(
        levelId: 1,
        seed: 2,
        result: _result({'가나': WordOutcome.correct}),
      );
      expect(ok, isTrue);

      final row = await statRow('가나');
      expect(row.read<int>('correct'), 2, reason: '두 제출 모두 반영돼 누적됨');
    });

    test('빈칸이 오답으로 집계', () async {
      await stats.recordSubmit(
        levelId: 1,
        seed: 1,
        result: _result({'가나': WordOutcome.blank}),
      );
      final row = await statRow('가나');
      expect(row.read<int>('correct'), 0);
      expect(row.read<int>('wrong'), 1);
    });

    test('누적: 서로 다른 퍼즐에서 같은 단어 → 값이 누적', () async {
      await stats.recordSubmit(
        levelId: 1,
        seed: 1,
        result: _result({'가나': WordOutcome.correct}),
      );
      await stats.recordSubmit(
        levelId: 2,
        seed: 1,
        result: _result({'가나': WordOutcome.wrong}),
      );
      final row = await statRow('가나');
      expect(row.read<int>('correct'), 1);
      expect(row.read<int>('wrong'), 1);
    });

    test('last_seen 갱신: 제출 시각이 기록됨', () async {
      final before = DateTime.now().millisecondsSinceEpoch;
      await stats.recordSubmit(
        levelId: 1,
        seed: 1,
        result: _result({'가나': WordOutcome.correct}),
      );
      final after = DateTime.now().millisecondsSinceEpoch;

      final row = await statRow('가나');
      final lastSeen = row.read<int>('last_seen');
      expect(lastSeen, inInclusiveRange(before, after));
    });

    test('summary: 누적 정답/오답 수가 맞음', () async {
      await stats.recordSubmit(
        levelId: 1,
        seed: 1,
        result:
            _result({'가나': WordOutcome.correct, '다라': WordOutcome.wrong}),
      );
      await stats.recordSubmit(
        levelId: 2,
        seed: 1,
        result: _result({'가나': WordOutcome.wrong, '마바': WordOutcome.correct}),
      );

      final s = await stats.summary();
      expect(s.correct, 2, reason: '가나(1) + 마바(1)');
      expect(s.wrong, 2, reason: '다라(1) + 가나(1)');
      expect(s.words, 3, reason: '가나·다라·마바');
    });

    test('bestScore: 최고 점수 반환, 없으면 null', () async {
      expect(await stats.bestScore(1), isNull);

      // score = correctCount - wrongCount (SubmitResult.score, 01-01 계약)
      await stats.recordSubmit(
        levelId: 1,
        seed: 1,
        result: _result({'가나': WordOutcome.correct, '다라': WordOutcome.correct}),
      ); // score = 2
      await stats.recordSubmit(
        levelId: 1,
        seed: 2,
        result: _result({'가나': WordOutcome.wrong, '다라': WordOutcome.wrong}),
      ); // score = -2

      expect(await stats.bestScore(1), 2);
      expect(await stats.bestScore(2), isNull, reason: '레벨 2로는 제출한 적 없음');
    });

    test('resetAll: word_stat/puzzle_log가 전부 비워짐', () async {
      await stats.recordSubmit(
        levelId: 1,
        seed: 1,
        result: _result({'가나': WordOutcome.correct}),
      );

      await stats.resetAll();

      final n1 = await db
          .customSelect('SELECT COUNT(*) AS n FROM word_stat')
          .getSingle();
      final n2 = await db
          .customSelect('SELECT COUNT(*) AS n FROM puzzle_log')
          .getSingle();
      expect(n1.read<int>('n'), 0);
      expect(n2.read<int>('n'), 0);
    });

    test('트랜잭션 원자성: 중간 실패 시 전부 롤백 (예외 주입)', () async {
      final faultyPath = '${tmp.path}/faulty.sqlite';
      final raw = sqlite3.open(faultyPath);
      raw.execute(schemaSql);
      raw.close();

      final faulty = _FaultyAppDatabase(NativeDatabase(File(faultyPath)));
      addTearDown(faulty.close);
      final faultyStats = StatRepository(faulty);

      faulty.armed = true; // puzzle_log INSERT에서만 던지도록 무장
      await expectLater(
        faultyStats.recordSubmit(
          levelId: 1,
          seed: 1,
          result: _result({'가나': WordOutcome.correct}),
        ),
        throwsException,
      );

      final statCount = await faulty
          .customSelect('SELECT COUNT(*) AS n FROM word_stat')
          .getSingle();
      expect(statCount.read<int>('n'), 0,
          reason: 'word_stat UPSERT가 롤백되지 않았다');

      final logCount = await faulty
          .customSelect('SELECT COUNT(*) AS n FROM puzzle_log')
          .getSingle();
      expect(logCount.read<int>('n'), 0);
    });
  });

  group('복습 루프 통합 테스트 (3단계 DoD 3번)', () {
    late Directory tmp2;
    late AppDatabase db2;
    late DriftWordRepository repo;
    late StatRepository stats2;
    late bool isFixture;

    setUpAll(() async {
      tmp2 = Directory.systemTemp.createTempSync('stat_repository_review_');
      final target = File('${tmp2.path}/words.sqlite');
      await target.writeAsBytes(
        await File('assets/words.sqlite').readAsBytes(),
        flush: true,
      );
      db2 = AppDatabase(NativeDatabase(target));
      repo = DriftWordRepository(db2);
      stats2 = StatRepository(db2);

      // schema_contract_test.dart / word_repository_test.dart와 같은 판정:
      // 현재 커밋된 assets/words.sqlite가 00-01 승인 대기 중 fixtures 샘플이면
      // 데이터 규모를 전제하는 생성이 실패할 수 있다.
      isFixture = false;
      final raw = await db2.metaValue('source_versions');
      if (raw != null) {
        try {
          final parsed = jsonDecode(raw);
          isFixture = parsed is Map && parsed['origin'] == 'fixtures';
        } catch (_) {
          isFixture = false;
        }
      }
    });

    tearDownAll(() async {
      await db2.close();
      if (tmp2.existsSync()) tmp2.deleteSync(recursive: true);
    });

    test('틀린 단어가 다음 생성에서 코어로 우선 선택된다', () async {
      final gen = GridGenerator(repo);
      final spec = levels[0];

      // 1. 퍼즐 생성
      final o1 = await gen.tryGenerate(spec, 1);
      if (isFixture && o1.puzzle == null) {
        // word_repository_test.dart "1단계 생성기 연동"과 같은 사유: 16단어
        // fixtures 샘플로는 levels[0] 채움 할당량을 못 채울 수 있다 — 생성기/
        // 리포지토리 버그가 아니라 데이터 규모 문제다. 00-01 실데이터가 들어오면
        // 이 테스트는 자동으로 하드 검증이 된다.
        markTestSkipped(
          '샘플 빌드(origin=fixtures, 16단어): levels[0] 생성 실패 ― '
          'tools/README.md 02-10, 00-01 참조. failReason=${o1.stats.failReason}',
        );
        return;
      }
      expect(o1.puzzle, isNotNull, reason: o1.stats.failReason);
      final p1 = o1.puzzle!;

      // 2. 일부러 다 틀린 답으로 제출
      final wrong = <(int, int), String>{
        for (final e in Scorer.solutionOf(p1).entries) e.key: '뷁',
      };
      final scored = Scorer.score(p1, wrong, isFirstSubmit: true);
      final recorded = await stats2.recordSubmit(
        levelId: p1.levelId,
        seed: p1.seed,
        result: scored,
      );
      expect(recorded, isTrue, reason: '첫 제출이어야 한다');

      // 3. 틀린 단어들
      final missed = p1.words.map((w) => w.headword).toSet();

      // 4. 같은 티어 코어 후보를 다시 뽑으면 앞쪽에 있어야 한다
      final cands = await repo.coreCandidates(
        tier: spec.coreTier,
        count: 5,
        seed: 1,
      );
      final head = cands.take(10).map((w) => w.headword).toSet();
      expect(head.intersection(missed), isNotEmpty,
          reason: '틀린 단어가 코어 후보 앞쪽에 없음');
    });
  });
}
