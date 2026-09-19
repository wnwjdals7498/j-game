# UI 가이드 (7단계 UI v2 디자인 언어 계약)

작성일: 2026-09-18
상위: [PLAN.md](PLAN.md) 7단계 · [plan/07-ui-v2.md](plan/07-ui-v2.md)
적용 범위: `app/lib/ui/**` 전체. 7단계 모든 세부 문서(07-01~07-08)가 이 문서를 계약으로 삼는다.

이 문서는 **"어떻게 보여야 하는가"를 한 곳에 고정**한다. 화면 문서(07-03~07-07)는 여기 정의된 토큰·모션·이펙트 ID만 참조하고, 값을 새로 만들지 않는다. 값을 바꿔야 하면 이 문서를 먼저 고치고 07-02의 토큰 파일을 따라 고친다.

---

## 1. 톤: NYT Games

참조 대상은 The New York Times Games(Crossword, Wordle, Connections)의 UI 언어다. 그 특징을 이 프로젝트 말로 옮기면 다음 여섯 줄이다.

| 원칙 | 뜻 | 하지 않는 것 |
|---|---|---|
| **종이 위의 잉크** | 흰 바탕, 검정 글자, 검정 격자선. 색은 강조 2개(노랑·하늘색)로 끝낸다 | 그라데이션, 파스텔 배경, 카드 그림자 |
| **타이포가 장식** | 굵은 제목(700)과 넉넉한 여백이 화면을 만든다 | 일러스트·아이콘으로 빈 곳 채우기 |
| **평면** | 구분은 1px 선과 여백으로. 입체감 없음 | elevation, 그림자, 유리 효과 |
| **정확한 사각형** | 격자 셀은 모서리 0. 버튼만 완전한 알약형(pill) | 둥근 셀, 중간 라운드 |
| **모션은 짧고 확실하게** | 80~400ms. 한 번 움직이고 멈춘다 | 반복 애니메이션(펄스·반짝임), 바운스 남용 |
| **축하는 절제** | 결과 화면에서 한 번, 1초 안에 끝난다 | 전면 컨페티, 사운드 폭발 |

한국어 조정: 영문 대문자 레이블(NYT의 `ACROSS`) 대신 **굵은 600 + 자간 0.4**로 레이블 감을 낸다. 세리프는 쓰지 않는다(한국어 세리프는 격자 안에서 무겁다).

---

## 2. 디자인 토큰

### 2.1 방법론

- 토큰은 **의미 이름**(semantic)으로만 부른다. `yellow`가 아니라 `cellCursor`.
- 구현은 Flutter `ThemeExtension` 두 개다: `GameColors`(색), `GameMotion`(모션). 간격·반지름·타입 스케일은 `const` 클래스(`GameSpace`, `GameRadius`, `GameType`).
- `lib/ui/theme/` 밖에서는 **`Color(0x…)`, `Colors.*`, `Duration(milliseconds: …)` 리터럴을 쓰지 않는다.** 07-01의 불변 조건 스크립트가 이를 감시한다(INV-05, INV-12).
- Material `ColorScheme`도 같은 값으로 채운다(`AppBar`, `TextField`, `Dialog` 등 Material 위젯이 자동으로 톤을 따르게). 화면 코드는 `GameColors`를 우선 쓰고, Material 위젯 내부 색은 `ColorScheme`에 맡긴다.
- 파일 위치: `app/lib/ui/theme/tokens.dart`(값), `app/lib/ui/theme/app_theme.dart`(ThemeData 조립), `app/lib/ui/theme/motion.dart`(GameMotion + 감소 모션 헬퍼).

### 2.2 색 토큰

