# 세부 계획 인덱스

작성일: 2026-09-16
상위 문서: [../PLAN.md](../PLAN.md) · [../DESIGN.md](../DESIGN.md) · [../REVIEW.md](../REVIEW.md)

---

## 읽는 법

`docs/plan/NN-MM.slug.md` — `NN`은 PLAN.md의 단계 번호, `MM`은 그 단계 안의 실행 순서.

각 세부 계획 문서는 **한 번의 작업 세션에서 끝낼 수 있는 단위**로 잘려 있고, 아래 고정 구조를 가진다.

| 절 | 뜻 |
|---|---|
| 담당 | `AGENT` = 코딩 에이전트가 수행 / `HUMAN` = 사람이 직접 해야 함(설치·가입·결제·기기 조작) / `MIXED` |
| 선행 | 이 문서를 시작하기 전에 끝나 있어야 하는 문서 |
| 컨텍스트 | 시작 전 반드시 읽을 파일 |
| 작업 | 순서대로 실행. 명령·파일 경로·코드 골격 포함 |
| 산출물 | 이 문서가 끝나면 존재해야 하는 파일 |
| 검증 | 그대로 실행해서 통과해야 하는 명령 |
| DoD | 체크리스트 |
| 막히면 | 실패 시 대응 |

**규칙**
- `HUMAN` 문서를 만나면 에이전트는 **작업하지 말고** 사람에게 넘기고 대기한다.
- 문서에 없는 결정을 새로 해야 하면, 하지 말고 멈춘 뒤 해당 문서의 "막히면" 절에 따른다.
- 계약(타입 시그니처·스키마)을 바꾸면 이 폴더의 해당 문서 + `docs/DESIGN.md`를 같이 고친다.

---

## 0단계 — 환경 구축 · 스켈레톤 · 데이터 신청

| 문서 | 담당 | 내용 |
|---|---|---|
| [00-01.data-request.md](00-01.data-request.md) | HUMAN | 사전·빈도·어휘 자료 4종 이용 신청 |
| [00-02.android-toolchain.md](00-02.android-toolchain.md) | HUMAN | Android Studio, SDK, JDK, adb, 테스트 기기 |
| [00-03.flutter-sdk.md](00-03.flutter-sdk.md) | HUMAN | Flutter SDK, `flutter doctor` 초록 |
| [00-04.python-venv.md](00-04.python-venv.md) | AGENT | `tools/.venv`, requirements, README |
| [00-05.project-skeleton.md](00-05.project-skeleton.md) | AGENT | `flutter create`, 폴더 구조, .gitignore, 브랜치 |
| [00-06.verification-build.md](00-06.verification-build.md) | MIXED | APK·웹 실행 확인, 첫 커밋 |

## 1단계 — domain 맵 생성기 (순수 Dart, **L**)

| 문서 | 담당 | 내용 |
|---|---|---|
| [01-01.domain-models.md](01-01.domain-models.md) | AGENT | `WordEntry`, `LevelSpec`, `Puzzle`, `SubmitResult` 타입 확정 |
| [01-02.word-repository-and-dummy.md](01-02.word-repository-and-dummy.md) | AGENT | `WordRepository` 인터페이스 + 더미 사전 2종 |
| [01-03.grid-rules.md](01-03.grid-rules.md) | AGENT | 배치 합법성·연속·연결성 검증 |
| [01-04.core-placer.md](01-04.core-placer.md) | AGENT | 코어 단어 교차 배치 |
| [01-05.slot-enumerator.md](01-05.slot-enumerator.md) | AGENT | 채움 슬롯 열거 |
| [01-06.filler.md](01-06.filler.md) | AGENT | 채움 + 백트래킹 |
| [01-07.grid-generator.md](01-07.grid-generator.md) | AGENT | 전체 오케스트레이션, 재시도, 결정성 |
| [01-08.scorer.md](01-08.scorer.md) | AGENT | 채점 |
| [01-09.levels-table.md](01-09.levels-table.md) | AGENT | `levels.dart` 초안 |
| [01-10.measure-harness.md](01-10.measure-harness.md) | AGENT | 실패율·성능 하네스 + 리포트 |

## 2단계 — tools ETL (Python)

| 문서 | 담당 | 내용 |
|---|---|---|
| [02-01.raw-inspection.md](02-01.raw-inspection.md) | MIXED | 받은 원본 구조 조사·기록 |
| [02-02.tools-skeleton.md](02-02.tools-skeleton.md) | AGENT | `python -m tools` CLI, config, 파이프라인 뼈대 |
| [02-03.parse-krdict.md](02-03.parse-krdict.md) | AGENT | 기초사전 XML 파서 |
| [02-04.parse-stdict.md](02-04.parse-stdict.md) | AGENT | 표준국어대사전 XML 파서 |
| [02-05.parse-freq-vocab.md](02-05.parse-freq-vocab.md) | AGENT | 빈도·학습용 어휘 csv 파서 |
| [02-06.normalize.md](02-06.normalize.md) | AGENT | 표제어 정규화·필터 |
| [02-07.merge.md](02-07.merge.md) | AGENT | 표제어 기준 결합 |
| [02-08.score-tier.md](02-08.score-tier.md) | AGENT | 복합 점수 → 7티어 피라미드 |
| [02-09.build-sqlite.md](02-09.build-sqlite.md) | AGENT | `schema.sql` + 적재 + 인덱스 + meta |
| [02-10.report-and-review.md](02-10.report-and-review.md) | MIXED | 분포 리포트 + 눈 검수 |

