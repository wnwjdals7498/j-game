import time
from . import config, io_util
from . import parse_krdict, parse_stdict, parse_freq, parse_vocab
from . import normalize, merge, score, build_sqlite

STEPS = [
    ("parse_krdict", parse_krdict.run),
    ("parse_stdict", parse_stdict.run),
    ("parse_freq",   parse_freq.run),
    ("parse_vocab",  parse_vocab.run),
    ("normalize",    normalize.run),
    ("merge",        merge.run),
    ("score",        score.run),
    ("build_sqlite", build_sqlite.run),
]

def build(only: str | None = None, use_fixtures: bool = False) -> None:
    config.BUILD.mkdir(parents=True, exist_ok=True)
    for name, fn in STEPS:
        if only and name != only:
            continue
        t0 = time.perf_counter()
        n = fn(use_fixtures=use_fixtures)
        dt = time.perf_counter() - t0
        print(f"  {name:<14} {n:>8,} rows  {dt:6.1f}s")