| 토큰 | 용도 | 라이트 | 다크 |
|---|---|---|---|
| `surface` | 화면 배경 | `#FFFFFF` | `#121212` |
| `surfaceAlt` | 힌트 바·설정 구획 등 한 톤 낮은 면 | `#F5F5F3` | `#1C1C1C` |
| `ink` | 본문·제목·아이콘, **기본 버튼 배경** | `#121212` | `#F2F2F2` |
| `inkMuted` | 보조 텍스트, 셀 번호 | `#6E6E6E` | `#A3A3A3` |
| `line` | 구분선, 아웃라인 버튼 테두리 | `#DEDEDE` | `#2E2E2E` |
| `accent` | **커서 셀**(현재 탭한 칸), 강조 배지 | `#FFDA00` | `#E5C400` |
| `accentSoft` | **선택 단어** 셀 배경 | `#A7D8FF` | `#2B5C8A` |
| `success` | 정답 표시(점·아이콘·텍스트) | `#1B7F3B` | `#58B368` |
| `danger` | 오답·빈칸 표시, 오류 문구 | `#C62828` | `#EF5350` |
| `gridLine` | 격자 셀 테두리 | `#121212` | `#4A4A4A` |
| `cellFill` | 일반 셀 배경 | `#FFFFFF` | `#1E1E1E` |
| `cellBlocked` | 검은 칸 | `#121212` | `#050505` |
| `cellCoreMark` | 코어 단어 셀 안의 원형 마크 | `#8A8A8A` | `#8A8A8A` |
| `cellInk` | 셀 안 음절(일반·선택 단어 위) | `#121212` | `#F2F2F2` |
| `cellInkOnAccent` | 커서 셀(노랑) 위 음절 | `#121212` | `#121212` |

`ColorScheme` 매핑: `primary = ink`, `onPrimary = surface`, `surface = surface`, `onSurface = ink`, `onSurfaceVariant = inkMuted`, `outline = line`, `outlineVariant = line`, `error = danger`, `secondaryContainer = accentSoft`, `tertiary = accent`.

### 2.3 대비 계약 (07-02 테스트가 계산으로 검증)

WCAG 상대 휘도 공식으로 계산한다. 아래 쌍이 두 테마 모두에서 기준을 넘어야 한다.

| 전경 / 배경 | 최소 비율 | 이유 |
|---|---|---|
| `ink` / `surface` | 7.0 | 본문 |
| `inkMuted` / `surface` | 4.5 | 보조 텍스트 |
| `inkMuted` / `surfaceAlt` | 4.5 | 힌트 바 헤더 |
| `cellInk` / `cellFill` | 7.0 | 격자 음절 |
| `cellInk` / `accentSoft` | 4.5 | 선택 단어 위 음절 |
| `cellInkOnAccent` / `accent` | 4.5 | 커서 셀 위 음절 |
| `surface` / `ink` | 7.0 | 기본 버튼 글자 |
| `inkMuted` / `cellFill` | 3.0 | 셀 번호(작은 글자지만 굵음) |

### 2.4 타이포그래피

폰트: **Pretendard** static 3종(`Regular 400`, `SemiBold 600`, `Bold 700`), SIL Open Font License 1.1. `app/assets/fonts/`에 번들하고 `pubspec.yaml` `fonts:`에 등록한다. 대안으로 Noto Sans KR(OFL)을 써도 되며, 그 경우 이 표의 굵기 매핑은 같다. 라이선스 원문은 `docs/LICENSES.md`에 절을 추가한다(`tools/build_sqlite.py`가 `app/assets/LICENSES.md`로 복사).

| 스케일 이름 | 크기/굵기/행간 | 쓰는 곳 |
|---|---|---|
| `display` | 34 / 700 / 1.1 | 결과 화면 점수, 홈 히어로 레벨 이름 |
| `title` | 22 / 700 / 1.2 | 화면 제목, 결과 헤더 |
| `heading` | 17 / 600 / 1.3 | 구획 제목, 레벨 카드 이름 |
| `body` | 16 / 400 / 1.5 | 힌트 본문, 뜻풀이 |
| `label` | 13 / 600 / 1.2 / 자간 0.4 | "가로 3", "3글자", 배지, 통계 라벨 |
| `caption` | 12 / 400 / 1.3 | 보조 안내, 유의어 |
| `cellSyllable` | 셀 × 0.55 / 600 / 1.0 | 격자 음절 |
| `cellNumber` | 셀 × 0.22 / 600 / 1.0 | 격자 번호 |

`Theme.textTheme`에도 같은 값을 매핑한다(`displaySmall = display`, `titleLarge = title`, `titleMedium = heading`, `bodyLarge = body`, `labelLarge = label`, `bodySmall = caption`).

### 2.5 간격·반지름·선

| 토큰 | 값 |
|---|---|
| `GameSpace.xs / s / m / l / xl / xxl` | 4 / 8 / 12 / 16 / 24 / 32 |
| 화면 좌우 여백 | `GameSpace.l`(16) |
| `GameRadius.cell` | 0 |
| `GameRadius.panel` | 12 (힌트 바, 레벨 카드, 바텀 시트 상단) |
| `GameRadius.pill` | 999 (모든 버튼, 배지) |
| 구분선 두께 | 1 (`line` 색) |
| 격자 테두리 두께 | 1 (`gridLine`), 격자 외곽 2 |
| elevation | 항상 0 |

