// DriftWordRepository(03-03) 테스트. 실 `assets/words.sqlite` 를 쓴다.
//
// `word_stat` 갱신 테스트(coreCandidates 통계 순)가 있어 원본 asset을 그대로
// 열지 않고 임시 디렉터리로 복사한 사본을 연다 — bootstrap_test.dart(03-02)와
// 같은 이유다. 원본 `assets/words.sqlite` 는 커밋된 파일이라 건드리면 안 된다
// (schema_contract_test.dart가 "word_stat은 비어 있다"를 검증한다).
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:jgame/data/db/app_database.dart';
import 'package:jgame/data/drift_word_repository.dart';
import 'package:jgame/domain/generator/grid.dart';
import 'package:jgame/domain/generator/grid_generator.dart';
import 'package:jgame/domain/generator/grid_rules.dart';
import 'package:jgame/domain/levels.dart';
import 'package:jgame/domain/model/puzzle.dart';
import 'package:test/test.dart';

/// [GridRules.validate] 는 [MutableGrid] 를 받는다. 완성된 [Puzzle] 을 검증하려면
/// 단어 목록만으로 격자를 되돌린다 (grid_generator_test.dart의 `regrid`와 동일 패턴).
MutableGrid regrid(Puzzle p) {
  final g = MutableGrid(p.width, p.height);
  for (final w in p.words) {
    g.place(w);
  }
  return g;
}

