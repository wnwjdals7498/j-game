# 진행 계획 (로드맵)

작성일: 2026-09-16
전제: `docs/DESIGN.md` 방향 + `docs/REVIEW.md` 검토 결과 반영.

---

## 1. 단계 구성

```
 0 환경 구축 ──┬─→ 1 domain 맵 생성기 ──┐
 (+데이터 신청) │                       ├─→ 3 data 연결·실측 ─→ 4 UI ─→ 5 갱신 ─→ 6 배포
               └─→ 2 tools ETL ────────┘
```

| # | 단계 | 문서 | 핵심 산출물 | 규모 | 선행 |
|---|---|---|---|---|---|
| 0 | 환경 구축 · 스켈레톤 · 데이터 신청 | [plan/00-env-setup.md](plan/00-env-setup.md) | 기기에서 돌아가는 hello APK, 빈 Flutter 프로젝트 구조, 데이터 신청 완료 | S | — |
| 1 | domain 맵 생성기 | [plan/01-domain-map-generator.md](plan/01-domain-map-generator.md) | 더미 사전으로 테스트 통과하는 `GridGenerator`, 실패율 하네스 | **L** | 0 |
| 2 | tools ETL | [plan/02-tools-etl.md](plan/02-tools-etl.md) | 재현 가능한 `words.sqlite` 빌드, 티어 분포 리포트 | M | 0 (데이터 승인) |
| 3 | data 연결 · 실데이터 실측 | [plan/03-data-layer.md](plan/03-data-layer.md) | drift 리포지토리, 실기기 생성 성능·실패율 리포트, 레벨 스펙 v1 | M | 1, 2 |
| 4 | UI | [plan/04-ui.md](plan/04-ui.md) | 플레이 루프 완성 (홈→퍼즐→결과), 출처 표기 화면 | M~L | 3 |
| 5 | 갱신 SyncService | [plan/05-sync.md](plan/05-sync.md) | GitHub Releases 기반 6개월 갱신, 통계 보존 검증 | S~M | 4 |
| 6 | 배포 | [plan/06-release.md](plan/06-release.md) | 서명된 AAB, 스토어 준비물 | S | 5 |

규모: S = 며칠 이내, M = 1~2주, L = 2주 이상 (혼자 파트타임 기준의 감. 확정치 아님).

---

## 2. 병행 트랙

- **1단계(Dart)와 2단계(Python)는 완전 독립.** 데이터 승인을 기다리는 동안 1단계에 집중하고, 승인 나면 2단계 착수.
- **2단계는 승인 전에도** 스크립트 뼈대·스키마·티어 산식은 만들 수 있다. 실제 XML 구조는 받아본 뒤 매핑.
- **데이터 이용 신청은 0단계 첫날** 한다. 병목이 될 수 있는 유일한 외부 의존.

---

## 3. 단계 간 계약 (이게 깨지면 기획이 틀어짐)

| 계약 | 정한 곳 | 쓰는 곳 |
|---|---|---|
| `WordRepository` 인터페이스 (패턴 질의, 코어 후보 조회) | 1 | 3 |
| `LevelSpec` 타입 (격자 크기, 코어 티어·개수, 채움 티어별 개수) | 1 | 3, 4 |
| `Puzzle` / `PlacedWord` / `SubmitResult` 타입 | 1 | 4 |
| SQLite 스키마 `tools/schema.sql` (word, sense, word_stat, word_char, meta) | 2 | 3, 5 |
| `manifest.json` 형식 | 5 | 6 |
| 격자 규칙 (성긴 방식, 2~5음절, 고립 단어 ≤1) | REVIEW 5절 | 1, 3, 4 |

계약을 바꿔야 하면 해당 plan 문서와 DESIGN.md를 같이 고친다.

---

## 4. 각 단계 공통 완료 조건

- 문서에 적힌 "완료 기준(DoD)" 전부 충족.
- 테스트가 있는 단계는 `dart test` / `python -m pytest` 통과.
- 결정 사항 변경은 DESIGN.md 5절(임의 규칙) 또는 해당 plan 문서에 기록.
- 커밋 후 다음 단계 진입.

---

## 5. 지금 당장 할 일 (0단계 첫날)

1. 국립국어원 한국어기초사전 회원가입 → 전체 자료 내려받기 신청
2. 표준국어대사전 전체 자료 이용 신청
3. Android Studio 설치 (SDK·JDK 동봉)
4. Flutter SDK 설치 → `flutter doctor` 전부 초록
5. `flutter create app` → 실기기 또는 에뮬레이터에서 실행 확인

상세: [plan/00-env-setup.md](plan/00-env-setup.md)