버튼 규격: 높이 52, 알약형. 기본 = `ink` 배경 + `surface` 글자(700). 보조 = 투명 배경 + `line` 1.5px 테두리 + `ink` 글자(600). 비활성 = `surfaceAlt` 배경 + `inkMuted` 글자.

---

## 3. 모션 시스템

### 3.1 지속 시간·곡선 토큰 (`GameMotion`)

| 토큰 | 값 | 용도 |
|---|---|---|
| `instant` | 80ms | 커서 셀 이동, 버튼 눌림 |
| `fast` | 150ms | 선택 단어 하이라이트 이동, 배지 교체 |
| `base` | 240ms | 화면 전환, 힌트 바 크로스페이드, 버튼 상태 색 변화 |
| `slow` | 400ms | 결과 행 순차 등장 전체 길이 기준 |
| `celebrate` | 900ms | 점수 카운트업, 레벨 해제 연출 |
| `curveStandard` | `Curves.easeOutCubic` | 대부분 |
| `curveEmphasized` | `Curves.easeInOutCubicEmphasized` | 화면 전환 |
| `curvePop` | `Curves.easeOutBack` | 셀 채움 팝 |

### 3.2 감소 모션

`MediaQuery.disableAnimationsOf(context)`가 true면 `GameMotion.of(context)`가 **모든 지속 시간을 `Duration.zero`로** 돌려준다. 화면 코드는 항상 `GameMotion.of(context).fast`처럼 토큰을 통해서만 시간을 얻는다. 이 규칙이 있어야 접근성 설정 하나로 모션이 전부 꺼진다(INV-12).

### 3.3 이펙트 카탈로그

모든 움직임은 아래 ID 중 하나다. 여기 없는 이펙트를 넣고 싶으면 먼저 이 표에 추가한다.

| ID | 이름 | 어디서 | 동작 | 시간/곡선 | 구현 메모 |
|---|---|---|---|---|---|
| E-01 | 셀 채움 팝 | 격자, 음절이 새로 들어간 셀 | 음절 스케일 0.7 → 1.0 | `fast` / `curvePop` | 셀별 진행값 맵을 `GridPainter`에 전달, 07-03 |
| E-02 | 선택 이동 | 격자, 선택 단어가 바뀔 때 | 하이라이트 사각형이 이전 위치에서 새 위치로 보간 | `fast` / `curveStandard` | 이전·현재 `PlacedWord` 두 개의 바운딩 Rect를 lerp, 07-03 |
| E-03 | 커서 이동 | 격자, 탭한 셀 | `accent` 채움이 즉시 이동(보간 없음), 알파 0 → 1 | `instant` | 07-03 |
| E-04 | 힌트 크로스페이드 | 힌트 바, 단어 변경 | 이전 텍스트 페이드아웃 + 새 텍스트 페이드인·4dp 상승 | `base` / `curveStandard` | `AnimatedSwitcher`, 07-04 |
| E-05 | 제출 버튼 활성 | 퍼즐 화면 하단 | 모든 칸이 채워지는 순간 보조 → 기본 스타일로 색 전환 | `base` | `AnimatedContainer`, 07-04 |
| E-06 | 점수 카운트업 | 결과 헤더 | 0 → 점수, 정답 링 0 → 비율 | `celebrate` / `curveStandard` | `TweenAnimationBuilder`, 07-06 |
| E-07 | 결과 행 순차 등장 | 결과 목록 | 행마다 40ms 간격, 알파 0 → 1 + 8dp 상승 | 행당 `fast`, 총 `slow` 상한 | 12행 넘으면 간격을 줄여 총 400ms 유지, 07-06 |
| E-08 | 레벨 해제 연출 | 결과 헤더, 첫 제출로 해제된 경우만 | `ink`·`accent`·`accentSoft` 사각 조각 24개가 헤더 위에서 낙하·회전, 1회 | `celebrate` | 자체 `CustomPainter`, 외부 패키지 없음, 07-06 |
| E-09 | 화면 전환 | 모든 라우트 | 페이드 스루(이전 화면 페이드아웃 → 새 화면 페이드인 + 2% 스케일) | `base` / `curveEmphasized` | `PageTransitionsTheme`에 커스텀 빌더, 07-07 |
| E-10 | 레벨 카드 해제 | 홈, 해제된 직후 첫 표시 | 자물쇠 → 번호로 플립 | `base` | `AnimatedSwitcher` + 회전 트랜지션, 07-05 |
| E-11 | 로딩 선 | 부트스트랩·퍼즐 생성 대기 | 상단 2dp 선형 진행 표시 | 내장 | `LinearProgressIndicator(minHeight: 2)`, 원형 스피너 대체, 07-07 |
| E-12 | 시트 등장 | 튜토리얼·제출 확인 | 바텀 시트 하단에서 상승 | `base` / `curveEmphasized` | `showModalBottomSheet` 기본 + 테마, 07-04 |

