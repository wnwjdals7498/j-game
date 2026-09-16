"""02-08 한글 자모 도구 테스트.

케이스는 02-08 "테스트" 절 표의 자모 4종(자모 분해 · 겹받침 판정 · 이중모음 판정 ·
단순 음절)을 그대로 옮긴 것이다.
"""
import pytest

from tools import hangul


# --- 02-08 "테스트" 표: 자모 분해 ---

@pytest.mark.parametrize("ch, expected", [
    ("강", ("ㄱ", "ㅏ", "ㅇ")),
    ("읽", ("ㅇ", "ㅣ", "ㄺ")),
    ("가", ("ㄱ", "ㅏ", "")),       # 종성 없음 -> 빈 문자열
    ("힣", ("ㅎ", "ㅣ", "ㅎ")),     # 완성형 마지막 음절
])
def test_decompose(ch, expected):
    assert hangul.decompose(ch) == expected


@pytest.mark.parametrize("ch", ["A", "1", "ㄱ", "漢", " "])
def test_decompose_rejects_non_syllable(ch):
    """완성형이 아니면 ValueError. 02-08 "막히면": 여기서 try/except 로 덮지 않는다.

    비완성형이 여기까지 왔다면 02-06 의 F1 필터가 안 먹은 것이고, 고칠 곳은 02-06 이다.
    """
    with pytest.raises(ValueError):
        hangul.decompose(ch)


# --- 02-08 "테스트" 표: 겹받침 · 이중모음 · 단순 음절 ---

def test_complex_jong():
    """겹받침 판정: `읽다` 의 `읽`(ㄺ) -> True."""
    assert hangul.decompose("읽")[2] in hangul.COMPLEX_JONG
    assert hangul.has_complex_jamo("읽다") is True


def test_complex_jung():
    """이중모음 판정: `과일` 의 `과`(ㅘ) -> True."""
    assert hangul.decompose("과")[1] in hangul.COMPLEX_JUNG
    assert hangul.has_complex_jamo("과일") is True


def test_simple_syllable():
    """`사과` 의 `사` 는 단순, `과` 는 ㅘ 때문에 복잡 -> 단어 전체는 True.

    02-08 이 "의도한 동작" 이라고 못 박은 케이스다. 이중모음이 너무 흔해 패널티가
    무의미해지면 `hangul.COMPLEX_JUNG` 을 좁히기로 돼 있고(02-08), 그때 이 테스트가 깨진다.
    """
    assert hangul.has_complex_jamo("사") is False
    assert hangul.has_complex_jamo("과") is True
    assert hangul.has_complex_jamo("사과") is True
    assert hangul.has_complex_jamo("나무") is False


def test_jamo_tables_are_complete():
    """초/중/종성 표 길이가 완성형 배치(19 x 21 x 28)와 맞아야 분해가 정확하다."""
    assert (len(hangul.CHO), len(hangul.JUNG), len(hangul.JONG)) == (19, 21, 28)
    assert hangul.COMPLEX_JONG <= set(hangul.JONG)
    assert hangul.COMPLEX_JUNG <= set(hangul.JUNG)


def test_normalization_helpers_moved_here():
    """02-06 이 쓰던 정규화 함수도 여기 있다 (02-08 `hangul.py` 주석).

    `normalize.py` 는 다시 내보내기만 하므로 두 이름이 같은 객체여야 한다.
    """
    from tools import normalize
    assert normalize.normalize_headword is hangul.normalize_headword
    assert normalize.is_all_hangul is hangul.is_all_hangul
    assert hangul.normalize_headword("사과01") == "사과"
