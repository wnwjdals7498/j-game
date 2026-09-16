# tools — 오프라인 ETL (앱에 포함되지 않음)

사전 원본을 가공해 `words.sqlite` 를 만든다. 개발 PC에서만 실행한다.

## 실행

```powershell
tools\.venv\Scripts\Activate.ps1
pip install -r tools/requirements.txt
python -m tools build      # raw -> tools/build/words.sqlite
python -m tools report     # docs/reports/02-db-report.md 생성
python -m tools check      # 산출물 검증
```

Python 3.10 이상 필요. PC마다 `python`/`python3` 가 가리키는 버전이 다를 수 있으니
`tools/.venv/Scripts/python.exe --version` 으로 venv 안 버전을 확인할 것.

## 원본 자료

`tools/raw/` 에 둔다. 커밋하지 않는다(용량·라이선스).
자료 목록과 라이선스는 `docs/LICENSES.md` 참조.

## 실제 파일 구조 조사 결과

조사일: 2026-09-16 · 수행 문서: [docs/plan/02-01.raw-inspection.md](../docs/plan/02-01.raw-inspection.md)

> ### ⚠ 이 절은 전부 **샘플 기반**이다 (실데이터 아님)
>
> 국립국어원 자료 4종(00-01)이 **이용 승인 대기 중**이라 `tools/raw/` 는 비어 있다.
> 02-01 "승인 대기 중이라면" 절에 따라 **손수 만든 소형 샘플**(`tools/fixtures/`)로 구조를 고정했다.
> 아래의 태그 경로·값 목록·행 수는 **그 샘플을 실제로 조사한 결과**이며,
> 실데이터의 구조를 보증하지 않는다.
>
> **실제 파일이 도착하면** 02-01로 돌아가 같은 절차(`tools/inspect_xml.py`)로 다시 조사하고,
> 이 절과 파서(02-03~02-05)를 고친다. 아래 "실데이터 도착 시 할 일" 참조.

### 조사 도구

`tools/inspect_xml.py` — 조사 전용. 파이프라인에 포함되지 않는다(`python -m tools` 가 import 하지 않음).
`iterparse` 스트리밍이라 수백 MB 파일도 통째로 메모리에 올리지 않는다.

```powershell
# 태그 빈도 · 경로 빈도 · 첫 항목 원문
tools\.venv\Scripts\python.exe tools/inspect_xml.py <파일>.xml [limit]

# 특정 태그의 텍스트 값 전수 조사 (품사 값 목록 확인용)
tools\.venv\Scripts\python.exe tools/inspect_xml.py <파일>.xml --count-tag pos
```

`limit` 기본값 200000 (start 이벤트 상한). 큰 파일에서 느리면 줄인다 — 구조 파악에는 앞부분으로 충분하다.

PowerShell 5.1 의 `Get-Content` 기본 인코딩은 ANSI(CP949)라 UTF-8 파일이 깨져 보인다.
**csv/xml 을 눈으로 볼 때는 `-Encoding UTF8` 을 붙인다.**

### 샘플 픽스처 배치

```
tools/fixtures/
├─ krdict/krdict_sample.xml    기초사전 구조 모방, 20항목
├─ stdict/stdict_sample.xml    표준 구조 모방, 20항목
├─ freq_sample.csv             빈도 100행
└─ vocab_sample.csv            학습용 어휘 50행
```

**XML 만 하위 폴더에 둔다.** 02-03의 `_src_files()` 는 `FIXTURES/krdict` 가 없으면
`FIXTURES` 전체를 `*.xml` 로 훑어 표준 샘플까지 기초사전 파서에 먹인다.
csv 는 `*freq*.csv` / `*vocab*.csv` 이름으로 구분되므로 평평하게 둬도 된다 (02-05 골격).

`tools/raw/` 는 gitignore 대상이라 샘플을 `tools/fixtures/` 에 두고 커밋한다.
`--fixtures` 플래그로 `config.RAW` 대신 이 폴더를 읽는다.

---

### 1. 한국어기초사전 (샘플: `tools/fixtures/krdict/krdict_sample.xml`)

