# 전통 보드게임 플랫폼 + 오목 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 로그인(구글·카카오·네이버·GitHub OAuth + QA 테스트 로그인), 사람 대 사람, 사람 대 컴퓨터로 오목을 두는 웹게임을 개발 서버 Docker에서 실행한다.

**Architecture:** npm workspaces 모노레포. 순수 함수 규칙 엔진(`@jgame/engine`)을 서버와 브라우저가 함께 쓰고, 최종 판정은 Fastify 서버 하나가 한다. 대국은 WebSocket으로 상태를 보내고, 계정·세션·대국·수순은 Node 내장 SQLite(`node:sqlite`)에 저장한다. 브라우저는 Vite + React SPA다.

**Tech Stack:** Node.js 24, TypeScript 6.0.3, Fastify 5, ws, jose, React 19, Vite 8, Vitest 5, Playwright 1.65, ESLint 10 + typescript-eslint 8, Docker Compose.

**Spec:** `web-game/docs/superpowers/specs/2026-11-18-traditional-web-games-design.md`

## Global Constraints

- 모든 경로와 명령은 `web-game/` 기준이다. 런타임은 Node.js 24(서버 v24.22.2)다.
- 패키지 버전을 정확히 고정한다: `typescript@6.0.3`(`typescript-eslint@8.73.0`이 `typescript <6.1.0`만 지원하므로 7.x 금지), `fastify@5.12.8`, `@fastify/websocket@11.3.7`, `@fastify/static@10.1.11`, `@fastify/cookie@11.1.5`, `ws@8.23.0`, `@types/ws@8.18.2`, `jose@6.2.17`, `react@19.3.1`, `react-dom@19.3.1`, `@types/react@19.3.0`, `@types/react-dom@19.3.0`, `vite@8.3.8`, `@vitejs/plugin-react@6.3.0`, `vitest@5.1.0`, `jsdom@31.0.1`, `@testing-library/react@16.3.3`, `@testing-library/dom@10.4.2`, `eslint@10.15.0`, `typescript-eslint@8.73.0`, `@eslint/js@10.0.1`, `@playwright/test@1.65.1`, `@types/node@^24`.
- DB는 `node:sqlite`의 `DatabaseSync`만 쓴다. 네이티브 빌드가 필요한 SQLite 패키지는 쓰지 않는다.
- 서버 포트는 `8840`이다. Docker는 `127.0.0.1:8840`과 `10.8.0.1:8840`에만 연결한다.
- 실제 로그인 주소는 `http://localhost:8840` 하나다. 리디렉션 URI는 `http://localhost:8840/auth/kakao/callback`, `http://localhost:8840/auth/naver/callback`, `http://localhost:8840/auth/github/callback`이다. 구글은 승인된 JavaScript 원본에 `http://localhost:8840`을 등록한다.
- 실제 제공자 버튼은 요청 `Host`의 호스트 이름이 정확히 `localhost`일 때만 목록에 나온다. QA 로그인은 `QA_LOGIN=1`일 때만 동작하며, 꺼져 있으면 `/api/auth/qa`가 404를 돌려준다.
- 수의 합법 여부와 승패는 서버만 판정한다. 브라우저의 엔진 사용은 표시용이다.
- 비밀값은 환경 변수로만 받는다. 원본은 `~/docs/.env`의 `WEB_GAME_` 접두 키이며 저장소에 넣지 않는다.
- 제공자 엔드포인트(공식 문서 확인, 2026-11-18):
  - 카카오: `https://kauth.kakao.com/oauth/authorize`, `https://kauth.kakao.com/oauth/token`, `https://kapi.kakao.com/v2/user/me`(이름: `kakao_account.profile.nickname`, ID: `id`). PKCE 미지원으로 보고 `state`만 쓴다.
  - 네이버: `https://nid.naver.com/oauth2.0/authorize`, `https://nid.naver.com/oauth2.0/token`, `https://openapi.naver.com/v1/nid/me`(ID: `response.id`, 이름: `response.nickname`). `state` 필수.
  - GitHub: `https://github.com/login/oauth/authorize`, `https://github.com/login/oauth/access_token`(요청 헤더 `Accept: application/json`), `https://api.github.com/user`(ID: `id`, 이름: `name ?? login`). PKCE `S256` 사용.
  - 구글: GIS 스크립트 `https://accounts.google.com/gsi/client`, JWKS `https://www.googleapis.com/oauth2/v3/certs`, 발급자 `accounts.google.com` 또는 `https://accounts.google.com`.
- 방 코드는 6자리, 문자 집합 `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`(O·0·I·1 제외)다.
- 오목: 15×15, 흑(0)이 먼저, 가로·세로·대각선 5개 이상 연속이면 승리, 225수로 판이 차면 무승부.
- 표기는 전통 게임 이름(오목 등)만 쓴다. 상업 게임 이름·그림·규칙서 문장을 쓰지 않는다.
- 커밋 전 `npm run lint && npm run typecheck && npm test`를 통과한다. 커밋 메시지는 `<타입>: <한국어 요약>` 형식이며 `Co-Authored-By` 같은 트레일러를 붙이지 않는다.

## Review Focus

1. 같은 차례에 수가 두 번 들어오는 경우(더블클릭, 두 탭): 하나만 저장되고 두 번째는 `not_your_turn`이다. → Task 7 `rejects second move in the same turn`
2. 방을 만든 사람이 자기 방 코드로 입장하는 경우: 두 자리를 모두 차지하지 않고 같은 대국을 돌려준다. → Task 7 `creator joining own room gets same game`
3. 대국 중 서버 재시작: 수순 테이블에서 상태를 복원하고 이어서 둘 수 있다. → Task 7 `restores game from db after restart`
4. WebSocket으로 깨진 JSON이나 모르는 메시지가 오는 경우: `bad_request` 오류를 보내고 연결은 유지한다. → Task 8 `malformed message keeps connection`
5. 대국 참가자가 아닌 사람이 대국을 구독하거나 수를 두는 경우: `not_player`로 거부한다(관전은 비목표). → Task 8 `non-player cannot subscribe`

---

## 파일 구조

