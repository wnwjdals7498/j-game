# 웹 전용 drift wasm 자산

`sqlite3.wasm`, `drift_worker.js` — drift wasm(웹 sqlite3)이 브라우저에서
쓰기 위해 필요한 바이너리/워커 파일. `app/lib/data/db/open_web.dart` 가
`WasmDatabase.open()` 에서 이 두 파일을 상대 경로(`sqlite3.wasm`,
`drift_worker.js`)로 참조한다 (03-02).

## 출처 및 버전

- drift 버전: **2.35.0** (`app/pubspec.lock` 의 `drift` 패키지 버전과 정확히 일치해야 한다)
- `dart run drift_dev make-web-assets` 명령은 이 drift 버전에 존재하지 않아
  (03-02 "막히면" 절에서 예고된 경로) 대신 GitHub 릴리스에서 직접 받았다.
- 다운로드 출처: https://github.com/simolus3/drift/releases/tag/drift-2.35.0
  - https://github.com/simolus3/drift/releases/download/drift-2.35.0/sqlite3.wasm
  - https://github.com/simolus3/drift/releases/download/drift-2.35.0/drift_worker.js
- 받은 날짜: 2026-09-17

## 갱신 방법

`app/pubspec.yaml` 에서 `drift` 패키지 버전을 올릴 때마다, 위 릴리스 태그를
새 버전(`drift-<version>`)으로 바꿔 **두 파일을 같은 릴리스에서 함께** 다시
받는다. `sqlite3.wasm` 과 `drift_worker.js` 의 버전이 서로 다르면 웹에서
DB가 열리지 않거나 원인 불명의 오류가 날 수 있다.

이 파일(README.md)의 버전 기록도 같이 갱신한다.
