"""ETL 설정값. 조정은 전부 여기서."""
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "tools" / "raw"
BUILD = ROOT / "tools" / "build"
FIXTURES = ROOT / "tools" / "fixtures"
APP_ASSETS = ROOT / "app" / "assets"

# --- 표제어 필터 (02-06) ---
MIN_LEN = 2               # 1음절 제외: 격자 교차 불가
MAX_LEN = 5               # 6음절 이상 제외: 격자에 안 들어감
HANGUL_START = 0xAC00     # 완성형 범위
HANGUL_END = 0xD7A3
ALLOWED_POS = {"명사"}    # 1차 범위. 02-01 실데이터 조사(2026-09-17)로 재확인된 값
# "문법‧표현"의 가운뎃점은 U+2027(HYPHENATION POINT)이다. 흔한 가운뎃점(U+00B7)이 아니므로
# 문자열을 새로 칠 때 실수하기 쉽다 — 02-01에서 실제 JSON 값을 그대로 복사해 왔다.
EXCLUDE_WORD_TYPES = {"구", "속담", "관용구", "문법‧표현"}
EXCLUDE_PROPER_NOUN = True

# --- 뜻풀이 (02-03, 02-09) ---
DEFINITION_MAX_CHARS = 80   # 용량 목표 10MB의 주 조절 손잡이
SENSES_PER_WORD = 1         # 앱에 넣는 뜻풀이 개수

# --- 난이도 (02-08) ---
TIER_COUNT = 7
TIER_RATIO = [25, 22, 18, 14, 10, 7, 4]   # 합 100. 피라미드. 등분위 금지
ADJ_VOCAB = {"A": -0.15, "B": -0.10, "C": -0.05}
ADJ_IN_KRDICT = -0.10
ADJ_PER_EXTRA_SYLLABLE = 0.03    # (음절수 - 2) 배
ADJ_COMPLEX_JAMO = 0.05
NO_FREQ_BASE = 1.0               # 빈도 정보 없음 = 가장 어려움

# --- 출처 비트 (02-09 schema) ---
SRC_KRDICT = 1
SRC_STDICT = 2

# --- 산출물 검사 (02-10 `python -m tools check` 표) ---
CHECK_MIN_WORDS = 1000            # 이보다 적으면 게임에 쓸 수 없다
CHECK_TIER_TOLERANCE_PP = 2       # 티어 실제 비율과 TIER_RATIO 의 허용 오차 (%p)
CHECK_MIN_FREQ_MATCH_PCT = 30     # 빈도 매칭률 기준 (리포트 요약의 판정)

# --- 메타 ---
SCHEMA_VERSION = 1
DB_VERSION = 1        # 갱신할 때마다 +1 (05-01 manifest 비교 키)

assert sum(TIER_RATIO) == 100, "TIER_RATIO must sum to 100"
assert len(TIER_RATIO) == TIER_COUNT
