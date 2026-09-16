/// 격자에 놓을 수 있는 한 단어. 사전 뜻풀이는 여기 없다(3단계 sense에서 붙임).
class WordEntry {
  final String headword; // 표제어. 한글 완성형 2~5음절
  final List<String> syllables; // headword를 음절 단위로 쪼갠 것
  final int tier; // 1(쉬움) .. 7(어려움)
  final String pos; // 품사. 1차는 '명사'

  /// `headword.split('')` 는 Dart에서 UTF-16 코드 유닛으로 쪼갠다.
  /// 한글 완성형(U+AC00~U+D7A3)은 BMP 안이라 1코드유닛 = 1음절이므로 안전하다.
  /// 완성형만 들어온다는 전제는 ETL(02-06)이 보장한다. assert 로 방어만 한다.
  WordEntry({
    required this.headword,
    required this.tier,
    required this.pos,
  }) : syllables = headword.split('') {
    assert(headword.runes.length == headword.length,
        'headword must be BMP-only Hangul: $headword');
    assert(length >= 2 && length <= 5, 'length must be 2..5: $headword');
    assert(tier >= 1 && tier <= 7, 'tier must be 1..7: $tier');
  }

  int get length => syllables.length;

  String syllableAt(int i) => syllables[i];

  @override
  bool operator ==(Object other) =>
      other is WordEntry && other.headword == headword;

  @override
  int get hashCode => headword.hashCode;

  @override
  String toString() => '$headword(t$tier)';
}
