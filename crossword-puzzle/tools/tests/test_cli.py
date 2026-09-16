import pytest
from tools import __main__ as cli
from tools import config

def test_tier_ratio_sums_to_100():
    assert sum(config.TIER_RATIO) == 100
    assert len(config.TIER_RATIO) == config.TIER_COUNT

def test_tier_ratio_is_pyramid():
    for a, b in zip(config.TIER_RATIO, config.TIER_RATIO[1:]):
        assert a > b, "티어 비율은 피라미드(등분위 금지)여야 한다"

def test_cli_requires_subcommand():
    with pytest.raises(SystemExit):
        cli.main([])

def test_no_stubs_left(tmp_path, monkeypatch):
    # 02-03~02-09 의 build 8단계에 이어 report/check(02-10)까지 구현됐다.
    # `check` 는 종료 코드를 내는 게 계약이다 — DB 가 없으면 1 (CI, 06-06).
    monkeypatch.setattr(config, "BUILD", tmp_path)
    assert cli.main(["check"]) == 1
