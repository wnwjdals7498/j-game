# 0단계 — 환경 구축 · 스켈레톤 · 데이터 신청

규모: S · 선행: 없음 · 다음: 1단계(domain), 2단계(tools) 병행

## 목표

이 PC에서 **Flutter 앱을 안드로이드 기기에 빌드·설치**하고, **Python ETL을 venv에서 실행**할 수 있는 상태. 프로젝트 골격을 DESIGN.md 3절 구조대로 만든다. 데이터 이용 신청을 걸어 둔다.

## 현재 상태 (2026-09-16 점검)

- 있음: Python 3.13, Git, VS Code, JRE 21
- 없음: Flutter, Dart, Android SDK, adb, Android Studio, JDK, sqlite3 CLI

## 작업 항목

### A. 데이터 이용 신청 (첫날, 승인 대기 발생 가능)

- [ ] 한국어기초사전(krdict.korean.go.kr) 회원가입 → "사전 자료 내려받기(전체)" 신청. XML 포맷.
- [ ] 표준국어대사전(stdict.korean.go.kr) 회원가입 → 전체 자료 이용 신청.
- [ ] 국립국어원 자료실에서 **현대 국어 사용 빈도 조사 2** 파일 확보 (xlsx/hwp 형식 예상 → csv 변환은 2단계).
- [ ] **한국어 학습용 어휘 목록(5,965)** 파일 확보.
- [ ] 받은 원본은 `tools/raw/` 에 두고 `.gitignore` 처리 (용량·라이선스 이유로 커밋 안 함).
- [ ] 각 자료의 라이선스 문구·출처 표기 요구사항을 `docs/LICENSES.md` 초안에 기록.

### B. 안드로이드 툴체인

- [ ] Android Studio 설치. 설치 시 Android SDK, Platform-Tools(adb), 에뮬레이터, 동봉 JDK가 함께 들어옴.
- [ ] SDK Manager에서 최신 안정 API 레벨 + Build-Tools + Command-line Tools 설치.
- [ ] 환경변수 `ANDROID_HOME` 설정, `platform-tools`를 PATH에 추가.
- [ ] 테스트 기기 준비: 실기기(USB 디버깅 켜기) 또는 에뮬레이터 AVD 1개.
- 주의: 현재 JRE 21은 JDK가 아니다. Gradle은 JDK가 필요하다. Android Studio 동봉 JDK를 쓰고 `flutter config --jdk-dir=<Android Studio 경로>/jbr` 로 지정.

### C. Flutter

- [ ] Flutter SDK stable 설치 (zip 또는 winget). PATH 추가.
- [ ] `flutter doctor` → Android toolchain, Chrome, VS Code 항목 모두 초록. `flutter doctor --android-licenses` 동의.
- [ ] VS Code에 Flutter/Dart 확장 설치.
- [ ] Windows 개발자 모드 켜기 (심볼릭 링크 플러그인 빌드용).

### D. Python

- [ ] `py -3.13 -m venv tools/.venv` 생성. `python3`(3.6.8) 절대 사용 금지.
- [ ] `tools/requirements.txt` 초기값: `pytest` 만. 표준 라이브러리(`xml.etree`, `sqlite3`, `csv`, `json`)로 시작. `lxml`은 대용량 XML 파싱이 느릴 때만 추가.
- [ ] `tools/README.md`에 실행 방법 한 줄.

### E. 프로젝트 골격

```
j-game/
├─ app/                 flutter create app --platforms android,web --org <역도메인>
│  ├─ lib/
│  │  ├─ domain/        순수 Dart. 플랫폼 import 금지
│  │  ├─ data/
│  │  ├─ ui/
│  │  └─ main.dart
│  ├─ assets/           words.sqlite 자리 (2단계 산출물)
│  ├─ web/              sqlite3.wasm, drift_worker.js (3단계에서 추가)
│  └─ test/
├─ tools/
│  ├─ raw/              .gitignore
│  ├─ build/            중간 산출물, .gitignore
│  └─ schema.sql
└─ docs/
```

- [ ] `flutter create` 후 `lib/domain`, `lib/data`, `lib/ui` 빈 디렉터리 + 각 폴더에 `.gitkeep`.
- [ ] `pubspec.yaml`에 의존성 후보 주석으로 기록만 (실제 추가는 해당 단계에서): `drift`, `drift_flutter`, `sqlite3_flutter_libs`, `path_provider`, `http`, `crypto`. 개발: `drift_dev`, `build_runner`, `test`.
- [ ] `.gitignore`: Flutter 기본 + `tools/raw/`, `tools/build/`, `tools/.venv/`, `*.keystore`, `key.properties`.
- [ ] 브랜치 정리: 현재 `master`, 기본 브랜치는 `main`. `git branch -M main` 으로 통일.
- [ ] 첫 커밋: docs + 골격.

### F. 검증 빌드

- [ ] `flutter run` 으로 실기기/에뮬레이터에서 기본 카운터 앱 실행.
- [ ] `flutter build apk --debug` → `app/build/app/outputs/flutter-apk/app-debug.apk` 생성 확인.
- [ ] `flutter run -d chrome` 웹 실행 확인.
- [ ] `app/`에서 `dart test` 가 (빈 테스트라도) 통과.
- [ ] `tools/.venv` 활성화 후 `python -c "import sqlite3"` 확인.

## 완료 기준 (DoD)

1. `flutter doctor` 경고 0.
2. 안드로이드 기기(또는 에뮬레이터)에 디버그 APK가 설치되고 실행된다.
3. 같은 코드가 Chrome에서 실행된다.
4. `dart test`, `python -m pytest tools` (빈 테스트) 둘 다 통과.
5. 데이터 이용 신청 4건 모두 접수 상태 이상. (승인은 2단계 진입 조건)
6. 첫 커밋 완료.

## 리스크 · 메모

- Android Studio + SDK + Flutter 합쳐 10GB 이상. 디스크 확인.
- 회사 네트워크/프록시면 Gradle 의존성 다운로드가 막힐 수 있다. 첫 빌드는 오래 걸린다(10분 이상 정상).
- 데이터 승인이 늦으면 2단계 착수만 밀린다. 1단계는 영향 없음.
