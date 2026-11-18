# 전통 보드게임

## 실행

Node.js 24와 npm을 설치한 뒤 실행합니다.

```bash
npm ci
npm run build
QA_LOGIN=1 npm start
```

서버에 원격 접속할 때는 다음 명령으로 SSH 포트 포워딩(로컬 포트를 서버에 연결)을 설정하고 `http://localhost:8840`에 접속합니다.

```bash
ssh -L 8840:127.0.0.1:8840 <서버>
```

## Docker 실행 (개발 서버)

개발 서버에서는 Docker Compose로 실행합니다. 포트는 `127.0.0.1:8840`과 사설 주소 `10.8.0.1:8840`에만 연결됩니다. 로그인 키는 자격 증명 파일 `~/docs/.env`의 `WEB_GAME_` 접두 키에서 읽으며, `compose.yaml`에 나열한 변수만 컨테이너에 들어갑니다.

```bash
docker compose --env-file ~/docs/.env up -d --build
docker compose down        # 중지 (DB 볼륨 web-game-data는 남는다)
```

- QA 담당자: `http://10.8.0.1:8840`에 접속해 QA 로그인을 씁니다.
- 실제 로그인(구글·카카오·네이버·GitHub): SSH 포트 포워딩 후 `http://localhost:8840`으로 접속합니다. 제공자 리디렉션 규칙상 `localhost`에서만 동작합니다.

## 로그인 설정

사용할 설정 키 이름은 다음과 같습니다. 설정하지 않은 제공자는 표시되지 않습니다.

- `WEB_GAME_GOOGLE_CLIENT_ID`
- `WEB_GAME_KAKAO_CLIENT_ID`
- `WEB_GAME_KAKAO_CLIENT_SECRET`
- `WEB_GAME_NAVER_CLIENT_ID`
- `WEB_GAME_NAVER_CLIENT_SECRET`
- `WEB_GAME_GITHUB_CLIENT_ID`
- `WEB_GAME_GITHUB_CLIENT_SECRET`

각 제공자 콘솔에 다음 주소를 등록합니다.

- 구글 JavaScript 원본: `http://localhost:8840`
- 카카오 리디렉션 URI(로그인 후 돌아갈 주소): `http://localhost:8840/auth/kakao/callback`
- 네이버 리디렉션 URI: `http://localhost:8840/auth/naver/callback`
- GitHub 리디렉션 URI: `http://localhost:8840/auth/github/callback`

QA 로그인(테스트용 로그인)을 끄려면 `WEB_GAME_QA_LOGIN=0`을 설정하고 컨테이너를 다시 만듭니다. 실제 제공자 로그인은 앱 등록 후 `http://localhost:8840`에서 각각 확인해야 합니다.

## 검증

```bash
npm run lint
npm run typecheck
npm test
npx playwright install chromium
npm run e2e
```

호스트에 브라우저 실행 라이브러리가 없으면(예: `libnspr4.so` 없음) Playwright 공식 이미지로 E2E를 실행합니다.

```bash
docker run --rm --network host --user "$(id -u):$(id -g)" -e HOME=/tmp -v "$PWD":/work -w /work mcr.microsoft.com/playwright:v1.65.1-noble npm run e2e
```
