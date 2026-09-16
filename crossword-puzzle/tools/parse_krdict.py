"""기초사전 XML -> build/entries.krdict.jsonl (02-03).

필드 경로는 tools/README.md "실제 파일 구조 조사 결과 → 1. 한국어기초사전" 절 기준.
예문·발음/음성·이미지는 라이선스 비개방(DESIGN 6절)이라 읽지도 저장하지도 않는다.
"""
import xml.etree.ElementTree as ET
from pathlib import Path
from . import config, io_util

OUT = "entries.krdict.jsonl"

ITEM = "item"          # README: 루트 <channel> / 항목 <item>


def _src_files(use_fixtures: bool) -> list[Path]:
    base = config.FIXTURES if use_fixtures else config.RAW
    d = base / "krdict"
    if not d.exists():
        d = base
    return sorted(d.glob("*.xml"))


def iter_entries(path: Path):
    """iterparse 스트리밍. 전체 로드 금지."""
    for ev, el in ET.iterparse(path, events=("end",)):
        if el.tag != ITEM:
            continue
        yield from _parse_item(el)
        el.clear()          # 메모리 해제. 없으면 수백 MB 파일에서 터진다


def _parse_item(el) -> list[dict]:
    raw = (el.findtext("word_info/word") or "").strip()
    if not raw:
        return []
    homonym = (el.findtext("word_info/homonym_num") or "").strip() or None
    pos = (el.findtext("word_info/pos") or "").strip()
    wtype = (el.findtext("word_info/word_unit") or "").strip() or None

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
            "source": "krdict",
            "sense_id": f"krdict:{sid}",
            "raw_headword": raw,
            "homonym": homonym,
            "pos": pos,
            "word_type": wtype,
            "definition": definition,
            "synonyms": [s for s in syns if s],
        })
    return out


def run(use_fixtures: bool = False) -> int:
    files = _src_files(use_fixtures)
    if not files:
        raise FileNotFoundError(
            f"기초사전 XML 없음. tools/raw/krdict/*.xml 확인 (00-01)")

    def rows():
        for f in files:
            yield from iter_entries(f)

    return io_util.write_jsonl(config.BUILD / OUT, rows())
