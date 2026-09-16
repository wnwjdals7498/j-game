# 5단계 — 갱신 (SyncService)

규모: S~M · 선행: 4단계 · 다음: 6단계

## 목표

6개월마다 새 `words.sqlite`를 내려받아 **유저 통계(`word_stat`)를 보존한 채** 교체한다. 웹은 1차 범위 밖(네이티브만).

## 배포처 결정

**GitHub Releases** (DESIGN 6절 미정 → 확정 권고). 무료, 정적 URL, 파일당 2GB 한도. 릴리스마다:

```
words-v{db_version}.sqlite
manifest.json
```

`manifest.json` (6단계·릴리스 스크립트와의 계약):

```json
{
  "db_version": 3,
  "schema_version": 1,
  "url": "https://github.com/<owner>/<repo>/releases/download/db-v3/words-v3.sqlite",
  "sha256": "…",
  "size_bytes": 9800000,
  "min_app_version": "1.0.0",
  "published_at": "2027-03-01"
}
```

manifest의 위치는 고정 URL 하나(예: `releases/latest/download/manifest.json`). 앱은 이 URL만 안다.

## 동작

```
앱 시작 (또는 설정의 "지금 갱신")
 └→ last_sync_at 이 180일 이상 전 AND 네트워크 있음?  아니면 종료
 └→ manifest 다운로드 → db_version > 현재? schema_version 호환? min_app_version 만족?  아니면 종료
 └→ 새 DB를 임시 파일로 다운로드 (재개 가능하면 좋고, 아니면 실패 시 삭제 후 다음 기회)
 └→ sha256 검증 실패 → 삭제, 종료
 └→ 새 DB 열어 sanity check: word 행 수 > 0, meta.db_version 일치, 필수 테이블 존재
 └→ ATTACH 기존 DB → word_stat 전체를 새 DB로 복사 (headword 기준. 새 DB에 없는 단어의 stat도 보존)
 └→ 기존 DB 닫기 → 파일 원자 교체 (rename) → 새 DB 열기
 └→ last_sync_at 기록, 사용자에게 "단어 N개 갱신" 한 줄 안내
```

실패는 어느 단계든 **조용히 중단, 기존 DB 그대로 사용**. 사용자 흐름을 막지 않는다.

## 산출물

```
app/lib/data/sync/
├─ manifest.dart           파싱·검증
├─ sync_service.dart       위 흐름
└─ db_swapper.dart         stat 복사 + 원자 교체
tools/release_db.py        words.sqlite → manifest.json 생성 (sha256, size) — 6단계 스크립트가 호출
```

## 테스트

- 단위: manifest 파싱, 버전 비교 로직, sha256 불일치 처리.
- 통합(데스크톱 또는 에뮬레이터): 로컬 HTTP 서버로 가짜 manifest·DB 제공 →
  1. 정상 갱신 후 `word_stat` 행 수·값 동일.
  2. 다운로드 중단(서버 끊기) → 기존 DB 무손상.
  3. sha256 조작 → 거부.
  4. schema_version 불일치 → 거부.
- 실기기: Wi-Fi 끄고 시작 → 조용히 스킵 확인.

## 완료 기준 (DoD)

1. 위 통합 테스트 4종 통과.
2. 실기기에서 실제 GitHub Releases의 테스트 릴리스로 갱신 1회 성공, 통계 보존 확인.
3. 설정 화면에 DB 버전·마지막 갱신일·수동 갱신 버튼 노출.
4. `manifest.json` 형식이 이 문서와 `tools/release_db.py`에서 일치.

## 리스크

- GitHub 접근이 막힌 네트워크(일부 기업망) → 갱신만 실패, 게임은 정상. 허용.
- 10MB 다운로드를 모바일 데이터에서 → Wi-Fi 전용 옵션 기본 켬 (설정에서 해제 가능). 규칙 절에 기록.
- 스키마 변경이 필요한 갱신 → `schema_version` 올리고 앱 업데이트 강제(`min_app_version`). 구 앱은 갱신 스킵.
