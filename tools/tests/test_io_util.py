def test_jsonl_roundtrip(tmp_path):
    from tools.io_util import write_jsonl, read_jsonl
    rows = [{"headword": "사과", "tier": 1}, {"headword": "나무", "tier": 2}]
    p = tmp_path / "x.jsonl"
    assert write_jsonl(p, rows) == 2
    assert list(read_jsonl(p)) == rows

def test_jsonl_keeps_hangul_readable(tmp_path):
    from tools.io_util import write_jsonl
    p = tmp_path / "x.jsonl"
    write_jsonl(p, [{"w": "사과"}])
    assert "사과" in p.read_text(encoding="utf-8")
