# tools — 오프라인 ETL (앱에 포함되지 않음)

사전 원본을 가공해 `words.sqlite` 를 만든다. 개발 PC에서만 실행한다.

## 실행

```powershell
tools\.venv\Scripts\Activate.ps1
pip install -r tools/requirements.txt
python -m tools build      # raw -> tools/build/words.sqlite
python -m tools report     # docs/reports/02-db-report.md 생성
python -m tools check      # 산출물 검증
```

Python 3.13 필수. 이 PC의 `python3` 는 3.6.8이므로 사용 금지.

## 원본 자료

`tools/raw/` 에 둔다. 커밋하지 않는다(용량·라이선스).
자료 목록과 라이선스는 `docs/LICENSES.md` 참조.

## 실제 파일 구조 조사 결과

(02-01에서 채운다)
