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

def test_build_stub_raises():
    # parse_krdict(02-03)·parse_stdict(02-04) 는 구현됐다. 아직 스텁인 다음 단계로 대상만 옮긴다.
    with pytest.raises(NotImplementedError):
        cli.main(["build", "--only", "parse_freq"])
