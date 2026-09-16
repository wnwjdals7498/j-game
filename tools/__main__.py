import argparse
import sys
from . import pipeline, report, config

def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="python -m tools")
    sub = p.add_subparsers(dest="cmd", required=True)

    b = sub.add_parser("build", help="raw -> words.sqlite")
    b.add_argument("--only", help="한 단계만 실행 (parse_krdict 등)")
    b.add_argument("--fixtures", action="store_true",
                   help="tools/raw 대신 tools/fixtures 사용 (승인 전 개발)")

    sub.add_parser("report", help="docs/reports/02-db-report.md 생성")
    sub.add_parser("check", help="산출물 검증")

    a = p.parse_args(argv)
    if a.cmd == "build":
        pipeline.build(only=a.only, use_fixtures=a.fixtures)
    elif a.cmd == "report":
        report.render()
    elif a.cmd == "check":
        return 0 if report.check() else 1
    return 0

if __name__ == "__main__":
    sys.exit(main())
