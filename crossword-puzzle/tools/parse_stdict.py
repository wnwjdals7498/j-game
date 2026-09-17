"""표준국어대사전 JSON -> build/entries.stdict.jsonl (02-04).

02-01 재조사(2026-09-17) 결과 원본은 XML 이 아니라 JSON 이고, 구조는 기초사전(LMF/att-val)과
전혀 다른 평평한 형태다: `{"channel": {"total": N, "item": [...]}}`.
`item[].word_info.word` 가 표제어, `word_info.pos_info[]` (품사별로 여러 개 가능) 안에
`comm_pattern_info[].sense_info[]` 가 뜻풀이 목록이다. 자세한 경로는 tools/README.md
"실제 파일 구조 조사 결과 -> 2. 표준국어대사전" 참조.

출력 스키마는 02-03(기초사전)과 완전히 같다. `source` 와 `sense_id` 접두어만 다르다.
예문(example_info)·발음(pronunciation_info)·이미지(multimedia_info)는 라이선스 비개방
(DESIGN 6절)이라 읽지도 저장하지도 않는다 — 아래 코드가 그 키를 참조하지 않는다.

02-04 검증(2026-09-17, 실데이터 전수)에서 별도 문제가 나왔다: 수식이 있는 sense는
`definition` 문자열 자체에 `<img src='http://stdmgt.korean.go.kr:8899/.../formula.do?...'>`
형태의 이미지 태그가 그대로 박혀 있다(84개 sense, <img> 126건). multimedia_info 키가
아니라 definition 텍스트 안에 섞여 있어서 위 "그 키를 참조하지 않는다"만으로는 안
걸러진다 — `_strip_img_tags()`로 definition 문자열에서 <img> 태그만 따로 제거한다.

파일당 최대 ~10MB(88개 파일, 총 ~789MB)라 파일 하나씩 `json.load` 로 통째로 읽는다.
표준은 DESIGN 2절상 "보충" 자료다. 원본이 없어도 빈 파일을 내고 파이프라인은 계속 돈다.
"""
import json
import re
from pathlib import Path

from . import config, io_util

OUT = "entries.stdict.jsonl"

DROP_WORD_UNITS = {"구", "속담", "관용구"}

# 유의어로 인정하는 lexical_info 관계 유형. 02-01 재조사 결과 실제 값 분포는
# 동의어(162,127) > 비슷한말(26,264) > 반대말 > 준말 > 본말 > 높임말 > 낮춤말 > 참고 어휘
# 다 — "비슷한말"만 있는 게 아니라 "동의어"가 압도적으로 많다. 둘 다 유의어로 인정하고,
# "참고 어휘"(단순 관련어)와 "반대말"은 제외한다.
SYNONYM_RELATION_TYPES = {"동의어", "비슷한말"}

# 실데이터에는 동형어 번호를 담는 별도 필드가 없다(00-01/02-01: 전수 스캔 436,587건 중 0건).
# `word` 문자열 끝의 숫자(전부 2자리, 예: "각본01")로만 존재한다. raw_headword 는 원문
# 그대로 두고(02-04 "여기서 고치지 않는다"), 이 값을 `homonym` 필드로 "분리"만 한다.
_HOMONYM_SUFFIX = re.compile(r"(\d+)$")

# 수식 렌더링용 이미지 태그 (라이선스 비개방, DESIGN 6절 "이미지는 개방 대상 아님").
# 실데이터 예: <img style="vertical-align: middle;" src='http://stdmgt.korean.go.kr:8899/
# dictionary/compilation/popup/formula.do?latex=...'> (닫는 태그 없이 단독으로 등장).
_IMG_TAG = re.compile(r"<img\b[^>]*>", re.IGNORECASE)
_MULTI_SPACE = re.compile(r"[ \t]{2,}")


def _strip_img_tags(text: str) -> str:
    """definition 문자열에 섞인 <img> 수식 태그를 제거한다. 태그를 들어내고 남는
    공백만 한 칸으로 접는다 — 태그가 감싸던 수식 자체(값)는 애초에 복원할 수 없고
    복원 대상도 아니다(DESIGN 6절 "추출 단계에서 제외")."""
    return _MULTI_SPACE.sub(" ", _IMG_TAG.sub("", text)).strip()

# 전문어(cat_info)는 아직 거르지 않는다 — 02-04 "막히면": 일단 약하게 걸고
# 02-10 눈 검수 · 03-05 실패율을 보고 조인다. 처음부터 세게 걸면 되돌리기 어렵다.
# 02-01 재조사: cat_info 는 sense_info 46%(509,143건 중 236,739건)에 붙어 있는 폭넓은
# "주제 분야" 태그(역사·불교·인명·식물·화학...)라 존재만으로 거르면 절반 가까이 날아간다.
DROP_TECHNICAL = False