### 3.4 햅틱·사운드

| ID | 트리거 | 구현 |
|---|---|---|
| H-01 | 셀 탭으로 단어 선택 변경 | `HapticFeedback.selectionClick()` |
| H-02 | 한 단어의 마지막 음절이 채워짐 | `HapticFeedback.lightImpact()` |
| H-03 | 제출 확정 | `HapticFeedback.mediumImpact()` |
| S-01 | 셀 탭 (설정 "효과음" 켜진 경우만, 기본 꺼짐) | `SystemSound.play(SystemSoundType.click)` |

햅틱은 설정으로 끄지 않는다(시스템 설정이 이미 있다). 사운드는 `SettingsModel.soundEnabled`로 제어하며 기본값 false. 외부 오디오 패키지는 도입하지 않는다.

---

## 4. 화면 공통 규칙

- **AppBar**: 배경 `surface`, 그림자·구분선 없음, 제목 `title` 스케일 왼쪽 정렬. 뒤로가기 아이콘은 `ink`.
- **본문 최대 폭**: 태블릿·웹에서 `560`으로 제한하고 가운데 정렬(격자 화면은 격자 폭 기준).
- **빈 상태·오류**: 아이콘 없이 `heading` 한 줄 + `body` 한 줄. 필요하면 `ink` 1.5px 모노라인 글리프 하나를 `CustomPainter`로 그린다(이미지 파일 아님).
- **스낵바**: `ink` 배경, `surface` 글자, 알약형, 하단 여백 16.
- **다이얼로그 대신 바텀 시트**: 확인·안내는 `showModalBottomSheet`(상단 반지름 `panel`). 예외: 파괴적 확인이 없으므로 `AlertDialog`는 남기지 않는다.
- **텍스트 레이블 유지**: 기존 테스트가 찾는 문구(INV-09 목록)는 글자 하나도 바꾸지 않는다.

---

## 5. 이미지 에셋

NYT 톤은 이미지를 거의 쓰지 않는다. **앱 안 UI는 전부 코드로 그린다.** 래스터 이미지는 아래 넷만 허용한다. 생성형 모델에 넘길 프롬프트는 [plan/07-08-05.image-prompts.md](plan/07-08-05.image-prompts.md)에 모아 둔다(영문). 생성 결과는 `asset/` 아래 원본, `app/assets/icon/`에 가공본을 둔다(06-01 관례).

| ID | 에셋 | 규격 | 필요 여부 |
|---|---|---|---|
| IMG-01 | 앱 아이콘 재도색 | 1024×1024 + adaptive foreground | **선택(HUMAN 결정)**. 현재 아이콘은 파랑 `#08A2FB` 배경으로 새 톤(흑·백·노랑)과 어긋난다. 바꾸면 06-01 절차로 재생성 |
| IMG-02 | 스토어 피처 그래픽 | 1024×500 | 06-04 갱신 시 |
| IMG-03 | 스토어 스크린샷 | 폰 세로 최소 2장 | **AI 생성 아님**. 07-08에서 실기기 캡처 |
| IMG-04 | 빈 상태 글리프 | 벡터(코드) | 기본은 코드로 그림. 프롬프트 문서의 IMG-04는 스케치 참고용 |

프롬프트 원문은 **[plan/07-08-05.image-prompts.md](plan/07-08-05.image-prompts.md)** 한 곳에 모여 있다. 저장소의 다른 문서에는 프롬프트를 적지 않는다 — 색 값이 갈라지는 것을 막기 위해서다. 그 문서는 팔레트 블록(2.2 라이트 열 hex), 묶음 프롬프트, IMG별 프롬프트, 생성 후 가공 절차, 검수 체크리스트를 담는다.