| 질문 | 조사 결과 |
|---|---|
| 인코딩 | UTF-8 (`<?xml version="1.0" encoding="UTF-8"?>`) |
| 루트 태그 / 항목 태그 | `<channel>` / **`<item>`** ← `iterparse` 대상 |
| 항목 총 개수 | 20 (샘플). 실데이터는 수만 예상 |
| 표제어 | `item/word_info/word` (필수) |
| 동형어 번호 | **표제어에 붙어 있고 별도 필드에도 있다.** `word` = `가다01`, `word_info/homonym_num` = `01`. 번호 없는 항목은 `homonym_num` 자체가 없다 (20항목 중 4개만 존재) |
| 품사 | `item/word_info/pos` — 실측 값: `명사`(14) `동사`(2) `품사 없음`(2) `형용사`(1) `부사`(1) |
| 어휘 단위 (구·속담·관용구) | `item/word_info/word_unit` — 실측 값: `단어`(17) `구`(1) `속담`(1) `관용구`(1) |
| 어휘 유형 (고유명사 등) | `item/word_info/word_type` — 실측 값: `일반어`(19) `고유명사`(1) |
| 뜻풀이 | `item/word_info/pos_info/comm_pattern_info/sense_info/definition` (필수) |
| 고유 ID | `.../sense_info/sense_code` → `sense_id` 는 `krdict:` 접두어를 붙여 만든다 |
| 유의어/관계 | `.../sense_info/rel_info` 의 `type` + `word`. 관계 유형 실측 값: `비슷한말`(5) `반대말`(1). **`비슷한말` 만 `synonyms` 로 뽑는다** |
| 다의어 | 한 `item` 에 `sense_info` 가 여러 개 (`가다01` 이 2개). 뜻풀이당 1행 |
| **버릴 것 (라이선스 비개방)** | 예문 `.../sense_info/example_info/example` · 발음/음성 `item/word_info/pronunciation_info/{pronunciation,link}` (`.mp3`) · 이미지 `.../sense_info/multimedia_info/{type,link}` (`.jpg`, `.png`). **파싱 단계에서 읽지도 저장하지도 않는다** (DESIGN 6절) |
| 선택 필드 (부재 허용) | `homonym_num`, `rel_info`, `example_info`, `pronunciation_info`, `multimedia_info` |
| 깨진 항목 | 표제어가 빈 `<word></word>` 항목이 섞일 수 있다 → 행을 내지 않는다 |

샘플에 일부러 넣은 것: 동형어 쌍(`가다01/02`, `사과01/02`), 다의어, 유의어 없는 항목,
1음절(`물`)·6음절(`국제연합기구`)·비한글(`PC방`)·띄어쓰기 구(`가게 주인`)·속담·관용구·고유명사,
그리고 **예문·음성·이미지 필드** (02-03의 라이선스 제외 테스트가 실제로 뭔가를 막는지 확인용).

#### 파싱 실적 (02-03)

| 입력 | 행 수 | 소요 시간 |
|---|---|---|
| 샘플 `tools/fixtures/krdict/krdict_sample.xml` (20항목) | 20 | 0.0s |
| 실데이터 `tools/raw/krdict/*.xml` | **미측정 — 승인 대기** | — |

명령: `tools\.venv\Scripts\python.exe -m tools build --only parse_krdict --fixtures`
실데이터가 도착하면 `--fixtures` 없이 한 번 돌려 위 두 번째 행을 채운다 (02-03 DoD).

### 2. 표준국어대사전 (샘플: `tools/fixtures/stdict/stdict_sample.xml`)

기초사전과 **같은 `item/word_info` 골격**으로 모방했고, 표준 고유 필드를 더했다.

| 질문 | 조사 결과 |
|---|---|
| 인코딩 | UTF-8 |
| 루트 태그 / 항목 태그 | `<channel>` / **`<item>`** |
| 항목 총 개수 | 20 (샘플). 실데이터는 수십만~수백 MB 예상 → `iterparse` + `el.clear()` 필수 |
| 표제어 | `item/word_info/word`. **`^`(띄어쓰기 표시)·`-`(접사) 가 섞인다** (`가게^주인`, `-님`). 원문 그대로 `raw_headword` 에 넣는다 — 판정은 02-06 |
| 동형어 번호 | 기초사전과 동일 (`나무01` + `homonym_num` = `01`) |
| 품사 | `item/word_info/pos` — 실측 값: `명사`(16) `품사 없음`(2) `수사`(1) `접사`(1) |
| 어휘 단위 | `item/word_info/word_unit` — 실측 값: `단어`(17) `구`(1) `속담`(1) `관용구`(1) |
| 어휘 유형 | `item/word_info/word_type` — 실측 값: `일반어`(12) `방언`(2) `옛말`(2) `북한어`(2) `전문어`(2) |
| 방언 판단 | `item/word_info/dialect_info/{dialect_type,area}` 존재 **또는** `word_type == "방언"` (샘플은 둘 다 있음) |
| 전문어 판단 | `item/word_info/cat_info/cat` 존재 — 실측 값: `의학`(1) `수학`(1). **필터를 세게 걸지 말 것** (02-04 "막히면") |
| 뜻풀이 | `.../comm_pattern_info/sense_info/definition`. **빈 `<definition></definition>` 항목이 섞인다** → 그 sense 만 버린다 |
| 고유 ID | `.../sense_info/sense_code` → `stdict:` 접두어 |
| 유의어/관계 | `.../sense_info/rel_info` (`비슷한말`). 기초사전보다 훨씬 드물다 |
| **버릴 것** | 기초사전과 동일 경로 (`example_info`, `pronunciation_info/link` `.wav`, `multimedia_info/link` `.jpg`) |

