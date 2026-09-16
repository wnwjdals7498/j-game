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

def test_report_stub_raises():
    # build 파이프라인 8단계(02-03~02-09)는 전부 구현됐다.
    # 아직 스텁인 건 report/check(02-10) 뿐이라 대상을 그쪽으로 옮긴다.
    with pytest.raises(NotImplementedError):
        cli.main(["report"])
    with pytest.raises(NotImplementedError):
        cli.main(["check"])