색 값은 2.2 토큰과 일치해야 한다. 생성 결과의 색이 어긋나면 이미지를 고치지 말고 재생성한다.

---

## 6. Non-goal (7단계에서 하지 않는 것)

| # | Non-goal | 이유 |
|---|---|---|
| N-01 | 격자 셀에 직접 타이핑하는 입력 방식으로 전환 | 04-ui "기술 결정". IME 조합 문제가 다시 열린다 |
| N-02 | 가로 모드 지원 | 격자가 정사각형이라 얻는 게 없다(04-01) |
| N-03 | 9×9 이상 격자, 스크롤·줌 | 03-06 상한 8 |
| N-04 | 게임 규칙 추가(타이머, 힌트 페널티, 진행 상태 영구 저장, 데일리 퍼즐) | 이 단계는 **표현만** 바꾼다. 규칙은 8단계 후보 |
| N-05 | 외부 애니메이션·오디오·폰트 로딩 패키지 도입 | Flutter 내장 API로 충분. 의존성 최소 |
| N-06 | `lib/domain/**`, `lib/data/**`, `lib/domain/levels.dart` 수정 | UI 단계가 알고리즘·데이터 계층을 건드리면 회귀 범위가 폭발한다 |
| N-07 | 웹 최적화 | 배포 대상 아님. 깨지지만 않으면 된다 |
| N-08 | 라이선스 화면의 마크다운 렌더링 | 04-06 결정 유지, `SelectableText` |
| N-09 | 튜토리얼 내용 확장 | 문구 유지, 표현(시트)만 바꾼다 |

---

## 7. 불변 조건 (INV) — 07-01 스크립트가 감시

`app/tool/check_invariants.dart`가 매 검증 단계에서 실행된다. 규칙은 (ID, 대상 파일, 검사)로 스크립트 안에 선언되며, 이 표와 1:1이다(한 줄이 여러 파일을 보면 스크립트에서 `INV-02a`·`INV-02b`처럼 접미사로 쪼갠다 — 접미사를 떼면 이 표의 ID와 같아야 한다). **규칙을 빼거나 바꾸면 이 표와 스크립트를 같은 커밋에서 고친다.**

| ID | 불변 조건 | 검사 방법 | 도입 |
|---|---|---|---|
| INV-01 | 세로 고정 | `lib/main.dart`에 `DeviceOrientation.portraitUp` 포함 | 07-01 |
| INV-02 | IME 입력은 하단 텍스트 필드 1개 | `lib/ui/puzzle/word_input.dart`에 `TextField`와 `committedSyllables(` 포함. `lib/ui/puzzle/grid_*.dart`에 `TextField`·`EditableText` 없음 | 07-01 |
| INV-03 | 격자에 정답 미노출 | `lib/ui/puzzle/grid_painter.dart`에 `.headword` 없음 | 07-01 |
| INV-04 | 정답·오답은 색 외 모양으로도 구분 | `grid_painter.dart`에 `drawCircle`과 `drawLine` 둘 다 포함, `result_page.dart`에 `Icons.check_circle`과 `Icons.cancel` 포함 | 07-01 |
| INV-05 | 하드코딩 색 금지 | `lib/ui/**`(단 `lib/ui/theme/**` 제외)와 `lib/main.dart`에 `Color(0x`, `Colors.` 없음(`Colors.transparent` 허용) | 07-01 |
| INV-06 | 출처·라이선스 화면 유지 | `lib/ui/settings/license_page.dart`에 `assets/LICENSES.md` 포함, `settings_page.dart`에 `'출처 및 라이선스'` 포함, `pubspec.yaml`에 `assets/LICENSES.md` 포함 | 07-01 |
| INV-07 | domain·data 무수정 | `--git-base <ref>` 인자가 주어지면 `git diff --name-only <ref> -- lib/domain lib/data`가 비어 있어야 함 | 07-01 |
| INV-08 | 보호 테스트 존재 | 스크립트 안 목록의 테스트 이름 문자열이 `test/**`에 전부 존재 | 07-01 |
| INV-09 | 사용자 문구 유지 | 아래 문구가 `lib/ui/**`에 전부 존재 | 07-01 |
| INV-10 | 격자 상한 8 | `lib/domain/levels.dart`의 `width:`·`height:` 값이 모두 ≤ 8 | 07-01 |
| INV-11 | 새 의존성 금지 | `pubspec.yaml` `dependencies:` 이름 집합이 스크립트의 허용 목록과 동일 | 07-01 |
| INV-12 | 모션 토큰 강제 | `lib/ui/**`(단 `theme/**` 제외)에 `Duration(milliseconds` 리터럴 없음 | 07-02 |
| INV-13 | 두 테마 모두 토큰 보유 | `test/ui/theme_test.dart`가 라이트·다크 `ThemeData`에서 `GameColors`·`GameMotion` 확장을 찾음 (테스트로 감시) | 07-02 |
| INV-14 | 대비 계약 | `test/ui/theme_test.dart`가 2.3 표를 계산 검증 (테스트로 감시) | 07-02 |