```text
web-game/
├─ package.json                # workspaces, 공통 스크립트
├─ tsconfig.base.json · tsconfig.json(참조 묶음)
├─ eslint.config.js · vitest.config.ts
├─ packages/engine/            # @jgame/engine: 규칙 계약, 오목, 봇, 게임 목록
├─ packages/protocol/          # @jgame/protocol: HTTP·WebSocket 공용 타입
├─ apps/server/                # Fastify 서버
│  └─ src/{config,db,app,main}.ts, repos/, auth/, play/
├─ apps/web/                   # Vite + React SPA
│  └─ src/{main.tsx,App.tsx,api.ts,useGameSocket.ts}, pages/, boards/
├─ e2e/                        # Playwright
├─ Dockerfile · compose.yaml · .dockerignore · README.md
└─ docs/superpowers/{specs,plans}/
```

---

### Task 1: 작업 공간과 오목 규칙 엔진

**Files:**
- Create: `package.json`, `tsconfig.base.json`, `tsconfig.json`, `eslint.config.js`, `vitest.config.ts`, `.gitignore`
- Create: `packages/engine/package.json`, `packages/engine/tsconfig.json`, `packages/engine/src/types.ts`, `packages/engine/src/games/omok.ts`, `packages/engine/src/index.ts`
- Test: `packages/engine/test/omok.test.ts`

**Interfaces:**
- Produces:
  - `type Player = 0 | 1`
  - `type Outcome = { kind: "ongoing" } | { kind: "win"; winner: Player } | { kind: "draw" }`
  - `interface GameRules<State, Move, Options = void>`: 설계 6.2의 계약 그대로 (`id`, `initialState`, `currentPlayer`, `isLegal`, `legalMoves`, `applyMove`, `outcome`). `applyMove`는 불법 수에 `IllegalMoveError`를 던진다.
  - `class IllegalMoveError extends Error`
  - `const OMOK_SIZE = 15`, `type OmokMove = { x: number; y: number }`, `interface OmokState { board: (Player | null)[]; next: Player; moveCount: number; lastMove: OmokMove | null; winner: Player | null }`(`board`는 길이 225, 인덱스 `y * 15 + x`)
  - `const omok: GameRules<OmokState, OmokMove>`

- [ ] **Step 1: 작업 공간 설정 파일 작성**

루트 `package.json`: `"private": true`, `"type": "module"`, `"workspaces": ["packages/*", "apps/*"]`, 스크립트 `lint`(`eslint .`), `typecheck`(`tsc -b`), `test`(`vitest run`), `build`(`tsc -b && npm run build -w @jgame/web`), `e2e`(`playwright test -c e2e/playwright.config.ts`), `start`(`node apps/server/dist/main.js`). 개발 의존성은 Global Constraints의 고정 버전으로 설치한다.
`tsconfig.base.json`: `strict`, `target: "ES2023"`, `module`·`moduleResolution: "NodeNext"`, `verbatimModuleSyntax`, `composite`, `declaration`, `noUncheckedIndexedAccess`.
`vitest.config.ts`: `test.projects`로 `packages/*`, `apps/server`(node 환경), `apps/web`(jsdom 환경)을 묶고, `@jgame/engine`·`@jgame/protocol`을 각 `src/index.ts`로 별칭한다.
`.gitignore`: `node_modules/`, `dist/`, `data/`, `test-results/`, `playwright-report/`, `.env*`.
작업 공간 패키지(`@jgame/engine`, 이후 `@jgame/protocol`)의 `package.json`은 `"exports": { ".": { "types": "./dist/index.d.ts", "default": "./dist/index.js" } }`로 빌드 결과를 내보낸다. 루트 `tsconfig.json`은 각 패키지·앱 `tsconfig.json`을 `references`로 묶고, 앱은 쓰는 패키지를 `references`에 넣는다.

- [ ] **Step 2: 실패하는 오목 테스트 작성** (`packages/engine/test/omok.test.ts`)

```ts
const play = (moves: [number, number][]) =>
  moves.reduce((s, [x, y]) => omok.applyMove(s, { x, y }), omok.initialState());

test("black moves first on empty 15x15 board", () => {
  const s = omok.initialState();
  expect(s.board).toHaveLength(225);
  expect(omok.currentPlayer(s)).toBe(0);
  expect(omok.legalMoves(s)).toHaveLength(225);
});
test("horizontal five wins", () => {
  const s = play([[0,0],[0,1],[1,0],[1,1],[2,0],[2,1],[3,0],[3,1],[4,0]]);
  expect(omok.outcome(s)).toEqual({ kind: "win", winner: 0 });
});
test("vertical five wins for white", () => {
  const s = play([[5,5],[0,0],[6,5],[0,1],[7,5],[0,2],[8,5],[0,3],[10,10],[0,4]]);
  expect(omok.outcome(s)).toEqual({ kind: "win", winner: 1 });
});
test("diagonal five wins", () => { /* 흑 (0,0)…(4,4), 백 (0,14)…(3,14) → { kind: "win", winner: 0 } */ });
test("anti-diagonal five wins", () => { /* 흑 (4,0),(3,1),(2,2),(1,3),(0,4), 백 y=10 줄 → { kind: "win", winner: 0 } */ });
test("six in a row also wins", () => {
  // 흑 (0,0)(1,0)(2,0)(4,0)(5,0) 뒤 (3,0)으로 6연속 완성, 백은 y=5 줄에 둔다
  expect(omok.outcome(s)).toEqual({ kind: "win", winner: 0 });
});
test("four in a row is still ongoing", () => { /* 흑 4연속 → { kind: "ongoing" } */ });
test("full board without five is a draw", () => {
  // 무늬 color(x,y) = ((x >> 1) + y) % 2 는 어느 방향으로도 5연속이 없다 (검증 완료, 0이 113칸)
  // 0 칸과 1 칸을 번갈아 두어 225수를 채운다
  expect(s.moveCount).toBe(225);
  expect(omok.outcome(s)).toEqual({ kind: "draw" });
});
test("occupied cell is illegal and applyMove throws", () => {
  const s = play([[7,7]]);
  expect(omok.isLegal(s, { x: 7, y: 7 })).toBe(false);
  expect(() => omok.applyMove(s, { x: 7, y: 7 })).toThrow(IllegalMoveError);
});
test("out of range and non-integer moves are illegal", () => {
  for (const m of [{x:-1,y:0},{x:15,y:0},{x:0,y:15},{x:1.5,y:2}])
    expect(omok.isLegal(omok.initialState(), m)).toBe(false);
});
test("no moves are legal after a win", () => { /* 승리 상태에서 legalMoves 길이 0, isLegal false */ });
test("applyMove does not mutate the input state", () => { /* 원본 board 복사본과 비교 */ });
```

- [ ] **Step 3: 실패 확인**

