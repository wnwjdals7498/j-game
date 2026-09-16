import json
from pathlib import Path
from typing import Iterable, Iterator, TextIO

# 국립국어원 csv 는 CP949(EUC-KR) 인 경우가 많다 (02-05 "인코딩").
# UTF-8 을 먼저 시도해야 한다 — cp949/euc-kr 은 아무 바이트열이나 대충 디코드해 버려서
# 순서를 바꾸면 UTF-8 파일이 깨진 채로 "성공" 한다.
CSV_ENCODINGS = ("utf-8-sig", "cp949", "euc-kr")

def write_jsonl(path: Path, rows: Iterable[dict]) -> int:
    path.parent.mkdir(parents=True, exist_ok=True)
    n = 0
    with path.open("w", encoding="utf-8") as f:
        for r in rows:
            f.write(json.dumps(r, ensure_ascii=False))
            f.write("\n")
            n += 1
    return n

def read_jsonl(path: Path) -> Iterator[dict]:
    with path.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                yield json.loads(line)

def count_jsonl(path: Path) -> int:
    return sum(1 for _ in read_jsonl(path))

def detect_csv_encoding(path: Path) -> str:
    """CSV_ENCODINGS 순으로 시도해 **파일 전체가** 디코드되는 첫 인코딩을 돌려준다.

    앞부분만 검사하면 ASCII 로 시작하는 CP949 파일이 UTF-8 로 "성공" 한 뒤
    뒤쪽 한글에서 조용히 깨진다. 통째로 메모리에 올리지 않도록 1MB 씩 흘려 읽는다.
    """
    for enc in CSV_ENCODINGS:
        try:
            with path.open("r", encoding=enc, newline="") as f:
                while f.read(1 << 20):
                    pass
            return enc
        except UnicodeDecodeError:
            continue
    raise UnicodeDecodeError("csv", b"", 0, 1, f"인코딩 판별 실패: {path}")

def open_csv(path: Path) -> tuple[TextIO, str]:
    """(열린 파일, 성공한 인코딩). 인코딩은 로그·README 에 남긴다 (02-05 DoD)."""
    enc = detect_csv_encoding(path)
    return path.open("r", encoding=enc, newline=""), enc
