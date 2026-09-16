"""원본 XML 구조 조사 전용 스크립트 (02-01).

파이프라인에 포함되지 않는다. `python -m tools` 는 이 모듈을 import 하지 않는다.
전체 로드 금지 — `iterparse` 로 스트리밍하며 태그/경로 빈도만 센다.

사용법:

    tools\\.venv\\Scripts\\python.exe tools/inspect_xml.py <파일>.xml [limit]
    tools\\.venv\\Scripts\\python.exe tools/inspect_xml.py <파일>.xml --count-tag pos

`limit` 은 처리할 start 이벤트 상한 (기본 200000). 파일이 너무 커서 느리면 줄인다.
`--count-tag TAG` 는 해당 태그의 **텍스트 값 전수 조사** (품사 값 목록 확인용).
"""
import sys
from collections import Counter
import xml.etree.ElementTree as ET


def count_tag_values(path: str, tag: str) -> None:
    """특정 태그의 텍스트 값을 전부 센다 (품사 값 목록 확인용)."""
    c = Counter()
    for ev, el in ET.iterparse(path, events=("end",)):
        if el.tag == tag:
            c[(el.text or "").strip()] += 1
            el.clear()
    print(f"=== <{tag}> 값 전수 조사 ({sum(c.values())}건) ===")
    for v, n in c.most_common():
        print(f"{n:>9}  {v!r}")


ITEM_TAGS = ("item", "entry", "LexicalEntry")


def inspect(path: str, limit: int) -> None:
    tags = Counter()
    paths = Counter()
    stack = []
    first_item = []
    capturing = False

    for ev, el in ET.iterparse(path, events=("start", "end")):
        if ev == "start":
            stack.append(el.tag)
            tags[el.tag] += 1
            paths["/".join(stack)] += 1
            if not first_item and el.tag in ITEM_TAGS:
                capturing = True
        else:
            if capturing and el.tag in ITEM_TAGS:
                first_item.append(ET.tostring(el, encoding="unicode")[:4000])
                capturing = False
            stack.pop()
            # 첫 항목을 뜨는 동안에는 clear 하지 않는다.
            # 자식의 end 이벤트가 먼저 오므로, 무조건 clear 하면 항목이 빈 껍데기로 찍힌다.
            if not capturing:
                el.clear()
        if sum(tags.values()) > limit:
            break

    print("=== 태그 빈도 (상위 40) ===")
    for t, n in tags.most_common(40):
        print(f"{n:>9}  {t}")
    print("\n=== 경로 빈도 (상위 40) ===")
    for p, n in paths.most_common(40):
        print(f"{n:>9}  {p}")
    if first_item:
        print("\n=== 첫 항목 원문 ===")
        print(first_item[0])


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    path = argv[0]
    rest = argv[1:]
    if "--count-tag" in rest:
        i = rest.index("--count-tag")
        count_tag_values(path, rest[i + 1])
        return 0
    limit = int(rest[0]) if rest else 200000
    inspect(path, limit)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