Run: `npx vitest run packages/engine`
Expected: FAIL (`omok` 모듈 없음)

- [ ] **Step 4: `types.ts`와 `games/omok.ts` 구현**

승리 판정은 마지막 수 기준으로 네 방향(`[1,0]`, `[0,1]`, `[1,1]`, `[1,-1]`)의 양쪽 연속 개수를 세어 합이 5 이상인지 본다. 승자가 있으면 `winner`에 기록하고, `outcome`은 `winner` → `moveCount === 225` → 진행 중 순으로 판단한다.

- [ ] **Step 5: 통과 확인과 검증 3종**

Run: `npx vitest run packages/engine && npm run lint && npm run typecheck`
Expected: 테스트 12개 PASS, lint·typecheck 오류 0

- [ ] **Step 6: Commit**

```bash
git add package.json package-lock.json tsconfig*.json eslint.config.js vitest.config.ts .gitignore packages/engine
git commit -m "feat: 웹게임 작업 공간과 오목 규칙 엔진"
```

---

### Task 2: QA 봇과 게임 목록

**Files:**
- Create: `packages/engine/src/bot.ts`, `packages/engine/src/registry.ts`
- Modify: `packages/engine/src/index.ts`
- Test: `packages/engine/test/bot.test.ts`

**Interfaces:**
- Consumes: Task 1의 `GameRules`, `omok`
- Produces:
  - `type BotLevel = "random" | "basic"`
  - `function createRng(seed: number): () => number` — mulberry32, `[0, 1)` 값
  - `function chooseBotMove<S, M>(rules: GameRules<S, M, any>, state: S, level: BotLevel, rng: () => number): M`
  - `const games: { omok: typeof omok }`, `type GameId = keyof typeof games`, `function getRules(id: string): GameRules<unknown, unknown, unknown> | undefined`

- [ ] **Step 1: 실패하는 테스트 작성**

```ts
test("same seed gives same random game", () => {
  // 시드 42로 random 대 random 한 판을 두 번 → 수순 배열이 같다
});
test("basic takes an immediate win", () => {
  // 흑 (0,0)~(3,0), 백 (0,5)~(3,5), 흑 차례 → basic 수가 (4,0)
  expect(chooseBotMove(omok, s, "basic", createRng(1))).toEqual({ x: 4, y: 0 });
});
test("basic blocks opponent's immediate win", () => {
  // 백 (0,5)~(3,5)에 열린 4, 흑은 승리 수 없음, 흑 차례 → basic 수가 (4,5)
  expect(chooseBotMove(omok, s, "basic", createRng(1))).toEqual({ x: 4, y: 5 });
});
test("bot vs bot games always finish with legal moves", () => {
  // 시드 1..30, random 대 basic, 흑백 교대. applyMove가 던지지 않고 모든 판이 win 또는 draw로 끝난다
});
test("getRules returns undefined for unknown game", () => {
  expect(getRules("omok")?.id).toBe("omok");
  expect(getRules("nope")).toBeUndefined();
});
```

- [ ] **Step 2: 실패 확인** — Run: `npx vitest run packages/engine/test/bot.test.ts` / Expected: FAIL (`chooseBotMove` 없음)

- [ ] **Step 3: `bot.ts`, `registry.ts` 구현**

`basic`은 규칙 계약만 쓴다: (1) 합법 수 중 둔 뒤 `outcome`이 자기 승리인 수 → 첫 번째. (2) 각 합법 수를 둔 뒤 상대의 합법 수 중 상대 승리가 있는지 본다. 상대 즉시 승리가 없는 수만 후보로 남긴다. (3) 후보(없으면 전체)에서 `rng`로 고른다.

- [ ] **Step 4: 통과 확인** — Run: `npx vitest run packages/engine && npm run lint && npm run typecheck` / Expected: 모두 PASS

- [ ] **Step 5: Commit** — `git commit -m "feat: 시드 고정 QA 봇(random·basic)과 게임 목록"`

---

### Task 3: 공용 프로토콜 타입, 서버 설정·DB·저장소

**Files:**
- Create: `packages/protocol/package.json`, `packages/protocol/tsconfig.json`, `packages/protocol/src/index.ts`
- Create: `apps/server/package.json`, `apps/server/tsconfig.json`, `apps/server/src/config.ts`, `apps/server/src/db.ts`, `apps/server/src/repos/users.ts`, `apps/server/src/repos/games.ts`
- Test: `apps/server/test/config.test.ts`, `apps/server/test/repos.test.ts`

**Interfaces:**
- Produces (`@jgame/protocol`, 타입만):
  - `interface UserView { id: number; name: string; isQa: boolean; provider: string }`
  - `type ProviderInfo = { id: "google"; kind: "gis"; clientId: string } | { id: "kakao" | "naver" | "github"; kind: "redirect"; startUrl: string } | { id: "qa"; kind: "qa" }`
  - `type PlayerView = { kind: "human"; userId: number; name: string; isQa: boolean } | { kind: "bot"; level: BotLevel }`
  - `interface GameView { id: number; gameId: string; mode: "pvp" | "pvc"; status: "waiting" | "playing" | "finished"; roomCode: string | null; players: [PlayerView | null, PlayerView | null]; state: unknown; outcome: Outcome; endReason: "rules" | "resign" | null; moveCount: number; online: [boolean, boolean] }`
  - `interface HistoryItem { id: number; gameId: string; mode: "pvp" | "pvc"; opponentName: string; result: "win" | "loss" | "draw" | "ongoing"; createdAt: string }`
  - `type ErrorCode = "unauthorized" | "not_found" | "not_player" | "not_your_turn" | "illegal_move" | "game_finished" | "room_full" | "bad_request"`
  - `type ClientMessage = { type: "subscribe"; gameId: number } | { type: "move"; gameId: number; move: unknown } | { type: "resign"; gameId: number }`
  - `type ServerMessage = { type: "state"; game: GameView } | { type: "error"; code: ErrorCode; message: string }`
