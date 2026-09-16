"""표제어 기준 결합 -> build/merged.jsonl (02-07).

`normalized.jsonl` 의 뜻풀이 행들을 **표제어 문자열 하나에 `word` 1행 + `sense` 여러 행**으로
묶고, `freq.jsonl`(순위)·`vocab.jsonl`(등급)을 붙인다.
DESIGN 4절의 "게임이 쓰는 것과 사전이 주는 것을 분리" 를 여기서 실현한다.
규칙은 02-07 "결합 규칙" 표가 정한 것이고, 여기서 그대로 구현한다.

`senses` 는 `config.SENSES_PER_WORD` 개로 잘린다 (DESIGN 6절 용량).
**버리기 전에 유의어만 모아 둔다** — 2번 뜻풀이에만 유의어가 있는 경우가 흔하다 (02-07).
"""
from collections import Counter, defaultdict

from . import config, io_util

OUT = "merged.jsonl"
IN = "normalized.jsonl"

# 02-07 "막히면" 이 정한 판단 기준. 밑돌면 경고 한 줄을 찍는다 (조용히 넘어가지 않는다).
MIN_FREQ_MATCH = 0.30
MIN_VOCAB_MATCH = 0.05


def _load_index(name: str, key: str, val: str) -> dict:
    """보조 입력(freq/vocab)을 `{표제어: 값}` 으로 읽는다. 파일이 없으면 빈 dict.

    빈도·어휘 등급은 **없어도 되는** 정보다 — 02-07 결합 규칙 표가 "없으면 `null`" 이라
    정했고 02-08 이 `NO_FREQ_BASE` 로 처리한다. 그래서 여기서 예외를 던지지 않는다.
    """
    p = config.BUILD / name
    if not p.exists():
        return {}
    return {r[key]: r[val] for r in io_util.read_jsonl(p)}


def _src_bit(source: str) -> int:
    return config.SRC_KRDICT if source == "krdict" else config.SRC_STDICT


def _sense_order(e: dict) -> tuple:
    """기초 우선(02-07 "기초 vs 표준"). 같은 출처면 `sense_id` 로 안정 정렬.

    `sense_id` 까지 보는 이유는 **재현성**이다 — 같은 입력이면 같은 파일 바이트가 나와야
    `words.sqlite` 의 sha256(05-01)이 안정적이다.
    """
    return (0 if e["source"] == "krdict" else 1, e["sense_id"])


def _pct(part: int, whole: int) -> str:
    return f"{(100.0 * part / whole) if whole else 0.0:.1f}%"


def run(use_fixtures: bool = False) -> int:
    freq = _load_index("freq.jsonl", "headword", "rank")
    vocab = _load_index("vocab.jsonl", "headword", "grade")

    by_word: dict[str, list] = defaultdict(list)
    for e in io_util.read_jsonl(config.BUILD / IN):
        by_word[e["headword"]].append(e)

    stats: Counter[str] = Counter()

    def rows():
        # sorted() 로 순회한다 — dict 순회 순서에 기대면 파이썬 버전·삽입 순서에 따라
        # 출력 바이트가 달라져 05-01 의 sha256 비교가 깨진다 (02-07 "정렬을 ... 하는 이유").
        for hw, entries in sorted(by_word.items()):
            entries.sort(key=_sense_order)
            head = entries[0]

            src_bits = 0
            for e in entries:
                src_bits |= _src_bit(e["source"])

            # 유의어는 용량 때문에 버려지는 sense 에서도 긁어모은다 (02-07).
            syns, seen = [], set()
            for e in entries:
                for s in e.get("synonyms", []):
                    if s and s not in seen:
                        seen.add(s)
                        syns.append(s)

            kept = entries[: config.SENSES_PER_WORD]
            senses = [{
                "sense_id": e["sense_id"],
                "definition": e["definition"],
                "synonyms": syns if i == 0 else [],
                "source": _src_bit(e["source"]),
            } for i, e in enumerate(kept)]

            rank, grade = freq.get(hw), vocab.get(hw)
            stats["freq"] += rank is not None
            stats["vocab"] += grade is not None
            stats[{config.SRC_KRDICT: "krdict_only",
                   config.SRC_STDICT: "stdict_only"}.get(src_bits, "both")] += 1

            yield {
                "headword": hw,
                "len": head["len"],
                "syllables": head["syllables"],
                "pos": head["pos"],
                "source": src_bits,
                "freq_rank": rank,
                "vocab_grade": grade,
                "in_krdict": bool(src_bits & config.SRC_KRDICT),
                "senses": senses,
            }

    n = io_util.write_jsonl(config.BUILD / OUT, rows())

    print(f"    merge: {n:,} words")
    print(f"      빈도 매칭 {stats['freq']:>8,} ({_pct(stats['freq'], n)})")
    print(f"      등급 매칭 {stats['vocab']:>8,} ({_pct(stats['vocab'], n)})")
    print(f"      기초사전만 {stats['krdict_only']:,}"
          f" / 표준만 {stats['stdict_only']:,} / 양쪽 {stats['both']:,}")
    # 콘솔이 cp949 일 수 있으므로 em dash 같은 비 cp949 문자는 쓰지 않는다.
    if n and stats["freq"] < n * MIN_FREQ_MATCH:
        print("      경고: 빈도 매칭률 30% 미만. 빈도 파일 표제어에 품사 태그나 동형어 번호가"
              " 붙어 있다 (02-07 '막히면' -> 02-05 에서 표제어 정규화 후 재결합)")
    if n and stats["vocab"] < n * MIN_VOCAB_MATCH:
        print("      경고: 등급 매칭률 5% 미만. 10% 안팎이 정상이다."
              " 1% 미만이면 어휘 파일이 잘못된 것 (02-07 '막히면')")
    return n