#### 파싱 실적 (02-04)

| 입력 | 행 수 | 소요 시간 |
|---|---|---|
| 샘플 `tools/fixtures/stdict/stdict_sample.xml` (20항목) | 12 | 0.0s |
| 실데이터 `tools/raw/stdict/*.xml` | **미측정 — 승인 대기** | — |

명령: `tools\.venv\Scripts\python.exe -m tools build --only parse_stdict --fixtures`

단계 로그(제외 개수):

```
stdict: {'total': 20, 'kept': 12, 'drop_dialect': 2, 'drop_old': 4, 'drop_technical': 0, 'drop_phrase': 3}
```

`total`·`drop_*` 는 `<item>` 개수, `kept` 는 출력 행 수(뜻풀이 개수)다.
버려진 9항목: 방언 2(`정구지`,`가시개`) · 옛말 2(`즈믄`,`온뫼`) · 북한어 2(`인민배우`,`날바라지`) ·
구 1(`가게^주인`) · 속담 1 · 관용구 1. 남은 11항목이 12행(`나무01` 이 뜻풀이 2개)이 됐다.

**전문어는 아직 거르지 않는다** (`parse_stdict.DROP_TECHNICAL = False`, 그래서 `drop_technical` 이 0).
02-04 "막히면" — 처음부터 세게 걸면 되돌리기 어려우므로 02-10 눈 검수와 03-05 실패율을 보고 조인다.
반대로 "채움 풀 부족"이면 완화할 첫 번째 손잡이는 `DROP_WORD_UNITS` 다.

`lxml` 은 **도입하지 않았다.** 샘플이 20항목이라 stdlib `iterparse` + `el.clear()` 로 0.0s 다.
실데이터가 도착해 2분을 넘으면 02-04 문서의 `lxml` 전환 절차를 따르고 이 줄을 고친다.

샘플 보강(02-04): 필터에 걸리지 않는 항목(`책상`)에 `example_info` 를 하나 넣었다.
예문이 든 유일한 항목(`가게^주인`)이 구 필터로 버려져 라이선스 제외 테스트가 빈 검사였기 때문이다.

### 3. 현대 국어 사용 빈도 조사 2 (샘플: `tools/fixtures/freq_sample.csv`)

| 질문 | 조사 결과 |
|---|---|
| 포맷 | csv, 구분자 `,`, 따옴표 `"` (천단위 구분자 때문에 필요) |
| 인코딩 | **UTF-8 (BOM 없음)** — `utf-8-sig` 로 열린다. 실데이터는 **CP949 가능성이 높다** (02-05 `_open_csv` 가 `utf-8-sig → cp949 → euc-kr` 순으로 시도) |
| 헤더 | 있음 (1행). 설명 행·2줄 헤더 없음 |
| 컬럼 순서 | `순위,어휘,품사,빈도` |
| 순위 컬럼 | **있다** (1~100). 없으면 02-05가 `빈도` 내림차순으로 직접 부여하는 경로를 탄다 |
| 빈도 표기 | 천단위 구분자 포함 (`"62,384"` — 100행 중 10행). `_to_int` 가 `,` 제거 필요 |
| 동률 | 있음 (`5160` 이 2행 — `의자`, `연필`) |
| 중복 표제어 | 있음 (`사람` 이 `명사`(순위 1)·`의존명사`(순위 100) 2행). **가장 높은 순위(작은 값)만 남긴다** (02-05) |
| 행 수 | 헤더 제외 100 (샘플). 실데이터 약 6만 예상 |
| 품사 값 | `명사`(81) `동사`(5) `의존명사`(4) `형용사`(4) `부사`(3) `대명사`(2) `관형사`(1) |

#### 파싱 실적 (02-05)