- Produces (서버):
  - `interface OAuthProviderConfig { clientId: string; clientSecret?: string; authorizeUrl: string; tokenUrl: string; userUrl: string; pkce: boolean; scope?: string }`
  - `interface Config { port: number; host: string; dbPath: string; qaLogin: boolean; publicOrigin: string; botDelayMs: number; webDist: string | null; google: { clientId: string; jwksUrl: string; issuers: string[] } | null; oauth: Partial<Record<"kakao" | "naver" | "github", OAuthProviderConfig>> }`
  - `function loadConfig(env: Record<string, string | undefined>): Config`
  - `function openDb(path: string): DatabaseSync` — 테이블 생성까지 한다
  - `users.ts`: `upsertUser(db, p: { provider: string; providerUserId: string; displayName: string; isQa: boolean }): UserView`, `getUser(db, id): UserView | undefined`, `createSession(db, userId, ttlMs): string`, `getSessionUser(db, sid, now: Date): UserView | undefined`, `deleteSession(db, sid): void`
  - `games.ts`: `GameRow` 타입, `insertGame`, `getGame`, `updateGame`, `findGameByRoomCode`, `insertMove`, `listMoves`, `listUserGames`

스키마 (설계 6.8을 여러 게임에 맞게 일반화: 흑·백 대신 자리 0·1):

```sql
CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, provider TEXT NOT NULL, provider_user_id TEXT NOT NULL, display_name TEXT NOT NULL, is_qa INTEGER NOT NULL, created_at TEXT NOT NULL, UNIQUE (provider, provider_user_id));
CREATE TABLE IF NOT EXISTS sessions (id TEXT PRIMARY KEY, user_id INTEGER NOT NULL REFERENCES users(id), expires_at TEXT NOT NULL);
CREATE TABLE IF NOT EXISTS games (id INTEGER PRIMARY KEY, game_id TEXT NOT NULL, mode TEXT NOT NULL, room_code TEXT UNIQUE, player0_user_id INTEGER, player1_user_id INTEGER, bot_level TEXT, bot_seed INTEGER, status TEXT NOT NULL, end_reason TEXT, resigned_by INTEGER, created_at TEXT NOT NULL, ended_at TEXT);
CREATE TABLE IF NOT EXISTS moves (game_id INTEGER NOT NULL REFERENCES games(id), seq INTEGER NOT NULL, player INTEGER NOT NULL, move TEXT NOT NULL, created_at TEXT NOT NULL, PRIMARY KEY (game_id, seq));
```

- [ ] **Step 1: 실패하는 테스트 작성**

```ts
test("loadConfig defaults", () => {
  const c = loadConfig({});
  expect(c).toMatchObject({ port: 8840, host: "0.0.0.0", qaLogin: false, publicOrigin: "http://localhost:8840", botDelayMs: 300, google: null, oauth: {} });
});
test("provider enabled only when its client id is set", () => {
  const c = loadConfig({ QA_LOGIN: "1", GOOGLE_CLIENT_ID: "g", GITHUB_CLIENT_ID: "h", GITHUB_CLIENT_SECRET: "s" });
  expect(c.qaLogin).toBe(true);
  expect(c.google?.jwksUrl).toBe("https://www.googleapis.com/oauth2/v3/certs");
  expect(Object.keys(c.oauth)).toEqual(["github"]);
  expect(c.oauth.github).toMatchObject({ pkce: true, tokenUrl: "https://github.com/login/oauth/access_token" });
});
test("upsertUser reuses the same provider user", () => { /* 같은 (provider, id) 두 번 → 같은 id, 이름은 최신값 */ });
test("expired session returns undefined", () => { /* ttl 1000ms, now + 2000ms → undefined */ });
test("moves round-trip in seq order", () => { /* insertMove 3개 → listMoves seq 0,1,2와 JSON 파싱된 move */ });
```

환경 변수 이름: `PORT`, `HOST`, `DB_PATH`, `QA_LOGIN`, `PUBLIC_ORIGIN`, `BOT_DELAY_MS`, `WEB_DIST`, `GOOGLE_CLIENT_ID`, `KAKAO_CLIENT_ID`, `KAKAO_CLIENT_SECRET`, `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET`, `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`. 제공자 엔드포인트 기본값은 Global Constraints 값이다. `WEB_DIST` 기본값은 현재 작업 디렉터리 기준 `apps/web/dist`다.

- [ ] **Step 2: 실패 확인** — Run: `npx vitest run apps/server` / Expected: FAIL
- [ ] **Step 3: 구현** — `node:sqlite`의 `DatabaseSync`를 쓰고, 세션 ID는 `crypto.randomBytes(32).toString("base64url")`로 만든다.
- [ ] **Step 4: 통과 확인** — Run: `npx vitest run apps/server && npm run lint && npm run typecheck` / Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat: 공용 프로토콜 타입과 서버 설정·SQLite 저장소"`

---

### Task 4: 앱 골격, 세션, QA 로그인, 제공자 목록

**Files:**
- Create: `apps/server/src/app.ts`, `apps/server/src/main.ts`, `apps/server/src/auth/session.ts`, `apps/server/src/auth/hosts.ts`, `apps/server/src/auth/routes.ts`
- Test: `apps/server/test/auth-qa.test.ts`, `apps/server/test/helpers.ts`

**Interfaces:**
- Consumes: Task 3의 `Config`, `openDb`, `users.ts`
- Produces:
  - `function buildApp(config: Config, deps?: { db?: DatabaseSync; fetch?: typeof fetch }): Promise<FastifyInstance>` — `db`가 없으면 `openDb(config.dbPath)`
  - `const SESSION_COOKIE = "sid"`. 쿠키 속성 `HttpOnly`, `SameSite=Lax`, `Path=/`, 7일
  - Fastify 요청 데코레이터 `request.user: UserView | null`, 헬퍼 `requireUser(request, reply): UserView | undefined`(없으면 401 `{ code: "unauthorized" }`)
  - `function isRealLoginHost(hostHeader: string | undefined): boolean` — 호스트 이름이 정확히 `localhost`일 때만 true
  - 테스트 헬퍼 `testConfig(over?: Partial<Config>): Config`(메모리 DB `":memory:"`, `botDelayMs: 0`, `qaLogin: true`), `qaLogin(app, name): Promise<string>`(쿠키 문자열 반환)
  - 라우트: `GET /api/auth/providers` → `{ providers: ProviderInfo[] }`, `POST /api/auth/qa` `{ name }` → `{ user }`, `POST /api/auth/logout` → 204, `GET /api/me` → `{ user }`

- [ ] **Step 1: 실패하는 테스트 작성** (`fastify.inject` 사용)