**INV-08 보호 테스트 목록**(현재 `test/ui`에 있는 이름 그대로. 리디자인이 이 테스트를 지우거나 이름을 바꾸면 스크립트가 실패한다):

```
탭 → 셀 변환: (cell*2.5, cell*1.5) 탭 → (row 1, col 2)
검은 칸 탭은 무시된다 (onCellTap 미호출)
격자 크기: 5×5 퍼즐 → 위젯 크기가 정사각형
shouldRepaint: 같은 입력 → false, 입력 변경 → true
레벨 1 항상 해제: 통계 없어도 탭 가능
잠금 표시: 이전 레벨 미클리어 → 자물쇠
잠긴 레벨 탭: 이동 안 함, 스낵바 안내
해제 레벨 탭: 퍼즐 화면으로, 새 seed
힌트 모드 변경: SettingsModel 저장, 재시작 후 유지
4개 자료명이 전부 보임 + assets/LICENSES.md와 동일한 문구
1. 루프 전체: 홈 → 퍼즐 → 제출 → 결과 → 다음 레벨
2. 격자 탭 → 올바른 단어 선택: 힌트 패널이 그 단어
3. 입력 → 셀 반영: 격자에 글자
5. 다시 풀기: 같은 퍼즐, 입력 초기화
9. 생성 실패: GenerationFailed → 에러 화면, 크래시 없음
교차 셀 두 번째 탭 → 세로 단어로 토글
길이 초과 차단: 3글자 자리에 4글자 입력 → 3글자로 잘림
완성형만: 조합 중 자모를 버린다
빈칸 있음: 빈칸 개수 문구 표시
재제출: isFirstSubmit == false, word_stat 불변
상태 구분: 정답/오답/빈칸 아이콘이 다름
마지막 레벨: "다음 레벨" 대신 "홈으로"
레벨 해제 조건이어도 재제출이면 안내 없음
처음 퍼즐에 들어가면 조작법 안내가 한 번 뜬다
```

**INV-09 유지 문구**:

```
제출
다시 풀기
다음 레벨
홈으로
설정
출처 및 라이선스
칸을 눌러 단어를 고르세요
이전 레벨을 클리어해야 열립니다
재제출이라 기록에 반영되지 않았습니다
모든 칸을 채웠습니다.
이렇게 플레이해요
누적 정답률
푼 단어
```

**INV-11 허용 의존성**(현재 `pubspec.yaml` `dependencies:` 그대로):

```
flutter, cupertino_icons, drift, drift_flutter, sqlite3_flutter_libs, path_provider,
provider, shared_preferences, http, crypto, connectivity_plus, package_info_plus, sqlite3
```

---

## 8. 화면별 적용 요약

| 화면 | 문서 | 핵심 변화 |
|---|---|---|
| 격자 | 07-03 | 검정 1px 격자선, 노랑 커서 셀, 하늘색 선택 단어, 코어 셀 원형 마크, E-01~E-03 |
| 퍼즐 | 07-04 | 슬림 AppBar + 진행 표시, NYT식 힌트 바(◀ 힌트 ▶) 안에 입력 필드, 제출 버튼 E-05, 튜토리얼·제출 확인은 바텀 시트, H-01~H-03 |
| 홈 | 07-05 | "이어하기" 히어로, 통계 한 줄, 레벨 카드 2열 격자, E-10 |
| 결과 | 07-06 | 점수 `display` + 정답 링 E-06, 행 E-07, 해제 연출 E-08 |
| 설정·라이선스·부트스트랩·벤치마크 | 07-07 | 토큰 적용, E-09 전환, E-11 로딩, 효과음 토글 S-01, 테마 모드 설정 |
| 검증 | 07-08 | 골든 3화면 × 2테마, 실기기 체크, 스토어 스크린샷 |