| 입력 | 읽은 행 | 출력 행 | 판별된 인코딩 | 소요 시간 |
|---|---|---|---|---|
| 샘플 `tools/fixtures/freq_sample.csv` | 100 | 99 | **`utf-8-sig`** | 0.0s |
| 실데이터 `tools/raw/*freq*.csv` | **미측정 — 승인 대기** (약 6만 예상) | — | — | — |

명령: `tools\.venv\Scripts\python.exe -m tools build --only parse_freq --fixtures`

```
freq: freq_sample.csv 인코딩=utf-8-sig
freq: {'files': 1, 'read': 100, 'drop_no_word': 0, 'drop_dup': 1, 'kept': 99}
```

100행 → 99행: `사람` 이 `명사`(순위 1)·`의존명사`(순위 100) 2행이라 **순위 1만 남았다**
(`drop_dup: 1`). 표제어 문자열이 `word` 의 PK 이고(DESIGN 4절), 높은 순위를 남기는 쪽이
난이도상 보수적(= 쉽게 보는) 선택이다 — 근거는 `parse_freq._best_by_headword` 주석에 있다.

**인코딩 판별**은 `io_util.detect_csv_encoding` 이 `utf-8-sig → cp949 → euc-kr` 순으로 시도하고
성공한 값을 위처럼 로그에 찍는다. `cp949`/`euc-kr` 은 아무 바이트열이나 디코드해 버리므로
UTF-8 을 반드시 먼저 본다. 또 **파일 전체**를 흘려 읽어 검사한다 — 앞부분만 보면
ASCII 로 시작하는 CP949 파일이 UTF-8 로 "성공" 한 뒤 뒤쪽 한글에서 조용히 깨진다.
실데이터가 도착하면 로그의 `인코딩=` 값을 위 표와 3·4절 "인코딩" 칸에 옮겨 적는다.

샘플에는 **순위 컬럼이 있어** 직접 부여 경로를 타지 않는다. 그 경로(`_assign_ranks`:
`빈도` 내림차순, 동률은 같은 순위)는 `test_parse_freq.py` 의
`test_assigns_rank_when_column_missing` · `test_ties_get_same_rank` 가 tmp csv 로 검증한다.

### 4. 한국어 학습용 어휘 목록 (샘플: `tools/fixtures/vocab_sample.csv`)

| 질문 | 조사 결과 |
|---|---|
| 포맷 | csv, 구분자 `,` |
| 인코딩 | **UTF-8 (BOM 없음)**. 실데이터는 CP949 가능성 |
| 헤더 | 있음 (1행) |
| 컬럼 순서 | `어휘,품사,등급` |
| 등급 표기 | **`초급`(25) / `중급`(20) / `고급`(4)** → `A`/`B`/`C` 로 매핑 (02-05 `GRADE_MAP`) |
| 미매칭 등급 | 샘플에 `등급 없음`(1행) 을 일부러 넣었다 → **조용히 버리지 말고 개수를 로그에 찍는 경로** 확인용 |
| 행 수 | 헤더 제외 50 (샘플). 실데이터 5,965 예상 |
| 품사 값 | `명사`(49) `형용사`(1) |

#### 파싱 실적 (02-05)

| 입력 | 읽은 행 | 출력 행 | 판별된 인코딩 | 소요 시간 |
|---|---|---|---|---|
| 샘플 `tools/fixtures/vocab_sample.csv` | 50 | 49 | **`utf-8-sig`** | 0.0s |
| 실데이터 `tools/raw/*vocab*.csv` | **미측정 — 승인 대기** (5,965 예상) | — | — | — |

명령: `tools\.venv\Scripts\python.exe -m tools build --only parse_vocab --fixtures`

```
vocab: vocab_sample.csv 인코딩=utf-8-sig
vocab: {'files': 1, 'read': 50, 'drop_no_word': 0, 'drop_unmapped_grade': 1, 'drop_dup': 0, 'kept': 49}
vocab: 미매칭 등급 1건 -> {'등급 없음': 1} (GRADE_MAP 에 추가할지 02-01 로 확인)
```

등급 매핑 표는 `parse_vocab.GRADE_MAP` 에 명시돼 있다 (`초급→A` `중급→B` `고급→C`,
그리고 이미 `A`/`B`/`C` 인 원본을 위한 항등 매핑). 출력 분포: `A` 25 · `B` 20 · `C` 4.
**매핑에 없는 값은 조용히 버리지 않는다** — 개수(`drop_unmapped_grade`)와 실제 값을
위처럼 로그에 찍는다. 샘플의 `등급 없음`(`예쁘다`) 1행이 그 경로의 회귀 케이스다.
실데이터 등급 표기가 `1급/2급/...` 이면 02-01 로 돌아가 값을 전수 조사한 뒤 `GRADE_MAP` 에 더한다.