```ts
test("qa login disabled returns 404", async () => {
  const app = await buildApp(testConfig({ qaLogin: false }));
  const r = await app.inject({ method: "POST", url: "/api/auth/qa", payload: { name: "tester1" } });
  expect(r.statusCode).toBe(404);
});
test("qa login sets session and /api/me returns user", async () => {
  // 200, set-cookie에 sid= 와 HttpOnly, SameSite=Lax 포함 → /api/me 가 { name: "tester1", isQa: true, provider: "qa" }
});
test("qa name is trimmed and must be 1-20 chars", async () => {
  // "  a  " → 이름 "a"; "" · "   " · 21자 → 400 { code: "bad_request" }
});
test("same qa name reuses the account", async () => { /* 두 번 로그인 → 같은 user.id */ });
test("logout invalidates the session", async () => { /* logout 204 후 같은 쿠키로 /api/me → 401 */ });
test("real providers listed only on localhost host", async () => {
  // google·github 설정 + qaLogin
  // Host: localhost:8840 → ids ["google", "github", "qa"]
  // Host: 10.8.0.1:8840 → ["qa"];  Host: 127.0.0.1:8840 → ["qa"]
});
```

- [ ] **Step 2: 실패 확인** — Run: `npx vitest run apps/server/test/auth-qa.test.ts` / Expected: FAIL
- [ ] **Step 3: 구현** — `@fastify/cookie`를 등록하고, `onRequest` 훅에서 `sid`로 `request.user`를 채운다. 목록 순서는 google, kakao, naver, github, qa다. `main.ts`는 `loadConfig(process.env)` → `buildApp` → `listen`.
- [ ] **Step 4: 통과 확인** — Run: `npx vitest run apps/server && npm run lint && npm run typecheck` / Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat: 세션 쿠키와 QA 테스트 로그인, 접속 주소별 제공자 목록"`

---

### Task 5: OAuth 인가 코드 흐름 (카카오·네이버·GitHub)

**Files:**
- Create: `apps/server/src/auth/oauth.ts`
- Modify: `apps/server/src/auth/routes.ts`
- Test: `apps/server/test/auth-oauth.test.ts`

**Interfaces:**
- Consumes: Task 3의 `OAuthProviderConfig`, Task 4의 `buildApp(config, { fetch })`
- Produces:
  - `class PendingAuthStore { put(state: string, v: { provider: string; verifier: string | null }): void; take(state: string, now: number): { provider: string; verifier: string | null } | undefined }` — 10분 만료, `take`는 한 번만 성공
  - `function mapProfile(provider: "kakao" | "naver" | "github", json: unknown): { providerUserId: string; displayName: string }` — Global Constraints의 필드
  - 라우트 `GET /auth/:provider/start` → 302, `GET /auth/:provider/callback?code&state` → 성공 시 세션 쿠키 + 302 `/#/games`, 실패 시 400 `{ code: "bad_request" }`. `redirect_uri`는 `${publicOrigin}/auth/${provider}/callback`
  - 토큰 교환은 `application/x-www-form-urlencoded` POST(`grant_type=authorization_code`, `code`, `redirect_uri`, `client_id`, 있으면 `client_secret`, PKCE면 `code_verifier`, 네이버는 `state`도 포함)이고, 사용자 정보 조회는 `Authorization: Bearer <access_token>`

- [ ] **Step 1: 실패하는 테스트 작성** — 가짜 `fetch`를 `buildApp`에 넣어 토큰·사용자 응답을 흉내 낸다.

```ts
test("start redirects with client_id, redirect_uri, state", async () => {
  // github 설정, GET /auth/github/start → 302, Location 호스트 github.com,
  // 쿼리 client_id=h, redirect_uri=http://localhost:8840/auth/github/callback, state 길이 ≥ 32,
  // code_challenge_method=S256, code_challenge 길이 43
});
test("kakao start has no PKCE parameters", async () => { /* code_challenge 없음 */ });
test("unknown or disabled provider start returns 404", async () => { /* /auth/naver/start (미설정) → 404 */ });
test("callback with unknown state is rejected", async () => { /* 400, fetch 호출 0회 */ });
test("callback creates user and session", async () => {
  // start로 state 확보 → callback → 302 Location "/#/games", set-cookie sid
  // 가짜 fetch가 받은 토큰 요청 본문에 code_verifier 포함(github)
  // /api/me → { provider: "github", name: "Octo" }   (응답 { id: 7, login: "octo", name: "Octo" })
});
test("state cannot be replayed", async () => { /* 같은 state로 callback 두 번 → 두 번째 400 */ });
test("mapProfile reads each provider's fields", () => {
  expect(mapProfile("kakao", { id: 1, kakao_account: { profile: { nickname: "카" } } })).toEqual({ providerUserId: "1", displayName: "카" });
  expect(mapProfile("naver", { response: { id: "n1", nickname: "네" } })).toEqual({ providerUserId: "n1", displayName: "네" });
  expect(mapProfile("github", { id: 7, login: "octo", name: null })).toEqual({ providerUserId: "7", displayName: "octo" });
});
test("token endpoint error returns 400 without session", async () => { /* 가짜 fetch 401 → 400, set-cookie 없음 */ });
```

- [ ] **Step 2: 실패 확인** — Run: `npx vitest run apps/server/test/auth-oauth.test.ts` / Expected: FAIL
- [ ] **Step 3: 구현** — `state`와 PKCE 검증값은 `crypto.randomBytes(32).toString("base64url")`, 도전값은 SHA-256의 base64url이다. 사용자 이름이 비면 `"<provider> 사용자"`로 둔다.
- [ ] **Step 4: 통과 확인** — Run: `npx vitest run apps/server && npm run lint && npm run typecheck` / Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat: 카카오·네이버·GitHub 인가 코드 로그인"`

---

### Task 6: 구글 GIS ID 토큰 검증

**Files:**
- Create: `apps/server/src/auth/google.ts`
- Modify: `apps/server/src/auth/routes.ts`
- Test: `apps/server/test/auth-google.test.ts`

**Interfaces:**
- Consumes: `Config.google`
- Produces:
  - `function createGoogleVerifier(cfg: { clientId: string; jwksUrl: string; issuers: string[] }): (credential: string) => Promise<{ providerUserId: string; displayName: string }>` — jose `createRemoteJWKSet` + `jwtVerify(issuer, audience)`. 이름은 `name ?? email ?? "Google 사용자"`, ID는 `sub`
  - 라우트 `POST /api/auth/google` `{ credential }` → 200 `{ user }` + 세션 쿠키, 검증 실패 401 `{ code: "unauthorized" }`, 구글 미설정 404