void main() {
  late Directory tmp;
  late AppDatabase db;
  late DriftWordRepository repo;
  late bool isFixture;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('word_repository_test_');
    final target = File('${tmp.path}/words.sqlite');
    await target.writeAsBytes(
      await File('assets/words.sqlite').readAsBytes(),
      flush: true,
    );
    db = AppDatabase(NativeDatabase(target));
    repo = DriftWordRepository(db);

    // schema_contract_test.dart와 같은 판정: 현재 커밋된 DB가 00-01 승인 대기 중
    // tools/fixtures/ 샘플(16단어)이면 실데이터 규모를 전제하는 검증은 못 돈다.
    isFixture = false;
    final raw = await db.metaValue('source_versions');
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
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('findByPattern', () {
    test('길이 필터: 반환 전부 length == 요청', () async {
      final r = await repo.findByPattern(length: 2, limit: 50);
      expect(r, isNotEmpty);
      for (final w in r) {
        expect(w.length, 2, reason: w.headword);
      }
    });

    test('티어 필터: 반환 전부 요청 티어 안', () async {
      final r = await repo.findByPattern(length: 2, tiers: {1, 2}, limit: 50);
      expect(r, isNotEmpty);
      for (final w in r) {
        expect(w.tier, anyOf(1, 2), reason: w.headword);
      }
    });

    test('fixed 자리 정확: 모든 결과의 syllableAt(fixed key) == fixed value', () async {
      final r = await repo.findByPattern(length: 2, fixed: {0: '사'}, limit: 50);
      expect(r, isNotEmpty);
      for (final w in r) {
        expect(w.length, 2, reason: w.headword);
        expect(w.syllableAt(0), '사', reason: w.headword);
      }
      expect(r.map((w) => w.headword).toSet(), {'사과', '사람'});
    });

    test('fixed 여러 자리: 2자리 고정도 정확', () async {
      final r = await repo.findByPattern(
        length: 3,
        fixed: {0: '도', 2: '관'},
        limit: 50,
      );
      expect(r.map((w) => w.headword).toList(), ['도서관']);
      expect(r.single.syllableAt(0), '도');
      expect(r.single.syllableAt(2), '관');
    });

    test('fixed off-by-one 회귀: 0-based key가 1-based cN으로 정확히 변환됨', () async {
      // '어머니' = 어(0)머(1)니(2). key=2가 c3(마지막 음절)을 가리켜야 한다.
      // off-by-one으로 c2를 짚으면 '머'를 찾게 되어 이 질의가 빈 리스트를 낸다.
      final r = await repo.findByPattern(
        length: 3,
        fixed: {2: '니'},
        limit: 50,
      );
      expect(r.map((w) => w.headword), contains('어머니'));
      for (final w in r) {
        expect(w.syllableAt(2), '니', reason: w.headword);
      }
    });

    test('exclude: 제외 단어가 결과에 없음', () async {
      final r = await repo.findByPattern(
        length: 2,
        fixed: {0: '사'},
        exclude: {'사과'},
        limit: 50,
      );
      expect(r.map((w) => w.headword).toList(), ['사람']);
    });

    test('exclude 후에도 limit 충족', () async {
      // length=2 후보 9개 중 1개를 제외해도 limit=3을 채울 여유가 있다.
      final r = await repo.findByPattern(
        length: 2,
        exclude: {'구름'},
        limit: 3,
      );
      expect(r.length, 3);
      expect(r.map((w) => w.headword), isNot(contains('구름')));
    });

    test('limit 준수: 결과 개수가 limit 이하', () async {
      final r = await repo.findByPattern(length: 2, limit: 3);
      expect(r.length, 3);
    });

    test('결정성: 같은 인자 두 번 → 같은 순서', () async {
      final a = await repo.findByPattern(length: 2, tiers: {2, 1});
      final b = await repo.findByPattern(length: 2, tiers: {1, 2});
      expect(a.map((w) => w.headword).toList(), b.map((w) => w.headword).toList());
    });

    test('빈 결과: 존재하지 않는 패턴 → 빈 리스트 (예외 아님)', () async {
      final r = await repo.findByPattern(length: 4, fixed: {0: '좀'});
      expect(r, isEmpty);
    });
  });

  group('coreCandidates', () {
    test('전부 요청 티어', () async {
      final r = await repo.coreCandidates(tier: 2, count: 2, seed: 1);
      expect(r, isNotEmpty);
      for (final w in r) {
        expect(w.tier, 2, reason: w.headword);
      }
    });

    test('개수 >= count (가능하면)', () async {
      final r = await repo.coreCandidates(tier: 2, count: 2, seed: 1);
      expect(r.length, greaterThanOrEqualTo(2));
    });

    test('통계 순: stat을 심으면 점수 낮은 단어가 앞', () async {
      // '바다'에 오답을 심어 score = 0 - 5*2 = -10 (다른 tier2 단어는 콜드 0점).
      await db.customStatement(
        "INSERT INTO word_stat(headword, correct, wrong) VALUES ('바다', 0, 5)",
      );
      addTearDown(() => db.customStatement(
          "DELETE FROM word_stat WHERE headword = '바다'"));

      final r = await repo.coreCandidates(tier: 2, count: 2, seed: 99);
      expect(r.first.headword, '바다');
    });

    test('결정성: 같은 seed 두 번 → 같은 순서', () async {
      final a = await repo.coreCandidates(tier: 1, count: 2, seed: 7);
      final b = await repo.coreCandidates(tier: 1, count: 2, seed: 7);
      expect(a.map((w) => w.headword).toList(), b.map((w) => w.headword).toList());
    });
  });

  test('인덱스 사용: explainPattern 결과에 idx_word_c 포함', () async {
    final plan = await repo.explainPattern();
    expect(
      plan.any((line) => line.contains('idx_word_c')),
      isTrue,
      reason: '인덱스 미사용: $plan',
    );
  });

  test('1단계 생성기 연동: 실 DB로 퍼즐이 생성된다', () async {
    final gen = GridGenerator(repo);
    final spec = levels[0];
    final o = await gen.tryGenerate(spec, 1);

    if (isFixture) {
      // 현재 커밋된 assets/words.sqlite는 00-01(실사전 데이터) 승인 대기 중
      // tools/fixtures/ 샘플 16단어뿐이다. levels[0]의 채움 할당량(티어1 최소
      // 2개, 서로 다른 표제어)을 만족하려면 코어(티어2) 후보와 음절을 공유하는
      // 서로 다른 티어1 단어가 2개 이상 있어야 하는데, 이 샘플에는 '사과'-'사람'
      // 교차 하나뿐이다 — 데이터가 없어서 생기는 구조적 한계지 생성기/리포지토리
      // 버그가 아니다. 실데이터가 들어오면(00-01) 이 테스트는 자동으로 하드
      // 검증으로 바뀐다(스킵 없이 통과해야 함).
      if (o.puzzle == null) {
        markTestSkipped(
          '샘플 빌드(origin=fixtures, 16단어): levels[0] 채움 할당량을 채울 만큼 '
          '티어1↔티어2 교차 단어가 없다 ― tools/README.md 02-10, 00-01 참조. '
          'failReason=${o.stats.failReason}',
        );
        return;
      }
    }

    expect(o.puzzle, isNotNull, reason: o.stats.failReason);
    final p = o.puzzle!;
    expect(GridRules.validate(regrid(p), allowIsolated: spec.allowIsolated), isEmpty);
  });
}