## 3단계 — data 연결 · 실데이터 실측

| 문서 | 담당 | 내용 |
|---|---|---|
| [03-01.drift-schema.md](03-01.drift-schema.md) | AGENT | drift 스키마 (`tools/schema.sql`과 1:1) |
| [03-02.db-bootstrap.md](03-02.db-bootstrap.md) | AGENT | 네이티브/웹 첫 실행 분기 |
| [03-03.pattern-query-repository.md](03-03.pattern-query-repository.md) | AGENT | `WordRepository` drift 구현 |
| [03-04.stat-repository.md](03-04.stat-repository.md) | AGENT | `word_stat` 읽기·쓰기, 첫 제출만 반영 |
| [03-05.real-measure.md](03-05.real-measure.md) | MIXED | 실데이터·실기기 실패율·속도 측정 |
| [03-06.level-spec-v1.md](03-06.level-spec-v1.md) | AGENT | 측정 기반 레벨 스펙 v1 확정 |

## 4단계 — UI

| 문서 | 담당 | 내용 |
|---|---|---|
| [04-01.app-shell-state.md](04-01.app-shell-state.md) | AGENT | 상태관리 결정, 라우팅, 앱 셸 |
| [04-02.grid-renderer.md](04-02.grid-renderer.md) | AGENT | `CustomPaint` 격자 렌더링 |
| [04-03.selection-and-hint.md](04-03.selection-and-hint.md) | AGENT | 셀 탭 → 단어 선택, 힌트 패널 |
| [04-04.word-input.md](04-04.word-input.md) | AGENT | 하단 텍스트 필드 입력 → 셀 분배 (IME) |
| [04-05.submit-and-result.md](04-05.submit-and-result.md) | AGENT | 제출 확인 → 채점 → 결과 화면 |
| [04-06.home-and-settings.md](04-06.home-and-settings.md) | AGENT | 홈·레벨 목록·설정·출처 표기 |
| [04-07.ui-tests.md](04-07.ui-tests.md) | MIXED | 위젯 테스트 + IME 수동 검증 |

## 5단계 — 갱신 (SyncService)

| 문서 | 담당 | 내용 |
|---|---|---|
| [05-01.manifest-and-release-script.md](05-01.manifest-and-release-script.md) | AGENT | `manifest.json` 계약 + `tools/release_db.py` |
| [05-02.sync-service.md](05-02.sync-service.md) | AGENT | 갱신 흐름 |
| [05-03.db-swapper.md](05-03.db-swapper.md) | AGENT | stat 보존 + 원자 교체 |
| [05-04.sync-tests.md](05-04.sync-tests.md) | MIXED | 통합 테스트 4종 + 실기기 갱신 |

## 6단계 — 배포

| 문서 | 담당 | 내용 |
|---|---|---|
| [06-01.app-identity.md](06-01.app-identity.md) | AGENT | applicationId, 버전, 아이콘·스플래시 |
| [06-02.signing.md](06-02.signing.md) | HUMAN | 키스토어 생성·백업, signingConfig |
| [06-03.release-build.md](06-03.release-build.md) | MIXED | AAB·release APK, 크기·동작 점검 |
| [06-04.store-assets.md](06-04.store-assets.md) | MIXED | 스크린샷, 설명, 개인정보처리방침, 양식 |
| [06-05.db-release-procedure.md](06-05.db-release-procedure.md) | AGENT | `docs/RELEASE.md` + 실제 릴리스 1회 |
| [06-06.ci.md](06-06.ci.md) | AGENT | GitHub Actions (선택) |

---

## 단계 간 계약 (바꾸면 양쪽 문서 동시 수정)

| 계약 | 정하는 문서 | 쓰는 문서 |
|---|---|---|
| `WordEntry` / `LevelSpec` / `Puzzle` / `SubmitResult` | 01-01 | 01-*, 03-*, 04-* |
| `WordRepository` 인터페이스 | 01-02 | 03-03 |
| `tools/schema.sql` | 02-09 | 03-01, 05-03 |
| `manifest.json` | 05-01 | 06-05 |
| 격자 규칙 (성긴 방식, 2~5음절, 고립 금지) | 01-03 | 01-04~07, 04-02 |
| 통계 점수 산식 `correct - wrong*2` | 01-02 | 03-03, 03-04 |