- [ ] **Step 1: 실패하는 테스트 작성** — 테스트 안에서 jose `generateKeyPair("RS256")`로 키를 만들고, 작은 HTTP 서버(포트 0)로 JWKS를 제공한다.

```ts
test("valid credential logs in", async () => {
  // iss "https://accounts.google.com", aud "g-client", sub "123", name "구글", exp +5분 → 200, /api/me provider "google"
});
test("issuer without https is accepted", async () => { /* iss "accounts.google.com" → 200 */ });
test("wrong audience is rejected", async () => { /* aud "other" → 401 */ });
test("expired credential is rejected", async () => { /* exp 과거 → 401 */ });
test("google not configured returns 404", async () => {});
```

- [ ] **Step 2: 실패 확인** — Run: `npx vitest run apps/server/test/auth-google.test.ts` / Expected: FAIL
- [ ] **Step 3: 구현**
- [ ] **Step 4: 통과 확인** — Run: `npx vitest run apps/server && npm run lint && npm run typecheck` / Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat: 구글 GIS ID 토큰 로그인"`

---

### Task 7: 대국 관리 (MatchService)와 방 코드

**Files:**
- Create: `apps/server/src/play/roomCode.ts`, `apps/server/src/play/match.ts`
- Test: `apps/server/test/match.test.ts`

**Interfaces:**
- Consumes: `@jgame/engine`(`getRules`, `chooseBotMove`, `createRng`), `@jgame/protocol`(`GameView`, `ErrorCode`), Task 3의 `games.ts`
- Produces:
  - `const ROOM_CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"`, `function generateRoomCode(rng?: () => number): string`
  - `class GameError extends Error { constructor(public code: ErrorCode, message: string) }`
  - `type SeatChoice = 0 | 1 | "random"`
  - `class MatchService extends EventEmitter`(이벤트 `"update"`, 인자 `gameDbId: number`)
    - `constructor(db: DatabaseSync, opts: { botDelayMs: number; rng?: () => number })`
    - `createPvc(userId: number, p: { gameId: string; seat: SeatChoice; botLevel: BotLevel; seed?: number }): GameView`
    - `createRoom(userId: number, p: { gameId: string; seat: SeatChoice }): GameView`
    - `joinRoom(userId: number, roomCode: string): GameView`
    - `playMove(gameDbId: number, userId: number, move: unknown): GameView`
    - `resign(gameDbId: number, userId: number): GameView`
    - `getView(gameDbId: number, online?: [boolean, boolean]): GameView`
    - `seatOf(gameDbId: number, userId: number): 0 | 1 | null`
    - `whenIdle(): Promise<void>` — 예약된 봇 수가 모두 끝나면 해결(테스트용)
  - 상태는 메모리 캐시에 두고, 없으면 `listMoves`를 차례로 `applyMove`해 복원한다.
  - 봇 차례면 `botDelayMs` 뒤 봇 수를 두고 `"update"`를 낸다. 봇 시드는 `seed ?? Math.floor(rng() * 2**31)`이며 `bot_seed`에 저장한다. 봇의 n번째 수 rng는 `createRng(seed + n)`.
  - 오류 코드: 없는 대국 `not_found`, 참가자 아님 `not_player`, 차례 아님 `not_your_turn`, 불법 수·형식 오류 `illegal_move`, 끝난 대국 `game_finished`, 다 찬 방 `room_full`, 없는 게임 ID·방 코드 `not_found`.

- [ ] **Step 1: 실패하는 테스트 작성** (메모리 DB, `botDelayMs: 0`, QA 사용자 2명)

```ts
test("room code uses 6 chars from the safe alphabet", () => {
  for (let i = 0; i < 200; i++) expect(generateRoomCode()).toMatch(/^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$/);
});
test("pvc: bot moves first when human takes white", async () => {
  const g = svc.createPvc(u1, { gameId: "omok", seat: 1, botLevel: "random", seed: 5 });
  await svc.whenIdle();
  expect(svc.getView(g.id).moveCount).toBe(1);
});
test("pvc: human move is followed by a bot move", async () => { /* 흑 선택, 수 1개 → whenIdle → moveCount 2 */ });
test("pvc with same seed replays same bot moves", async () => { /* 같은 seed·같은 사람 수순 두 대국 → 상태 동일 */ });
test("pvp: room create, join, alternate moves to a win", () => {
  // createRoom(u1, seat 0) → status "waiting" → joinRoom(u2, code) → "playing"
  // 흑 (0..4,0), 백 (0..3,1) 교대 → status "finished", outcome win 0, endReason "rules"
});
test("rejects second move in the same turn", () => {
  // u1(흑) 수 → 같은 u1이 즉시 또 수 → GameError not_your_turn, listMoves 길이 1
});
test("creator joining own room gets same game", () => { /* joinRoom(u1, 자기 코드) → 같은 id, status "waiting" 유지 */ });
test("third user cannot join a full room", () => { /* room_full */ });
test("illegal and malformed moves are rejected", () => { /* 둔 자리 · { x: "a" } → illegal_move */ });
test("non-player move is rejected", () => { /* u3 → not_player */ });
test("resign ends game with opponent win", () => { /* u1 기권 → outcome win 1, endReason "resign"; 이후 수 → game_finished */ });
test("restores game from db after restart", () => {
  // 수 3개 후 같은 db로 새 MatchService → getView moveCount 3, 다음 차례 사람이 이어서 둘 수 있음
});
test("random seat assignment covers both seats", () => { /* rng 주입으로 0과 1 모두 나옴 */ });
```

- [ ] **Step 2: 실패 확인** — Run: `npx vitest run apps/server/test/match.test.ts` / Expected: FAIL
- [ ] **Step 3: 구현** — 방 코드가 이미 쓰이면 다시 뽑는다(최대 10회 뒤 오류). `GameView.players`의 사람 정보는 `getUser`로 채운다.
- [ ] **Step 4: 통과 확인** — Run: `npx vitest run apps/server && npm run lint && npm run typecheck` / Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat: 대국 관리 — 방 코드, 사람·봇 대국, 기권, DB 복원"`

---

### Task 8: 대국 HTTP API와 WebSocket

**Files:**
- Create: `apps/server/src/play/routes.ts`, `apps/server/src/play/ws.ts`
- Modify: `apps/server/src/app.ts`
- Test: `apps/server/test/play-http.test.ts`, `apps/server/test/play-ws.test.ts`

