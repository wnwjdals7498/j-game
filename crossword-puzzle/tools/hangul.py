"""한글 음절 도구 (02-08).

02-08 이 "`tools/hangul.py` (02-06/02-07이 쓰는 정규화 함수도 여기로 모은다)" 라고 정한
대로, 자모 분해·복잡 자모 판정과 **02-06 의 표제어 정규화·완성형 검사**를 한곳에 모은다.
`normalize.py` 는 여기서 다시 내보내기만 한다 (02-06 의 공개 이름은 그대로 유지).

`decompose` 는 완성형이 아니면 **예외를 던진다**. 02-08 "막히면" 이 정한 대로
여기서 try/except 로 덮지 않는다 — 비완성형이 여기까지 왔다면 02-06 의 F1 필터가
안 먹은 것이고, 고칠 곳은 02-06 이다.
"""
import re
import unicodedata

from . import config

CHO = ["ㄱ", "ㄲ", "ㄴ", "ㄷ", "ㄸ", "ㄹ", "ㅁ", "ㅂ", "ㅃ", "ㅅ", "ㅆ", "ㅇ",
       "ㅈ", "ㅉ", "ㅊ", "ㅋ", "ㅌ", "ㅍ", "ㅎ"]
JUNG = ["ㅏ", "ㅐ", "ㅑ", "ㅒ", "ㅓ", "ㅔ", "ㅕ", "ㅖ", "ㅗ", "ㅘ", "ㅙ", "ㅚ",
        "ㅛ", "ㅜ", "ㅝ", "ㅞ", "ㅟ", "ㅠ", "ㅡ", "ㅢ", "ㅣ"]
JONG = ["", "ㄱ", "ㄲ", "ㄳ", "ㄴ", "ㄵ", "ㄶ", "ㄷ", "ㄹ", "ㄺ", "ㄻ", "ㄼ", "ㄽ",
        "ㄾ", "ㄿ", "ㅀ", "ㅁ", "ㅂ", "ㅄ", "ㅅ", "ㅆ", "ㅇ", "ㅈ", "ㅊ", "ㅋ",
        "ㅌ", "ㅍ", "ㅎ"]

COMPLEX_JONG = {"ㄳ", "ㄵ", "ㄶ", "ㄺ", "ㄻ", "ㄼ", "ㄽ", "ㄾ", "ㄿ", "ㅀ", "ㅄ"}  # 겹받침
# 이중모음. 02-08 이 준 초안 그대로 쓴다 (`ㅒ`·`ㅖ` 포함).
# 좁힐지 여부(`{"ㅙ","ㅚ","ㅞ","ㅟ","ㅢ"}`)는 02-10 눈 검수 결과를 보고 결정한다.
# 02-08 "테스트" 표가 `사과` 의 `과`(ㅘ) 를 True 로 못 박았으므로 지금 좁히면 계약이 깨진다.
# 바꾸려면 여기에 결정을 주석으로 남길 것 (02-08: 이건 config 값이 아니다).
COMPLEX_JUNG = {"ㅘ", "ㅙ", "ㅚ", "ㅝ", "ㅞ", "ㅟ", "ㅢ", "ㅒ", "ㅖ"}

# 완성형 음절 개수 - 1. 0xD7A3 - 0xAC00 == 11171
_LAST_CODE = config.HANGUL_END - config.HANGUL_START

# --- 02-06 정규화 (여기로 모음) ---
# 동형어 번호는 표제어 끝의 숫자다 (`가다01` -> `가다`). 02-03/02-04 의 `homonym` 필드가
# 동형어의 정체를 말해 주는 정본이고, 여기서는 **표제어에 붙어 있을 때만** 잘라낸다 (02-06).
_HOMONYM = re.compile(r"\d+$")
_SUPERSCRIPT = str.maketrans("", "", "¹²³⁴⁵⁶⁷⁸⁹⁰")


def normalize_headword(raw: str) -> str:
    """NFC -> 앞뒤 공백 -> 첨자 제거 -> 동형어 번호 제거.

    첨자를 동형어 번호보다 먼저 지운다. `¹` 은 유니코드 No 범주라 `\\d` 에 걸리지 않아
    순서를 바꾸면 `가다¹` 이 안 고쳐진다.
    """
    s = unicodedata.normalize("NFC", raw).strip()
    s = s.translate(_SUPERSCRIPT)
    s = _HOMONYM.sub("", s)
    return s.strip()


def is_hangul_syllable(ch: str) -> bool:
    return config.HANGUL_START <= ord(ch) <= config.HANGUL_END


def is_all_hangul(s: str) -> bool:
    return bool(s) and all(is_hangul_syllable(c) for c in s)


# --- 02-08 자모 ---

def decompose(ch: str) -> tuple[str, str, str]:
    """완성형 음절 -> (초성, 중성, 종성). 종성이 없으면 빈 문자열."""
    code = ord(ch) - config.HANGUL_START
    if not (0 <= code <= _LAST_CODE):
        raise ValueError(f"완성형 아님: {ch}")
    return CHO[code // 588], JUNG[(code % 588) // 28], JONG[code % 28]


def has_complex_jamo(word: str) -> bool:
    """겹받침이나 이중모음이 하나라도 있으면 True (02-08 점수 패널티)."""
    for ch in word:
        _, jung, jong = decompose(ch)
        if jong in COMPLEX_JONG or jung in COMPLEX_JUNG:
            return True
    return False
