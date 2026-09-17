"""기초사전 JSON -> build/entries.krdict.jsonl (02-03).

02-01 재조사(2026-09-17) 결과 원본은 XML 이 아니라 JSON 이다 (00-01 예상과 다름).
구조는 LMF 스타일 att/val: `{"LexicalResource": {"Lexicon": {"LexicalEntry": [...]}}}`.
표제어는 `LexicalEntry.Lemma.feat[att=writtenForm]`, 동형어 번호·품사·어휘단위는
`LexicalEntry.feat[]` 안에 `att`/`val` 쌍으로 따로 있다. 카디널리티가 1개면 dict, 여러개면
list 로 오가므로(Lemma/feat/Sense/SenseRelation 전부 그렇다) `_as_list` 로 통일해 다룬다.
자세한 경로는 tools/README.md "실제 파일 구조 조사 결과 -> 1. 한국어기초사전" 참조.

파일당 최대 ~99MB 라 파일 하나씩 `json.load` 로 통째로 읽고 처리한다 — 스트리밍(iterparse)은
필요 없다(02-01 "대용량 실파일은 파일 하나씩 열고 처리하는 방식으로 충분하다").

예문(SenseExample)·발음/음성(WordForm)·이미지(Multimedia)는 라이선스 비개방(DESIGN 6절)이라
읽지도 저장하지도 않는다 — 애초에 아래 코드가 그 키를 참조하지 않는다.
"""
import json
from collections import Counter
from pathlib import Path

from . import config, io_util

OUT = "entries.krdict.jsonl"

# 유의어로 인정하는 SenseRelation 관계 유형. 02-01 재조사 결과 실제 값은 "비슷한말"이 아니라
# "유의어"다(기초사전 관계 유형: 유의어/참고어/반대말/작은말/큰말/여린말/준말/본말/센말/높임말/
# 낮춤말 — "비슷한말"은 아예 없다). "참고어"는 단순 관련어라 유의어로 치지 않는다.
SYNONYM_RELATION_TYPES = {"유의어"}


def _as_list(x):
    """카디널리티에 따라 dict 하나 또는 list 로 오는 필드를 리스트로 통일한다."""
    if x is None:
        return []
    return x if isinstance(x, list) else [x]


def _feat_map(feat) -> dict:
    """`[{"att": a, "val": v}, ...]` 또는 `{"att": a, "val": v}` -> `{a: v}`."""
    return {f.get("att"): f.get("val") for f in _as_list(feat)}


def _written_form(entry: dict) -> str:
    """Lemma 는 보통 dict 하나지만 변이형(variant)이 있으면 list 다(예: '체스'/'체인').

    이번 범위는 변이형을 다루지 않으므로 첫 Lemma 의 writtenForm 만 표제어로 쓴다.
    """
    for lemma in _as_list(entry.get("Lemma")):
        val = _feat_map(lemma.get("feat")).get("writtenForm")
        if val:
            return val
    return ""


def _src_files(use_fixtures: bool) -> list[Path]:
    base = config.FIXTURES if use_fixtures else config.RAW
    if use_fixtures:
        d = base / "krdict"
        if not d.exists():
            d = base
        return sorted(d.glob("*.json"))
    # 실데이터 폴더명은 "전체 내려받기_한국어기초사전_json_<날짜>" 처럼 날짜가 섞여 있고
    # 이름 변경이 금지돼 있다(00-01) -> 하위 경로 전부에서 "기초사전" 이 들어간 json 만
    # 재귀로 찾는다(표준국어대사전 json 과 섞이지 않도록 -- parse_stdict.py 와 대칭).
    return sorted(p for p in base.rglob("*.json") if "기초사전" in str(p))


def _sense_definition(sense: dict) -> str:
    return (_feat_map(sense.get("feat")).get("definition") or "").strip()


def _sense_synonyms(sense: dict) -> list[str]:
    syns = []
    for rel in _as_list(sense.get("SenseRelation")):
        fm = _feat_map(rel.get("feat"))
        if fm.get("type") in SYNONYM_RELATION_TYPES:
            syns.append((fm.get("lemma") or "").strip())
    return [s for s in syns if s]


def parse_entry(entry: dict, entry_key: str) -> list[dict]:
    """entry_key 는 호출자가 만든, 이 항목 전용의 유일한 식별자다 (아래 "entry.val 이 유일하지
    않다" 참고). 여기서는 그걸로 sense_id 를 짓기만 한다.
    """
    raw = _written_form(entry).strip()
    if not raw:
        return []

    fm = _feat_map(entry.get("feat"))
    homonym_number = fm.get("homonym_number")
    # "0" 은 "동형어 없음" 이다(별도 필드가 없는 게 아니라 값이 "0") — None 으로 통일한다.
    homonym = homonym_number if homonym_number and homonym_number != "0" else None
    pos = fm.get("partOfSpeech") or ""
    word_type = fm.get("lexicalUnit") or None

    out = []
    for sense in _as_list(entry.get("Sense")):
        sense_no = sense.get("val") or ""
        definition = _sense_definition(sense)
        if not sense_no or not definition:
            continue
        out.append({
            "source": "krdict",
            "sense_id": f"krdict:{entry_key}-{sense_no}",
            "raw_headword": raw,
            "homonym": homonym,
            "pos": pos,
            "word_type": word_type,
            "definition": definition,
            "synonyms": _sense_synonyms(sense),
        })
    return out


def iter_entries(path: Path, seen_vals: Counter):
    """`seen_vals` 는 `run()` 이 전체 파일에 걸쳐 공유하는 카운터다.

    ### entry.val 이 전역 유일하지 않다 (02-01 실데이터에서 발견)
    관용구·속담 항목은 파생 원어의 `LexicalEntry` id(`val`)를 그대로 재사용한다
    (예: "첫"(단어, val=77610)과 "첫 단추를 끼우다"(관용구)가 둘 다 val=77610).
    실측 56,555 항목 중 1,160개 val 이 이렇게 중복되며, 중복 그룹마다 "단어"가 정확히
    1개씩(전수 확인) 나머지는 관용구/속담/구다. `krdict:{val}-{sense}` 를 그대로 쓰면
    entries.krdict.jsonl 안에서 sense_id 가 충돌한다(02-03 DoD "sense_id 전역 유일").
    그래서 같은 val 을 다시 보면 순번을 덧붙여 키를 갈라 준다 — 처리 순서(파일 정렬 ->
    파일 내 등장 순)가 고정이라 재현 가능하다.
    """
    data = json.loads(path.read_text(encoding="utf-8"))
    entries = data["LexicalResource"]["Lexicon"]["LexicalEntry"]
    for entry in entries:
        val = entry.get("val") or ""
        occurrence = seen_vals[val]
        seen_vals[val] += 1
        entry_key = val if occurrence == 0 else f"{val}+{occurrence}"
        yield from parse_entry(entry, entry_key)


def run(use_fixtures: bool = False) -> int:
    files = _src_files(use_fixtures)
    if not files:
        raise FileNotFoundError(
            "기초사전 JSON 없음. tools/raw/전체 내려받기_한국어기초사전_*/*.json 확인 (00-01)")

    seen_vals: Counter = Counter()

    def rows():
        for f in files:
            yield from iter_entries(f, seen_vals)

    return io_util.write_jsonl(config.BUILD / OUT, rows())