**Interfaces:**
- Consumes: Task 7의 `MatchService`, `GameError`, Task 4의 `requireUser`
- Produces:
  - HTTP(모두 로그인 필요, 오류는 `{ code, message }`, 상태 코드 `not_found` 404, `bad_request`·`illegal_move` 400, `not_player` 403, 나머지 409):
    - `POST /api/games/pvc` `{ gameId, seat, botLevel, seed? }` → 201 `{ game }`
    - `POST /api/rooms` `{ gameId, seat }` → 201 `{ game }`
    - `POST /api/rooms/join` `{ roomCode }` → 200 `{ game }`(코드는 대문자로 바꾼 뒤 찾는다)
    - `GET /api/games/:id` → 200 `{ game }`(참가자만)
    - `GET /api/me/games` → 200 `{ games: HistoryItem[] }`(최신순 50개)
  - WebSocket `GET /ws`: 업그레이드 때 `sid` 쿠키가 없거나 무효면 `{ type: "error", code: "unauthorized" }`를 보내고 닫는다. 메시지는 `ClientMessage`/`ServerMessage` JSON이다. `subscribe` 뒤 그 대국의 `"update"`마다 `state`를 보낸다. 접속 상태는 대국별로 `(seat → 소켓 수)`를 세어 `GameView.online`에 반영하고, 접속·종료 때 다시 보낸다.

- [ ] **Step 1: 실패하는 테스트 작성** — WebSocket 테스트는 `app.listen({ port: 0 })` 뒤 `ws` 클라이언트에 `Cookie` 헤더를 넣는다. 메시지 대기 헬퍼 `nextState(ws, predicate)`를 둔다.

```ts
// play-http.test.ts
test("unauthenticated api returns 401", async () => {});
test("pvc create returns 201 with game view", async () => { /* players[1].kind "bot" */ });
test("join with lowercase code works", async () => {});
test("history lists result from each user's view", async () => {
  // u1이 이긴 pvp 대국 → u1 result "win", u2 result "loss", opponentName 서로의 이름
});
test("error codes map to http status", async () => { /* 없는 대국 404, 남의 대국 GET 403 */ });

// play-ws.test.ts
test("ws without session is closed with unauthorized", async () => {});
test("pvp game played to the end over ws", async () => {
  // u1·u2 소켓 subscribe → 두 소켓 모두 state 수신 → 교대로 move → 마지막 state status "finished"
});
test("pvc game finishes over ws", async () => {
  // 사람은 받은 state로 엔진 legalMoves를 계산해 첫 수를 보낸다 → status "finished"까지
});
test("reconnect resumes current state", async () => {
  // 수 2개 후 u1 소켓 종료 → u2가 받은 online [false, true] → u1 재접속 subscribe → moveCount 2
});
test("malformed message keeps connection", async () => {
  // "not json" 전송 → error bad_request 수신 → 같은 소켓으로 subscribe 성공
});
test("non-player cannot subscribe", async () => { /* u3 subscribe → error not_player */ });
test("move error is sent only to the sender", async () => { /* 차례 아닌 u2 move → u2만 not_your_turn */ });
```

- [ ] **Step 2: 실패 확인** — Run: `npx vitest run apps/server/test/play-http.test.ts apps/server/test/play-ws.test.ts` / Expected: FAIL
- [ ] **Step 3: 구현** — `@fastify/websocket`을 등록한다. `GameError`를 코드별 응답으로 바꾸는 오류 처리기는 HTTP와 WebSocket이 함께 쓴다.
- [ ] **Step 4: 통과 확인** — Run: `npm test && npm run lint && npm run typecheck` / Expected: PASS
- [ ] **Step 5: Commit** — `git commit -m "feat: 대국 HTTP API와 WebSocket 실시간 진행"`

---

### Task 9: 웹 클라이언트

**Files:**
- Create: `apps/web/package.json`(이름 `@jgame/web`, 스크립트 `dev`, `build`), `apps/web/tsconfig.json`, `apps/web/vite.config.ts`, `apps/web/index.html`, `apps/web/src/main.tsx`, `apps/web/src/App.tsx`, `apps/web/src/api.ts`, `apps/web/src/useGameSocket.ts`, `apps/web/src/pages/{LoginPage,GameListPage,LobbyPage,PlayPage,HistoryPage}.tsx`, `apps/web/src/boards/{OmokBoard.tsx,index.ts}`, `apps/web/src/styles.css`
- Modify: `apps/server/src/app.ts`(`config.webDist` 디렉터리가 있을 때만 `@fastify/static`으로 제공)
- Test: `apps/web/test/OmokBoard.test.tsx`, `apps/web/test/LoginPage.test.tsx`

**Interfaces:**
- Consumes: `@jgame/protocol` 타입, Task 4·5·6·8의 HTTP·WebSocket 계약
- Produces:
  - 해시 라우팅: `#/login`, `#/games`, `#/lobby/:gameId`, `#/play/:id`, `#/history`. 로그인하지 않았으면 `#/login`으로 보낸다.
  - `boards/index.ts`: `const boards: Record<string, { title: string; Board: (p: BoardProps) => JSX.Element }>`. 오목 제목은 `"오목"`.
  - `interface BoardProps { state: unknown; mySeat: 0 | 1 | null; myTurn: boolean; onMove: (move: unknown) => void }`
  - `OmokBoard`: 15×15 SVG. 교차점마다 `<g data-cell="x,y" data-stone="0|1|">` 클릭 영역, 마지막 수 표시, `myTurn`이 false면 클릭 무시
  - `useGameSocket(gameId: number): { game: GameView | null; error: ErrorCode | null; send: (m: ClientMessage) => void }` — 끊기면 1초 뒤 다시 연결하고 `subscribe`를 다시 보낸다.
  - 로그인 화면: `kind: "gis"`면 GIS 스크립트를 넣고 `google.accounts.id.initialize({ client_id, callback })` + `renderButton`으로 버튼을 그린다. 콜백은 `credential`을 `POST /api/auth/google`로 보낸다. `kind: "redirect"`는 `startUrl` 링크, `kind: "qa"`는 닉네임 입력 + "QA 로그인" 버튼이다.
  - 로비: "컴퓨터와 두기"(색: 흑/백/무작위, 봇: random/basic), "방 만들기"(색 선택), "방 코드로 들어가기". 대국 화면: 판, 차례 표시, 상대 연결 상태, 방 코드(대기 중일 때), 기권 버튼. 끝나면 결과 패널("승리"/"패배"/"무승부", "다시 하기", "로비로").
  - `vite.config.ts`: 개발 서버 프록시 `/api`, `/auth`, `/ws` → `http://localhost:8840`

