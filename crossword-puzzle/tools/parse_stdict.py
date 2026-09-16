"""표준국어대사전 XML -> build/entries.stdict.jsonl (02-04).

출력 스키마는 02-03(기초사전)과 완전히 같다. `source` 와 `sense_id` 접두어만 다르다.
필드 경로는 tools/README.md "실제 파일 구조 조사 결과 -> 2. 표준국어대사전" 절 기준.
예문·발음/음성·이미지는 라이선스 비개방(DESIGN 6절)이라 읽지도 저장하지도 않는다.

표준은 DESIGN 2절상 "보충" 자료다. 원본이 없어도 빈 파일을 내고 파이프라인은 계속 돈다.
"""
import xml.etree.ElementTree as ET
from pathlib import Path
from . import config, io_util

OUT = "entries.stdict.jsonl"

ITEM = "item"          # README: 루트 <channel> / 항목 <item>

# 02-04 "표준 고유 필터" 표. 옛말·북한어는 한 칸(drop_old)으로 센다.
DROP_WORD_TYPES = {"방언", "옛말", "북한어"}
DROP_WORD_UNITS = {"구", "속담", "관용구"}

# 전문어(cat_info)는 아직 거르지 않는다 — 02-04 "막히면": 일단 약하게 걸고
# 02-10 눈 검수 · 03-05 실패율을 보고 조인다. 처음부터 세게 걸면 되돌리기 어렵다.
# "채움 풀이 남아돈다"로 판정되면 여기를 True 로 바꾸는 게 첫 번째 손잡이다.
DROP_TECHNICAL = False


def _src_files(use_fixtures: bool) -> list[Path]:
    base = config.FIXTURES if use_fixtures else config.RAW
    d = base / "stdict"
    if not d.exists():
        d = base
    return sorted(d.glob("*.xml"))


def _new_stats() -> dict:
    # total/drop_* 는 <item> 개수, kept 는 출력 행 수(뜻풀이 개수)다.
    return {"total": 0, "kept": 0, "drop_dialect": 0, "drop_old": 0,
            "drop_technical": 0, "drop_phrase": 0}


def iter_entries(path: Path, stats: dict):
    """iterparse 스트리밍. 수백 MB 파일이라 전체 로드 금지."""
    for ev, el in ET.iterparse(path, events=("end",)):
        if el.tag != ITEM:
            continue
        stats["total"] += 1
        yield from _parse_item(el, stats)
        el.clear()          # 메모리 해제. 없으면 수백 MB 파일에서 터진다


def _drop_reason(el, word_type: str, word_unit: str | None) -> str | None:
    if word_type == "방언" or el.find("word_info/dialect_info") is not None:
        return "drop_dialect"
    if word_type in DROP_WORD_TYPES:            # 옛말·북한어
        return "drop_old"
    if DROP_TECHNICAL and el.find("word_info/cat_info") is not None:
        return "drop_technical"
    if word_unit in DROP_WORD_UNITS:
        return "drop_phrase"
    return None


def _parse_item(el, stats: dict) -> list[dict]:
    raw = (el.findtext("word_info/word") or "").strip()
    if not raw:
        return []
    # 표제어의 `^`(띄어쓰기 표시)·`-`(접사)·동형어 번호는 여기서 고치지 않는다. 판정은 02-06.
    src_word_type = (el.findtext("word_info/word_type") or "").strip()
    word_unit = (el.findtext("word_info/word_unit") or "").strip() or None

    reason = _drop_reason(el, src_word_type, word_unit)
    if reason:
        stats[reason] += 1
        return []

    homonym = (el.findtext("word_info/homonym_num") or "").strip() or None
    pos = (el.findtext("word_info/pos") or "").strip()

    out = []
    for sense in el.findall("word_info/pos_info/comm_pattern_info/sense_info"):
        sid = (sense.findtext("sense_code") or "").strip()
        definition = (sense.findtext("definition") or "").strip()
        if not sid or not definition:
            continue
        syns = [
            (r.findtext("word") or "").strip()
            for r in sense.findall("rel_info")
            if (r.findtext("type") or "").strip() == "비슷한말"
        ]
        out.append({
            "source": "stdict",
            "sense_id": f"stdict:{sid}",
            "raw_headword": raw,
            "homonym": homonym,
            "pos": pos,
            "word_type": word_unit,
            "definition": definition,
            "synonyms": [s for s in syns if s],
        })
    return out


def run(use_fixtures: bool = False) -> int:
    files = _src_files(use_fixtures)
    stats = _new_stats()
    if not files:
        # 표준은 선택 자료다. 없으면 빈 파일을 내고 경고만 남긴다 (02-04, 00-01 "막히면").
        print("    stdict: 원본 없음 -> 빈 파일 생성 (기초사전만으로 진행)")
        return io_util.write_jsonl(config.BUILD / OUT, [])

    def rows():
        for f in files:
            yield from iter_entries(f, stats)

    stats["kept"] = io_util.write_jsonl(config.BUILD / OUT, rows())
    print(f"    stdict: {stats}")
    return stats["kept"]
