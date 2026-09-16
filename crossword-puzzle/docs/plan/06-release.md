# 6단계 — 배포

규모: S · 선행: 5단계

## 목표

서명된 Android App Bundle(AAB)을 만들고 스토어 등록에 필요한 준비물을 갖춘다. DB 릴리스 절차를 스크립트로 고정한다.

## 작업 항목

### A. 앱 식별·버전
- applicationId(역도메인) 확정. 이후 변경 불가.
- `pubspec.yaml` `version: 1.0.0+1`. 빌드 번호는 배포마다 +1.
- 앱 이름·아이콘·스플래시. 아이콘은 `flutter_launcher_icons` 등으로 생성.

### B. 서명
- 업로드 키스토어 생성 (`keytool`). **저장소 밖에 보관**, 백업 2곳.
- `android/key.properties` 작성, `.gitignore` 확인 (0단계에서 이미 제외).
- `android/app/build.gradle` release signingConfig 연결.
- Play App Signing 사용 (구글이 앱 서명 키 관리, 우리는 업로드 키만).

### C. 빌드
- `flutter build appbundle --release`.
- 크기 점검: assets의 10MB sqlite 포함해 AAB 30MB 안팎 예상. 초과하면 원인 확인.
- release 빌드로 실기기 설치 테스트 (`flutter build apk --release` → adb install). 디버그와 달리 tree-shaking·난독화로 깨지는 것 확인.

### D. 스토어 준비물
- 스크린샷(폰 세로 최소 2장), 아이콘 512, 피처 그래픽 1024×500.
- 짧은 설명·긴 설명. 사전 출처·라이선스 문구를 설명에도 넣는다(CC BY-SA 표기 의무).
- 개인정보 처리방침 URL: 수집 데이터 없음(통계는 기기 내부만, 네트워크는 DB 다운로드만). 한 페이지 정적 문서로 GitHub Pages 등에 게시.
- Play Console 데이터 보안 양식: 수집 없음으로 작성.
- 콘텐츠 등급 설문.

### E. DB 릴리스 절차 고정
- `tools/release_db.py`: `words.sqlite` → sha256·size 계산 → `manifest.json` 생성 → (선택) `gh release create db-v{N}` 으로 업로드.
- 절차를 `docs/RELEASE.md`에 5줄로 기록: 빌드 → 리포트 검수 → 태그 → 업로드 → 앱에서 갱신 확인.

### F. CI (선택, 여유 있으면)
- GitHub Actions: push 시 `dart analyze`, `dart test`, `flutter build apk --debug`. 서명 빌드는 로컬에서.

## 완료 기준 (DoD)

1. 서명된 AAB가 생성되고 release APK가 실기기 2대 이상에서 정상 동작.
2. 키스토어 백업 완료, 저장소에 비밀 없음(`git log -p`로 확인).
3. 스토어 준비물 전부 준비, 라이선스 문구 포함.
4. `docs/RELEASE.md`, `tools/release_db.py` 존재하고 한 번 실제 실행.
5. 내부 테스트 트랙 업로드 성공.

## 리스크

- Play Console 신규 개발자 계정은 등록 후 **14일 이상 20명 비공개 테스트** 요건이 있을 수 있다(정책 변동). 배포 일정에 반영.
- 키스토어 분실 = 앱 업데이트 불가. Play App Signing을 쓰면 업로드 키는 재발급 가능하므로 반드시 사용.