- [ ] **Step 1: 실패하는 테스트 작성** (jsdom + Testing Library)

```tsx
test("clicking an empty cell on my turn sends the move", () => {
  // OmokBoard state=initialState, myTurn=true → [data-cell="3,4"] 클릭 → onMove({ x: 3, y: 4 })
});
test("clicks are ignored when not my turn or cell is occupied", () => {});
test("login page shows only qa form when providers are [qa]", async () => {
  // fetch 흉내 → providers [{ id: "qa", kind: "qa" }] → 닉네임 입력란 있음, 구글 버튼 영역 없음
});
test("login page shows redirect links for kakao, naver, github", async () => {
  // href "/auth/kakao/start" 등 3개
});
```

- [ ] **Step 2: 실패 확인** — Run: `npx vitest run apps/web` / Expected: FAIL
- [ ] **Step 3: 구현** — 화면 문구는 한국어로 쓴다. 휴대폰 폭(360px)에서도 판이 화면 폭에 맞게 줄어들게 한다.
- [ ] **Step 4: 통과 확인과 빌드** — Run: `npm test && npm run lint && npm run typecheck && npm run build` / Expected: PASS, `apps/web/dist/index.html` 생성
- [ ] **Step 5: 수동 확인** — `QA_LOGIN=1 npm start` 후 `curl -s http://127.0.0.1:8840/ | grep -c '<div id="root">'` / Expected: `1`
- [ ] **Step 6: Commit** — `git commit -m "feat: 웹 클라이언트 — 로그인, 로비, 오목 대국, 기록 화면"`

---

### Task 10: E2E, Docker, 실행 안내

**Files:**
- Create: `e2e/playwright.config.ts`, `e2e/qa-pvc.spec.ts`, `Dockerfile`, `.dockerignore`, `compose.yaml`, `README.md`

**Interfaces:**
- Consumes: Task 9의 화면과 `data-cell`·`data-stone` 속성
- Produces:
  - Playwright `webServer`: `npm run build && node apps/server/dist/main.js`, 환경 `QA_LOGIN=1`, `PORT=8851`, `DB_PATH=` 임시 파일, `BOT_DELAY_MS=0`. `baseURL` `http://127.0.0.1:8851`
  - `compose.yaml` 서비스 `web-game`: 빌드 `.`, 포트 `127.0.0.1:8840:8840`과 `10.8.0.1:8840:8840`, 볼륨 `web-game-data:/data`, `DB_PATH=/data/web-game.sqlite`, `QA_LOGIN=${WEB_GAME_QA_LOGIN:-1}`, 그리고 `GOOGLE_CLIENT_ID=${WEB_GAME_GOOGLE_CLIENT_ID:-}` 식으로 `KAKAO_CLIENT_ID`, `KAKAO_CLIENT_SECRET`, `NAVER_CLIENT_ID`, `NAVER_CLIENT_SECRET`, `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`를 각각 `WEB_GAME_` 접두 변수에서 받는다. 실행은 `docker compose --env-file ~/docs/.env up -d --build`다(파싱 가능 확인 완료, 2026-11-18). 이 방식이면 나열한 변수만 컨테이너에 들어간다.
  - `Dockerfile`: 빌드 단계 `node:24-bookworm-slim`에서 `npm ci && npm run build`, 실행 단계 `node:24-bookworm-slim`에 루트·작업 공간 패키지의 `package.json`, `package-lock.json`, 각 `dist`, `apps/web/dist`를 복사하고 `npm ci --omit=dev`, `USER node`, `CMD ["node", "apps/server/dist/main.js"]`

- [ ] **Step 1: 실패하는 E2E 작성** (`e2e/qa-pvc.spec.ts`)

```ts
test("qa user plays omok against the computer to the end", async ({ page }) => {
  // #/login → 닉네임 "e2e" → QA 로그인 → "오목" → "컴퓨터와 두기"(흑, random) 시작
  // 반복: 내 차례면 data-stone="" 인 첫 칸 클릭 (행 우선) → 결과 패널이 보일 때까지 (최대 113수)
  // 결과 패널 문구가 "승리" · "패배" · "무승부" 중 하나 → "내 기록"에 이 대국 1건
});
```

- [ ] **Step 2: 실행** — Run: `npx playwright install chromium && npm run e2e`
  Expected: 1 passed. 이 서버(RHEL 9 계열)에서 브라우저 의존 라이브러리가 없어 실행되지 않으면 `docker run --rm --network host -v "$PWD":/work -w /work mcr.microsoft.com/playwright:v1.65.1-noble npm run e2e`로 실행한다. 이미지 존재는 확인했다.
- [ ] **Step 3: Docker 작성과 실행 확인**
  Run: `docker compose --env-file ~/docs/.env up -d --build && sleep 5 && curl -s -o /dev/null -w '%{http_code}\n' http://10.8.0.1:8840/api/auth/providers && curl -s -H 'Host: 10.8.0.1:8840' http://127.0.0.1:8840/api/auth/providers`
  Expected: `200`, 그리고 `{"providers":[{"id":"qa","kind":"qa"}]}`
- [ ] **Step 4: `README.md` 작성** — 실행 명령, 검증 3종 명령, SSH 포트 포워딩(`ssh -L 8840:127.0.0.1:8840 <서버>` 뒤 `http://localhost:8840` 접속), 제공자 콘솔에 등록할 리디렉션 URI·JavaScript 원본(Global Constraints 값), `~/docs/.env` 키 이름 7개, QA 로그인 끄는 방법(`WEB_GAME_QA_LOGIN=0`)
- [ ] **Step 5: 전체 검증** — Run: `npm run lint && npm run typecheck && npm test && npm run e2e` / Expected: 모두 PASS
- [ ] **Step 6: Commit** — `git commit -m "chore: E2E 검증과 Docker 실행 구성, 실행 안내"`

---

## 실제 로그인 수동 확인 (사용자 앱 등록 후)

자동화 범위 밖이다. 사용자가 네 제공자 콘솔에 앱을 등록하고 `~/docs/.env`에 키를 넣은 뒤, SSH 포트 포워딩으로 `http://localhost:8840`에 접속해 구글·카카오·네이버·GitHub 로그인을 차례로 확인한다. 네이버는 `localhost` 콜백 허용이 공식 문서에 명시되어 있지 않으므로 이때 처음 확인한다.
