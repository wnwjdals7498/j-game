# 3단계 — data 연결 · 실데이터 실측

규모: M · 선행: 1단계, 2단계 · 다음: 4단계

## 목표

1단계 `WordRepository` 인터페이스를 2단계 `words.sqlite`로 구현한다. 실데이터·실기기에서 **생성 실패율과 속도를 측정**하고 레벨 스펙 v1을 확정한다. 이 단계가 끝나면 UI 없이도 "진짜 단어로 퍼즐이 나온다"가 증명된다.

## 산출물

```
app/lib/data/
├─ db/
│  ├─ app_database.dart       drift 스키마 (tools/schema.sql과 1:1)
│  ├─ open_native.dart        Android/데스크톱: assets → 앱 문서 디렉터리 복사 후 열기
│  └─ open_web.dart           Web: assets 바이트 → drift wasm 저장소 적재 후 열기
├─ drift_word_repository.dart  WordRepository 구현
├─ stat_repository.dart        word_stat 읽기·쓰기 (첫 제출만 반영)
└─ db_bootstrap.dart           첫 실행 판별, 시드 복사, 스키마 버전 확인
app/assets/words.sqlite
app/web/sqlite3.wasm, drift_worker.js
```

## 작업 항목

### A. drift 연결
- `drift`, `drift_flutter`(네이티브) + `drift/wasm`(웹). 스키마는 `tools/schema.sql`을 그대로 옮긴다. drift 코드 생성 대신 **raw SQL 기반**도 가능. 판단 기준: 패턴 질의가 동적(고정 자리 수가 가변)이므로 `customSelect`가 편하다. 테이블 클래스는 타입 안정성 정도로만 쓴다.
- 조건부 import로 `open_native` / `open_web` 분기.

### B. 첫 실행 부트스트랩
- 네이티브: `assets/words.sqlite` → `getApplicationDocumentsDirectory()/words.sqlite` 복사. 이미 있으면 `meta.schema_version` 비교만.
- 웹: drift `WasmDatabase.open(initializeDatabase: () => assets 바이트)`. OPFS 불가 시 IndexedDB 폴백 허용(테스트 용도라 성능 무관).
- 스키마 버전 불일치 시 정책: v1은 "시드로 덮어쓰기 + word_stat 보존" 한 가지만.

### C. 패턴 질의 구현
- `findByPattern`: `fixed`의 자리 수만큼 `cN = ?` 조건 AND, `len = ?`, `tier IN (...)`, `headword NOT IN (...)`, `ORDER BY RANDOM() LIMIT ?`. 단, `RANDOM()`은 결정성을 깨므로 **seed 기반 정렬**이 필요하면 후보를 넉넉히(limit×3) 가져와 Dart에서 `Random(seed)`로 섞는다.
- `EXPLAIN QUERY PLAN`으로 `(len, tier, cN)` 인덱스가 실제로 잡히는지 확인. 잡히지 않으면 인덱스 순서 조정 → `schema.sql` 수정(2단계 산출물 재빌드).
- `coreCandidates`: `word LEFT JOIN word_stat` → `(correct - wrong*2) ASC`, 동점은 위와 같이 Dart에서 seed 셔플.

### D. 통계 기록
- `recordSubmit(puzzleId, results)`: 퍼즐 단위로 "첫 제출 여부"를 로컬에 기억(간단히 `puzzle_log` 테이블 또는 SharedPreferences). 첫 제출만 `word_stat` 반영.
- 산식은 1단계 문서와 DESIGN 5절 값 사용.

### E. 실측 하네스
- 1단계 `measure` 하네스를 실 DB로 돌린다. 두 환경:
  1. **데스크톱** (`dart run` + `sqlite3` 패키지 또는 Flutter 데스크톱 타깃) — 빠른 반복용.
  2. **실기기** (저가형 안드로이드 포함) — Flutter 통합 테스트 또는 디버그 화면의 "벤치마크" 버튼.
- 레벨 스펙별 1000 seed → 실패율, p50/p95 생성 시간, 평균 백트래킹 횟수. `docs/reports/03-real-failure.md`.

### F. 레벨 스펙 v1 확정
- 측정 결과로 `levels.dart` 조정. 초안: 10~15개 레벨, 5×5 → 8×8, 코어 티어 2→6, 채움은 코어보다 1~3티어 낮게.
- 채움 풀 부족이면 표준 보충분 투입 결정 (2단계 재빌드).

## 완료 기준 (DoD)

1. Android 실기기와 Chrome 양쪽에서 실 DB로 퍼즐이 생성된다 (콘솔 출력 수준으로 충분).
2. 실기기 퍼즐 생성 p95 **1초 미만**, 전 레벨 실패율 **1% 미만**. 미달 시 레벨 스펙·티어 할당 조정 후 재측정, 결과 리포트 커밋.
3. `word_stat`에 기록이 남고, 다음 생성에서 낮은 점수 단어가 코어로 우선 선택되는 테스트 통과.
4. drift 스키마가 `words.sqlite`를 문제없이 여는 테스트 통과 (스키마 계약 검증).
5. 첫 실행 부트스트랩이 앱 삭제→재설치 시에도 동작.

## 리스크

- 웹에서 10MB 자산 로딩이 느림 → 테스트 용도이므로 허용. 배포 대상 아님.
- 저가형 기기에서 `NOT IN (...)` 목록이 길어지면 느려짐 → exclude는 격자 안 단어(수십 개)로 제한되어 문제 없을 것. 실측으로 확인.
- 실패율이 더미보다 크게 높을 것 (실단어는 음절 조합이 성김). 이 단계의 존재 이유. 레벨 스펙으로 흡수하고, 안 되면 채움 티어 범위를 넓힌다.
