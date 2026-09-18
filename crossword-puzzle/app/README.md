# jgame

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## 검증 3종

`app/` 에서 아래 셋을 순서대로 돌린다. 하나라도 실패하면 작업이 끝나지 않은 것이다.

```powershell
cd app
dart run tool/check_invariants.dart   # UI-GUIDE 7절 불변 조건 (INV-01~11)
flutter analyze                       # 정적 분석 0건
flutter test                          # 전체 테스트
```

- `check_invariants.dart` 는 규칙을 어기면 `PASS/FAIL/SKIP` 목록과 위반 위치를
  찍고 exit 1을 낸다. 규칙의 원본은 `docs/UI-GUIDE.md` 7절 표다.
- `--git-base <ref>` 를 주면 INV-07(`lib/domain`·`lib/data` 무수정)까지 검사한다.
  인자가 없으면 그 규칙만 SKIP으로 표시된다.
- 규칙을 추가·수정할 때는 `tool/invariants/rules.dart` 와 UI-GUIDE 7절 표를
  **같은 커밋에서** 고친다.
