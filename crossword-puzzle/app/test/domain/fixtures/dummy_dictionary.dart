import 'dart:math';

import 'package:jgame/domain/model/word_entry.dart';
import 'package:jgame/domain/repository/word_repository.dart';

/// 메모리 기반 WordRepository. 정렬은 headword 사전순으로 고정(결정성).
class InMemoryWordRepository implements WordRepository {
  final List<WordEntry> _words;
  final Map<String, int> _stats; // headword -> correct - wrong*2

  InMemoryWordRepository(List<WordEntry> words, {Map<String, int>? stats})
      : _words = List.of(words)..sort((a, b) => a.headword.compareTo(b.headword)),
        _stats = stats ?? const {};

  @override
  Future<List<WordEntry>> findByPattern({
    required int length,
    Set<int> tiers = const {},
    Map<int, String> fixed = const {},
    Set<String> exclude = const {},
    int limit = 50,
  }) async {
    final out = <WordEntry>[];
    for (final w in _words) {
      if (w.length != length) continue;
      if (tiers.isNotEmpty && !tiers.contains(w.tier)) continue;
      if (exclude.contains(w.headword)) continue;
      var ok = true;
      for (final e in fixed.entries) {
        if (w.syllableAt(e.key) != e.value) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      out.add(w);
      if (out.length >= limit) break;
    }
    return out;
  }

  @override
  Future<List<WordEntry>> coreCandidates({
    required int tier,
    required int count,
    required int seed,
  }) async {
    final pool = _words.where((w) => w.tier == tier).toList();
    final rnd = Random(seed);
    // 동점 랜덤: 사전순 정렬된 풀을 섞은 뒤 점수로 안정 정렬
    pool.shuffle(rnd);
    pool.sort((a, b) =>
        (_stats[a.headword] ?? 0).compareTo(_stats[b.headword] ?? 0));
    return pool.take(count * 4).toList();
  }
}

/// 합성 더미 사전 생성기.
/// 음절 풀이 좁아 교차가 잘 맞는다. 티어는 피라미드 분포.
List<WordEntry> buildDummyDictionary({int seed = 1, int target = 4000}) {
  const pool = [
    '가', '나', '다', '라', '마', '바', '사', '아', '자', '차', //
    '카', '타', '파', '하', '고', '노', '도', '로', '모', '보', //
    '소', '오', '조', '초', '기', '니', '디', '리', '미', '비', //
    '시', '이', '지', '치', '구', '누', '두', '루', '무', '부', //
  ];
  const tierRatio = [25, 22, 18, 14, 10, 7, 4]; // 02-08과 같은 피라미드
  final rnd = Random(seed);
  final seen = <String>{};
  final out = <WordEntry>[];

  while (out.length < target) {
    final len = 2 + rnd.nextInt(4); // 2..5
    final buf = StringBuffer();
    for (var i = 0; i < len; i++) {
      buf.write(pool[rnd.nextInt(pool.length)]);
    }
    final hw = buf.toString();
    if (!seen.add(hw)) continue;

    var roll = rnd.nextInt(100);
    var tier = 1;
    for (var t = 0; t < tierRatio.length; t++) {
      if (roll < tierRatio[t]) {
        tier = t + 1;
        break;
      }
      roll -= tierRatio[t];
      tier = t + 2;
    }
    if (tier > 7) tier = 7;

    out.add(WordEntry(headword: hw, tier: tier, pos: '명사'));
  }
  return out;
}