### hwp/xlsx → csv 변환 절차

**해당 없음.** 샘플을 csv 로 직접 작성했으므로 변환 단계가 없었다.
실데이터가 hwp/xlsx 로 오면 한글/엑셀로 열어 **UTF-8 csv 로 저장**한 뒤 `tools/raw/` 에 두고,
**어느 시트의 어느 컬럼을 남겼는지**를 여기에 적는다 (재현 가능해야 한다).

### 실데이터 도착 시 할 일

1. `tools/raw/` 에 압축만 풀어 둔다 (이름 변경 금지 — 00-01).
2. `Get-ChildItem -Recurse tools/raw | Select-Object FullName, Length, LastWriteTime` 로 파일 수·용량 확인.
   수백 MB면 02-04의 `iterparse` 스트리밍이 필수다 (이미 전제).
3. `tools/inspect_xml.py` 로 태그·경로·품사 값을 다시 조사해 **위 1·2절 표를 덮어쓴다.**
4. csv 는 `_open_csv` 가 성공한 인코딩을 로그에서 확인해 3·4절 표에 적는다.
5. 실데이터 행 수와 소요 시간을 기록한다 (02-03/02-04/02-05 DoD).
6. 구조가 다르면 **파서를 땜질하지 말고 02-* 계획 문서를 먼저 고친다** (02-01 6절).

### 미해결 — 실데이터 확인 후 확정할 것

- **고유명사 제외 판정 필드.** `config.EXCLUDE_PROPER_NOUN = True` 인데,
  02-03 출력 스키마의 `word_type` 은 원본 `word_unit`(단어/구/속담/관용구)에서 오고,
  고유명사 표시는 샘플에서 **원본 `word_type`** 에 있다 — 즉 **출력 스키마에 실어 나를 자리가 없다.**
  실데이터에서 고유명사가 어느 필드(품사? 어휘 유형?)로 표시되는지 확인한 뒤
  02-03 출력 스키마에 필드를 더할지, 파서에서 바로 거를지를 **02-03/02-06 문서에 먼저 반영**한다.
  샘플로 진행하는 동안에는 `대한민국` 항목이 이 판정의 회귀 케이스다.
- **csv 실제 인코딩** (CP949 예상). 판별에 성공한 인코딩을 위 표에 기록한다.
  (샘플은 `utf-8-sig`. 실데이터 로그의 `인코딩=` 값으로 3·4절 표를 덮어쓴다.)
- **학습용 어휘의 중복 표제어 규칙.** 02-05 "중복 표제어 처리"는 **빈도**에 대해서만
  "가장 높은 순위만 남긴다(= 쉽게 보는 쪽)"를 정했고, 어휘 목록의 중복은 언급이 없다.
  샘플 50행에는 중복이 없다(`drop_dup: 0`). 구현은 같은 방향으로
  **가장 쉬운 등급(A<B<C)만 남기도록** 했다 (`parse_vocab._best_by_headword`) —
  표제어가 `word` 의 PK 라서(DESIGN 4절) 무언가는 골라야 하기 때문이다.
  실데이터에 중복이 실제로 있는지 확인하고, 있으면 **02-05 문서에 규칙을 명시**한다.
  회귀 케이스는 `test_duplicate_headword_keeps_easiest_grade` (tmp csv).
- **표준국어대사전 승인 여부.** 거부·지연되면 빈 파일로 진행한다 (02-04 골격이 이미 허용).
- **02-04 문서 내부 불일치 — `가게^주인`.** 02-04 "표준 고유 필터" 표와 DoD 는
  `word_unit in {구, 속담, 관용구}` 를 **파싱 단계에서 버리라**고 하는데,
  같은 문서의 "출력 스키마" 예시는 `가게^주인`(`word_type: "구"`)을 **출력 행으로** 보여 준다.
  구현은 필터 표·DoD 를 따랐다(버림). 그래서 "`raw_headword` 원문 보존" 테스트는
  `가게^주인` 대신 **출력에 남는** `-님`(접사 하이픈)·`나무01`(동형어 번호)로 검증하고,
  추가로 모든 출력 표제어가 원문 `<word>` 집합의 부분집합임을 확인한다.
  **02-06(정규화) 진입 전에 02-04 문서의 예시를 고칠지 필터를 옮길지 결정해야 한다.**