# --- 02-01 재조사 결과: "방언/옛말/북한어" 판정 필드는 존재하지 않는다 -----------------
# 00-01/02-04 는 `word_info.word_type`(예: "방언") 또는 `dialect_info` 존재로 방언·옛말·
# 북한어를 거르라고 했으나, 실데이터(436,587항목) 전수 스캔 결과:
#   - `word_type` 은 어원 유형(고유어/한자어/외래어/혼종어/'')일 뿐 방언·옛말·북한어 값이
#     전혀 없다.
#   - `dialect_info`/`region_info` 필드 자체가 어디에도 없다.
#   - `sense_info.type` 은 전 항목이 "일반어"로 고정(509,143/509,143)이다.
#   - 정의문 텍스트도 "'OO'의 방언"/"'OO'의 옛말" 패턴이 0건이다(있는 건 "방언"이라는
#     개념을 설명하는 표제어 자체뿐 -- 예: '방언02'="...양웅이 엮은 책...").
#   - "북한" 이 들어간 정의문은 대부분 북한 소재 지명의 행정구역 연혁 설명이라 오탐이 크다.
# 즉 이 다운로드본에는 방언/옛말/북한어를 가려낼 근거가 없다. 코드로 억지로 걸지 않고
# 02-04 문서의 "표준 고유 필터" 표에서 해당 행을 제거했다(02-01 6절: "코드로 땜질하지
# 않는다"). 구·속담·관용구 제외(word_unit, 신뢰 가능)만 남는다.


def _src_files(use_fixtures: bool) -> list[Path]:
    base = config.FIXTURES if use_fixtures else config.RAW
    if use_fixtures:
        d = base / "stdict"
        if not d.exists():
            d = base
        return sorted(d.glob("*.json"))
    # 실데이터 폴더명은 "전체 내려받기_표준국어대사전_JSON_<날짜>" 처럼 날짜가 섞여 있고
    # 이름 변경이 금지돼 있다(00-01) -> 하위 경로 전부에서 "표준국어대사전" 이 들어간
    # json 만 재귀로 찾는다(기초사전 json 과 섞이지 않도록).
    return sorted(p for p in base.rglob("*.json") if "표준국어대사전" in str(p))


def _new_stats() -> dict:
    return {"total": 0, "kept": 0, "drop_phrase": 0, "drop_technical": 0}


def _extract_homonym(word: str) -> str | None:
    m = _HOMONYM_SUFFIX.search(word)
    return m.group(1) if m else None


def _sense_synonyms(sense: dict) -> list[str]:
    syns = [
        (li.get("word") or "").strip()
        for li in sense.get("lexical_info") or []
        if li.get("type") in SYNONYM_RELATION_TYPES
    ]
    return [s for s in syns if s]


def parse_item(item: dict, stats: dict) -> list[dict]:
    wi = item.get("word_info") or {}
    raw = (wi.get("word") or "").strip()
    if not raw:
        return []

    word_unit = wi.get("word_unit")
    if word_unit in DROP_WORD_UNITS:
        stats["drop_phrase"] += 1
        return []

    homonym = _extract_homonym(raw)

    out = []
    # pos_info 가 여러 개일 수 있다(품사가 둘 이상인 표제어, 실측 439,566/436,587개
    # pos_info -- 약 3천 개 항목이 품사를 둘 이상 갖는다). 각 pos_info 소속 sense_info 는
    # 그 pos_info 의 pos 를 써야 한다 -- 첫 pos_info 의 pos 하나로 전부 라벨링하면 틀린다.
    for pinfo in wi.get("pos_info") or []:
        pos = pinfo.get("pos") or ""
        for cpinfo in pinfo.get("comm_pattern_info") or []:
            for sinfo in cpinfo.get("sense_info") or []:
                if DROP_TECHNICAL and sinfo.get("cat_info"):
                    stats["drop_technical"] += 1
                    continue
                sense_code = sinfo.get("sense_code")
                definition = _strip_img_tags((sinfo.get("definition") or "").strip())
                if sense_code is None or not definition:
                    continue
                out.append({
                    "source": "stdict",
                    "sense_id": f"stdict:{sense_code}",
                    "raw_headword": raw,
                    "homonym": homonym,
                    "pos": pos,
                    "word_type": word_unit,
                    "definition": definition,
                    "synonyms": _sense_synonyms(sinfo),
                })
    return out


def iter_entries(path: Path, stats: dict):
    """`json.load` 로 파일 하나를 통째로 읽는다. 파일당 최대 ~10MB 라 스트리밍이 필요 없다
    (02-01: "대용량 실파일은 파일 하나씩 열고 처리하는 방식으로 충분하다")."""
    data = json.loads(path.read_text(encoding="utf-8"))
    for item in data["channel"]["item"]:
        stats["total"] += 1
        yield from parse_item(item, stats)


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
