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

# 용량 컷: score 오름차순(=쉬운 순) 상위 MAX_WORDS 개만 남기고 tier를 다시 매긴다.
# 02-01 실데이터 첫 실행(2026-09-17)에서 02-06 필터를 통과한 표제어가 88,957개였는데,
# DEFINITION_MAX_CHARS 는 이 규모에서 거의 효과가 없었다(30~80자 전부 시도해도 33.6MB가
# 32.9~34.6MB 사이만 오갔다 — 평균 뜻풀이 길이가 32자라 컷에 거의 안 걸린다. 88,957행이
# word/sense/word_char 세 테이블과 5개 cN 인덱스에 고르게 곱해지는 게 진짜 원인이다).
# word_char 제거(02-09 "막히면" ②)도 24.6MB까지만 줄고(9MB 절감), 그마저 03-01
# app_database.dart의 WordChars 테이블·schema_contract_test.dart를 함께 고쳐야 해서
# 이번 재적재 범위를 벗어난다(이 환경엔 Flutter/Dart 툴체인이 없어 고쳐도 검증 불가).
# 그래서 tools/README.md가 미해결 항목 2로 남겨 둔 두 번째 대안 "티어 상위 N개만
# 담기"를 택했다. score.py가 scored 전체를 score 오름차순 정렬한 뒤 이 값으로 자르고
# 그 부분집합에 대해서만 tier를 다시 매긴다 — 배점 산식·TIER_RATIO는 그대로다.
# 실측(2026-09-17, 임시 build 디렉터리에서 이분 탐색): 26,000개 -> 9.35MB
# (27,000개는 9.74MB로 더 타이트하다. 다음 6개월 주기 갱신에서 데이터가 조금만 늘어도
# 10MB를 다시 넘을 수 있어 26,000으로 여유를 남겼다). fixtures 빌드는 애초에 수십 행이라
# 이 컷에 걸리지 않는다.
MAX_WORDS = 26000

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

# REPO/MIN_APP_VERSION(갱신 배포처)은 여기 두지 않는다 — tools/release_db.py는
# `python tools/release_db.py`로 직접 실행되는 독립 스크립트라 tools 패키지를
# import할 수 없다(파이프라인 모듈들과 다름). 그 스크립트 안에 자체 상수로 둔다.

assert sum(TIER_RATIO) == 100, "TIER_RATIO must sum to 100"
assert len(TIER_RATIO) == TIER_COUNT
