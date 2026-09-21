# J Game

게임 프로젝트를 모아 두는 저장소입니다.

- [`crossword-puzzle/`](./crossword-puzzle/): Flutter 낱말퍼즐 구현
- [`drone-simulator/`](./drone-simulator/): Unity·Windows 드론 조종 시뮬레이터 계획 단계

## crossword-puzzle

한국어 낱말퍼즐을 오프라인에서 즐길 수 있도록 만드는 Flutter 프로젝트입니다. 기기에 포함된 SQLite 사전 데이터로 십자말 격자를 생성하며, 네트워크는 단어 데이터 갱신에만 사용합니다.

## 핵심 기능

- 단어별 정답·오답 통계를 반영한 출제 우선순위
- 2~5음절 낱말을 교차 배치하는 격자 생성
- Drift와 SQLite 기반의 오프라인 데이터 저장
- manifest·SHA-256 검증 후 데이터베이스를 교체하는 갱신 흐름
- 갱신 실패 시 기존 데이터베이스를 보존하는 통합 테스트

## 저장소 구조

```text
crossword-puzzle/
├─ app/     Flutter 애플리케이션
├─ tools/   사전 데이터를 SQLite로 만드는 오프라인 도구
├─ docs/    설계, 단계별 계획, 검증 기록
└─ asset/   프로젝트 시각 자산

drone-simulator/
├─ README.md
└─ docs/plan.md    구현 전 계획
```

## 낱말퍼즐 시작하기

Flutter SDK를 설치한 뒤 앱 디렉터리에서 실행합니다.

```powershell
cd crossword-puzzle/app
flutter pub get
flutter run
```

## 낱말퍼즐 검증

```powershell
cd crossword-puzzle/app
dart run tool/check_invariants.dart
flutter analyze
flutter test
```

검증 규칙과 설계 근거는 [`crossword-puzzle/docs/`](./crossword-puzzle/docs/)에 있습니다.

## 데이터와 라이선스

사전 원본과 파생 SQLite 데이터의 이용 조건은 [`crossword-puzzle/docs/LICENSES.md`](./crossword-puzzle/docs/LICENSES.md)를 확인하세요. 원본 자료와 사용자의 게임 기록은 저장소에 올리지 않습니다.
