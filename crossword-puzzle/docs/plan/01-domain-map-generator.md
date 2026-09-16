# 1단계 — domain 맵 생성기 (순수 Dart)

규모: **L** · 선행: 0단계 · 다음: 3단계 · 병행 가능: 2단계

## 목표

DB도 UI도 모르는 순수 Dart로 **격자 생성 · 채점 알고리즘**을 완성하고 더미 사전으로 검증한다. 이 프로젝트의 유일한 난제. 여기서 실패율·성능이 안 나오면 뒤 단계가 전부 흔들리므로 시간을 아끼지 않는다.

## 진입 조건 (코딩 전 확정)

REVIEW.md 5절 결정을 `docs/DESIGN.md` 5절에 옮겨 적는다.

- 격자 규칙: **성긴 낱말퍼즐 방식.** 배치한 단어만 유효. 우연히 인접해 생기는 2칸 이상 연속은 금지. 검은 칸 개수 제한 없음.
- 단어 길이 2~5음절.
- 고립 단어(다른 단어와 교차 없음) 맵당 최대 1개. 나머지는 전부 연결(하나의 연결 요소).
- 레벨 스펙은 Dart 상수 테이블.
- 통계 점수 산식 초안: `score = 정답수 - 오답수 * 2`. 코어는 낮은 순, 동점 랜덤.

## 산출물 (다른 단계와의 계약)

`app/lib/domain/` 아래. 플랫폼 import(`dart:io`, `flutter/*`, drift) 금지.

```
domain/
├─ model/
│  ├─ word_entry.dart      표제어, 음절 리스트, tier, pos
│  ├─ level_spec.dart      격자 W×H, 코어 (tier, count), 채움 [(tier, count)], 시도 예산
│  ├─ puzzle.dart          Cell 격자, List<PlacedWord>(위치·방향·isCore), seed
│  └─ submit_result.dart   단어별 정답/오답/빈칸, 총점
├─ repository/
│  └─ word_repository.dart 추상 인터페이스 (아래)
├─ generator/
│  ├─ grid_generator.dart  Puzzle generate(LevelSpec, WordRepository, int seed)
│  ├─ core_placer.dart     코어 교차 배치
│  ├─ filler.dart          빈 슬롯 채움
│  └─ grid_rules.dart      인접·연속·연결성 검증
├─ scoring/
│  └─ scorer.dart          SubmitResult score(Puzzle, Map<cell, String> answers)
└─ levels.dart             const List<LevelSpec>
```

`WordRepository` 인터페이스 (3단계가 구현):

```dart
abstract class WordRepository {
  /// 패턴 질의. fixed = {자리index: 음절}. 예: length 3, {1: '가'} → ?가?
  Future<List<WordEntry>> findByPattern({
    required int length,
    required Set<int> tiers,
    Map<int, String> fixed = const {},
    Set<String> exclude = const {},
    int limit = 50,
  });

  /// 코어 후보. 통계 점수 낮은 순, 동점 랜덤. count보다 많이 돌려주면 생성기가 고른다.
  Future<List<WordEntry>> coreCandidates({
    required int tier,
    required int count,
    required int seed,
  });
}
```

동기/비동기: DB 접근이 비동기이므로 `Future`. 더미 구현은 즉시 완료되는 Future.

## 알고리즘 방향

1. **코어 배치.** 코어 후보 N개 중 `count`개 선택. 첫 코어를 중앙 근처 가로로. 다음 코어부터는 기존 배치 단어와 **공유 음절**이 있는 위치에 수직 교차 배치. 공유 음절 없으면 고립 슬롯 사용(1회만), 그것도 안 되면 후보 교체. 후보 소진 시 실패.
2. **채움.** 배치된 글자를 지나는 빈 슬롯(길이 2~5)을 열거. 슬롯마다 `findByPattern` → 채움 티어 할당량에 맞는 단어를 랜덤 선택 → `grid_rules` 검증 → 배치. 할당량 다 채우면 종료. 슬롯 후보 없으면 마지막 배치 되감기(백트래킹). 되감기 예산 초과 시 실패.
3. **재시도.** 실패 시 seed+1로 전체 재시작. `LevelSpec.maxAttempts` 초과 시 `GenerationFailed` 예외.
4. **결정성.** 같은 (spec, repository 내용, seed) → 같은 Puzzle. 랜덤은 전부 `Random(seed)` 에서만.

## 더미 사전

- 음절 풀 40개 정도(가 나 다 … 자주 쓰는 완성형)에서 2~5음절 합성어를 수천 개 생성. 티어는 랜덤 분포(피라미드).
- 음절 풀이 작아야 패턴이 잘 맞아서 알고리즘 검증에 유리. 실데이터는 훨씬 성기다 — 3단계에서 재측정.
- 별도로 실제 한국어 단어 200개 손수 리스트도 하나 둔다(눈으로 결과 볼 용도).

## 테스트

`app/test/domain/`

- 결정성: 동일 seed 두 번 → 동일 결과.
- 규칙: 모든 가로·세로 연속(2칸 이상)이 PlacedWord와 일치. 고립 단어 1개 이하. 나머지 연결.
- 할당량: 코어 개수·티어, 채움 티어별 개수 일치.
- 채점: 빈칸 = 오답, 부분 정답 없음, 재제출 시 결과 동일.
- **실패율 하네스**: `dart run tool/measure.dart` 형태. 레벨 스펙 × 1000 seed → 실패율, 평균 시도 횟수, 평균 생성 시간 출력. 결과를 `docs/reports/01-dummy-failure.md` 에 붙인다.

## 완료 기준 (DoD)

1. 테스트 전부 통과.
2. 더미 사전에서 `levels.dart` 전 레벨 실패율 **1% 미만**.
3. 데스크톱 VM에서 퍼즐 1개 생성 **200ms 미만** (폰에서 5배 느려도 1초).
4. `domain/` 안에 플랫폼 import 0 (`dart analyze` + grep으로 확인).
5. 인터페이스(`WordRepository`, `LevelSpec`, `Puzzle`, `SubmitResult`) 시그니처를 이 문서에 반영해 확정.

## 범위 밖

- 실제 사전 데이터, DB, UI, 힌트 텍스트(뜻풀이는 3단계에서 `sense`로 붙임).
- 성능 최적화는 DoD 수치만 만족하면 멈춘다.

## 리스크

- 채움 단계에서 티어 할당량이 좁으면(예: 5티어만 3개) 후보가 없어 백트래킹 폭발. → 할당량을 "정확히"가 아니라 "이상/범위"로 두는 완화책을 `LevelSpec`에 옵션으로 준비.
- 격자가 클수록(9×9 이상) 연결성 유지가 어려움. 1차 레벨은 5×5 ~ 8×8 로 제한.
