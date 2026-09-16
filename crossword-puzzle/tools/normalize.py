"""표제어 정규화·필터 -> build/normalized.jsonl (02-06).

`entries.krdict.jsonl` + `entries.stdict.jsonl` 에서 **격자에 쓸 수 있는 형태만** 남긴다.
규칙은 02-06 문서 "규칙 (확정)" 절이 정한 것이고, 여기서 그대로 구현한다.

정규화는 **버리기 전에 고칠 수 있는 것만** 고친다 (NFC · 앞뒤 공백 · 동형어 번호 · 첨자).
띄어쓰기/`^`/하이픈은 고치지 않는다 — 그건 다른 단어로 바꾸는 것이라 그냥 버린다 (F1).
"""
import re
import unicodedata
from collections import Counter

from . import config, io_util

OUT = "normalized.jsonl"
IN = ["entries.krdict.jsonl", "entries.stdict.jsonl"]

# 동형어 번호는 표제어 끝의 숫자다 (`가다01` -> `가다`). 02-03/02-04 의 `homonym` 필드가
# 동형어의 정체를 말해 주는 정본이고, 여기서는 **표제어에 붙어 있을 때만** 잘라낸다 (02-06).
# `4H`, `3D` 같은 표제어는 어차피 F1(완성형 검사)에서 탈락한다.
_HOMONYM = re.compile(r"\d+$")
_SUPERSCRIPT = str.maketrans("", "", "¹²³⁴⁵⁶⁷⁸⁹⁰")

# 로그 라벨. 코드(F1~F5)는 02-06 문서·README·테스트가 그대로 쓰는 이름이라 바꾸지 않는다.
REASONS = {
    "F1": "비한글/기호",
    "F2": "길이",
    "F3": "품사",
    "F4": "어휘유형",
    "F5": "고유명사",
}


def _pad(label: str, width: int = 14) -> str:
    """한글은 콘솔에서 두 칸을 먹는다. 사유별 개수를 세로로 비교하려면 표시폭으로 맞춰야 한다."""
    w = sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in label)
    return label + " " * max(0, width - w)


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


def check(entry: dict) -> str | None:
    """통과하면 None, 탈락하면 사유 코드.

    F1 이 F2 보다 먼저다 — 비한글이 섞이면 길이 개념이 무의미하다 (02-06).
    """
    hw = entry["headword"]
    if not is_all_hangul(hw):
        return "F1"
    if not (config.MIN_LEN <= len(hw) <= config.MAX_LEN):
        return "F2"
    # F5 를 F3 보다 먼저 본다. 02-06 골격의 순서(F3 -> F5)로는 `ALLOWED_POS = {"명사"}` 이므로
    # `pos == "고유명사"` 가 F3 에서 먼저 잡혀 F5 가 영영 도달 불가가 되고,
    # 같은 문서의 필터 테스트 표가 요구하는 ("서울", "고유명사") -> "F5" 가 깨진다.
    # 탈락 여부는 어느 쪽이든 같지만, 02-06 3절이 **사유별 개수**로 필터 완화를 판단하라고
    # 했으므로 고유명사는 품사 통계에 섞이면 안 된다.
    if config.EXCLUDE_PROPER_NOUN and entry.get("pos") == "고유명사":
        return "F5"
    if entry.get("pos") not in config.ALLOWED_POS:
        return "F3"
    if entry.get("word_type") in config.EXCLUDE_WORD_TYPES:
        return "F4"
    return None


def run(use_fixtures: bool = False) -> int:
    stats = Counter()

    def rows():
        for name in IN:
            p = config.BUILD / name
            if not p.exists():
                continue        # 표준(02-04)이 없을 수 있다. 건너뛰고 계속한다
            for e in io_util.read_jsonl(p):
                stats["in"] += 1
                hw = normalize_headword(e["raw_headword"])
                cand = {**e, "headword": hw}
                why = check(cand)
                if why:
                    stats[why] += 1
                    continue
                stats["out"] += 1
                yield {
                    "source": cand["source"],
                    "sense_id": cand["sense_id"],
                    "headword": hw,
                    "raw_headword": e["raw_headword"],
                    "len": len(hw),
                    "syllables": list(hw),
                    "pos": cand["pos"],
                    "definition": cand["definition"],
                    "synonyms": cand.get("synonyms", []),
                }

    n = io_util.write_jsonl(config.BUILD / OUT, rows())
    print(f"    normalize: 입력 {stats['in']:,} → 통과 {stats['out']:,}")
    for code, label in REASONS.items():
        print(f"      {code} {_pad(label)}{stats[code]:>8,}")
    if not stats["F5"]:
        # 02-06 "고유명사 판정": 판정 근거가 없으면 그 사실을 로그와 README 에 남긴다.
        # 입력에 고유명사 표시가 실려 오지 않으면 F5 는 한 건도 못 잡는다 — 0 이 그 신호다.
        # 콘솔이 cp949 일 수 있으므로 em dash 같은 비 cp949 문자는 쓰지 않는다.
        print("      F5 경고: 고유명사 탈락 0건. 입력에 판정 근거가 실려 있는지 확인할 것"
              " (tools/README.md '미해결', 02-10 눈 검수)")
    return n
