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

- **고유명사 제외 판정 필드 — 02-06에서 실제로 터졌다. F5가 0건이다.**
  `config.EXCLUDE_PROPER_NOUN = True` 인데,
  02-03 출력 스키마의 `word_type` 은 원본 `word_unit`(단어/구/속담/관용구)에서 오고,
  고유명사 표시는 샘플에서 **원본 `word_type`** 에 있다 — 즉 **출력 스키마에 실어 나를 자리가 없다.**
  그래서 `normalize.check()` 의 F5(`pos == "고유명사"`)가 한 건도 못 잡고
  `대한민국` 이 그대로 통과한다 (아래 "정규화·필터 (02-06)" 참조).
  02-06 "고유명사 판정"·"막히면" 이 지시한 대로 **건너뛴 사실을 로그와 여기에 남기고** 진행했다.
  실데이터에서 고유명사가 어느 필드(품사? 어휘 유형?)로 표시되는지 확인한 뒤
  02-03 출력 스키마에 필드를 더할지, 파서에서 바로 거를지를 **02-03/02-06 문서에 먼저 반영**한다.
  샘플로 진행하는 동안에는 `대한민국` 항목이 이 판정의 회귀 케이스다
  (`test_proper_noun_without_basis_is_warned`).
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
  **02-06 진입 시 확인한 결과: 이 불일치는 02-06을 막지 않는다.**
  02-06의 F4(`word_type in EXCLUDE_WORD_TYPES`)가 normalize까지 흘러온 구·속담·관용구를
  어차피 거르므로, 02-04의 파싱 단계 선필터는 중복일 뿐 결과를 바꾸지 않는다
  (기초사전 파서는 선필터가 없어 F4가 여전히 일할 자리가 있다).
  **02-04 문서의 출력 스키마 예시를 고치는 일은 여전히 남아 있다** — 02-10 문서 정리에서 처리한다.

---

## 정규화·필터 (02-06)

> ⚠ 아래 숫자는 전부 **손수 만든 샘플 기반**이다 (실데이터 아님, 00-01 승인 대기).

`tools/normalize.py` — `build/entries.{krdict,stdict}.jsonl` → `build/normalized.jsonl`.
규칙은 [docs/plan/02-06.normalize.md](../docs/plan/02-06.normalize.md) "규칙 (확정)" 절.

정규화는 **버리기 전에 고칠 수 있는 것만** 고친다: NFC → 앞뒤 공백 → 첨자(`가다¹`) → 동형어 번호(`가다01`).
띄어쓰기·`^`·하이픈은 **고치지 않는다** (다른 단어로 바꾸는 것이라 그냥 버린다 → F1).

### 실적

| 입력 | 읽은 행 | 통과 행 | 소요 시간 |
|---|---|---|---|
| 샘플 `entries.krdict.jsonl`(20) + `entries.stdict.jsonl`(12) | 32 | **20** | 0.0s |
| 실데이터 | **미측정 — 승인 대기** (기초사전 명사 기준 수만 개 예상) | — | — |

명령: `tools\.venv\Scripts\python.exe -m tools build --only normalize --fixtures`

```
    normalize: 입력 32 → 통과 20
      F1 비한글/기호          5
      F2 길이                 2
      F3 품사                 5
      F4 어휘유형             0
      F5 고유명사             0
      F5 경고: 고유명사 탈락 0건. 입력에 판정 근거가 실려 있는지 확인할 것 (tools/README.md '미해결', 02-10 눈 검수)
```

실데이터가 도착하면 `--fixtures` 없이 한 번 돌려 위 표의 둘째 행을 채운다 (02-06 DoD).
**통과가 1만 미만이면** 필터가 과하거나 `pos` 실제 값이 `config.ALLOWED_POS` 와 다른 것이다
(02-06 "막히면" — `entries.krdict.jsonl` 의 `pos` 를 `Counter` 로 세어 확인).

### 사유별 탈락 내역 (샘플 12건)

| 코드 | 조건 | 샘플 탈락 |
|---|---|---|
| F1 | 모든 글자가 한글 완성형 (U+AC00~U+D7A3) | 5 — `PC방` · `가게 주인` · `발 없는 말이 천 리 간다` · `미역국을 먹다` · `-님` |
| F2 | 길이 2~5음절 | 2 — `물`(1음절) · `국제연합기구`(6음절) |
| F3 | `pos` 가 `config.ALLOWED_POS`(`{"명사"}`) 에 있음 | 5 — `가다01`(뜻 2개) · `가다02` · `예쁘다` · `빨리` |
| F4 | `word_type` 이 `config.EXCLUDE_WORD_TYPES` 에 없음 | **0** |
| F5 | 고유명사 제외 | **0** |

**F4 가 0인 이유** — 샘플의 구·속담·관용구는 전부 표제어에 띄어쓰기가 있어 **F1 이 먼저 잡는다**
(F1 이 F2 보다 먼저라는 02-06 규칙에 따라 F1 이 맨 앞이다). 표준 쪽 구·속담·관용구는
02-04 파서가 이미 걸러 normalize 까지 오지도 않는다. F4 는 **띄어쓰기 없는 구**가 실데이터에
있을 때를 위한 자리다. 회귀 케이스는 `test_filter` 의 `("사과", "명사", "속담") → "F4"`.

**F5 가 0인 이유** — 위 "미해결" 첫 항목. 고유명사 표시가 입력에 실려 오지 않는다.
그래서 `run()` 은 F5 가 0이면 **경고 한 줄을 반드시 찍는다** (조용히 넘어가지 않는다).

### 02-06 문서 내부 불일치 — F5 를 F3 보다 먼저 본다

02-06의 코드 골격은 `F1 → F2 → F3 → F4 → F5` 순인데, `config.ALLOWED_POS = {"명사"}` 라서
`pos == "고유명사"` 는 **F3 에서 먼저 잡히고 F5 는 영영 도달 불가**가 된다.
같은 문서의 필터 테스트 표는 `("서울", "고유명사", "일반어") → "F5"` 를 요구하고,
DoD 는 "표 기반 테스트 전부 통과"를 요구한다. 그래서 `normalize.check()` 는 **F5 를 F3 앞에 둔다.**

탈락 여부 자체는 어느 순서든 같다. 순서를 고친 이유는 02-06 3절이
**사유별 개수로 어느 필터를 완화할지 판단하라**고 했기 때문이다 — 고유명사가 품사 통계에 섞이면
그 판단을 할 수 없다. 사유는 `normalize.check()` 주석에도 남겼다.

### 검증

```powershell
tools\.venv\Scripts\python.exe -m tools build --only normalize --fixtures
tools\.venv\Scripts\python.exe -m pytest tools/tests/test_normalize.py -q
Get-Content tools/build/normalized.jsonl -TotalCount 5 -Encoding UTF8
```

`tools/tests/test_normalize.py` 31개. 02-06 표 기반 테스트(정규화 7 + 필터 13) 전부 +
NFC 조합형 · F1 선행 · 출력 스키마(`len`/`syllables` 일치) · `raw_headword` 보존 ·
통계 합(사유별 합 + 통과 == 입력) · **입력 파일 일부 부재** · 두 입력 병합 · 빈 입력 ·
F5 경고 · JSONL UTF-8 · 픽스처 end-to-end 32→20.

---

## 표제어 결합 (02-07)

> ⚠ 아래 숫자는 전부 **손수 만든 샘플 기반**이다 (실데이터 아님, 00-01 승인 대기).

`tools/merge.py` — `build/normalized.jsonl` (+ `build/freq.jsonl` · `build/vocab.jsonl`)
→ `build/merged.jsonl`. 규칙은 [docs/plan/02-07.merge.md](../docs/plan/02-07.merge.md) "결합 규칙" 표.

뜻풀이 행 여러 개를 **표제어 문자열 하나에 `word` 1행 + `sense` 여러 행**으로 묶는다
(DESIGN 4절 "게임이 쓰는 것과 사전이 주는 것을 분리"). 기초 우선 · 표준은 보충이고,
앱에 싣는 뜻풀이는 `config.SENSES_PER_WORD`(=1) 개로 자른다 (DESIGN 6절 용량).
**자르기 전에 유의어만 전부 모아** `senses[0].synonyms` 에 넣는다 — 2번 뜻풀이에만
유의어가 있는 경우가 흔하기 때문이다 (02-07).

### 실적

| 입력 | 읽은 행 | 출력 표제어 | 소요 시간 |
|---|---|---|---|
| 샘플 `normalized.jsonl`(20) | 20 | **16** | 0.0s |
| 실데이터 | **미측정 — 승인 대기** | — | — |

명령: `tools\.venv\Scripts\python.exe -m tools build --only merge --fixtures`

```
    merge: 16 words
      빈도 매칭       14 (87.5%)
      등급 매칭       16 (100.0%)
      기초사전만 6 / 표준만 8 / 양쪽 2
```

20행 → 16표제어: `사람`·`나무` 가 기초+표준 양쪽(`source: 3`), `사과` 가 동음이의어
(`사과01`/`사과02` 2 sense → `word` 1행), `나무01` 이 표준에서 뜻풀이 2개다.
빈도 미매칭 2건은 `심근경색`·`미분방정식`(빈도 샘플에 없는 전문어).

**매칭률은 샘플 때문에 비현실적으로 높다.** 등급 100% 는 어휘 샘플 50행을
`normalized` 에 남는 단어들로 채웠기 때문이고, 실데이터에서는 **10% 안팎이 정상**이다
(02-07 "막히면": 등급 5% 미만이면 이상, 1% 미만이면 파일이 잘못된 것).
빈도 쪽 판단 기준은 **30% 미만이면 표제어 형태가 안 맞는 것**(품사 태그·동형어 번호)이고,
그때는 02-05 의 `parse_freq` 에 정규화를 넣어 다시 결합한다.
두 기준은 `merge.MIN_FREQ_MATCH`/`MIN_VOCAB_MATCH` 로 코드에 박혀 있고,
밑돌면 `run()` 이 **경고 한 줄을 반드시 찍는다** (조용히 넘어가지 않는다).
회귀 케이스는 `test_low_match_rate_is_warned`.

실데이터가 도착하면 `--fixtures` 없이 한 번 돌려 위 표의 둘째 행과 매칭률을 채운다 (02-07 DoD).

### 유의어 실적 — 16표제어 중 3개뿐

`사람`(`인간`) · `어머니`(`모친`) · `학교`(`배움터`). 전부 기초사전 `rel_info` 에서 왔고,
표준 샘플에는 `비슷한말` 이 하나도 없다 (02-01 조사: "기초사전보다 훨씬 드물다").
02-07 "막히면" 이 정한 대로 **치명적이지 않다** — 유의어가 없으면 힌트는 뜻풀이로 폴백한다(04-03).
실데이터에서도 비율이 이 수준이면 연상어 모드가 소수 단어에만 뜬다는 뜻이므로,
02-10 눈 검수에서 실제 비율을 기록한다.

### 출력 바이트 재현성

`sorted(by_word.items())` 로 표제어 순회, 같은 표제어 안에서는 `(기초 우선, sense_id)` 로 정렬한다.
dict 순회 순서에 기대면 파이썬 버전·삽입 순서에 따라 파일 바이트가 달라져
`words.sqlite` 의 sha256 비교(05-01)가 깨진다. 유의어 목록도 **첫 등장 순**으로 중복 제거한다
(`set` 순회 금지). 회귀 케이스는 `test_output_is_byte_stable` — 입력 순서를 뒤집어 두 번 돌려
바이트를 비교한다.

### 검증

```powershell
tools\.venv\Scripts\python.exe -m tools build --only merge --fixtures
tools\.venv\Scripts\python.exe -m pytest tools/tests/test_merge.py -q
Get-Content tools/build/merged.jsonl -TotalCount 3 -Encoding UTF8
```

`tools/tests/test_merge.py` 14개. 02-07 "테스트" 표 11종(동음이의어 결합 · 기초 우선 ·
표준 보충 · `source` 비트 · 뜻풀이 컷 · 유의어 수집 · 유의어 중복 제거 · 빈도 결합 ·
등급 결합 · 출력 바이트 안정 · 표준 없음) 전부 + `freq`/`vocab` **파일 자체 부재** ·
매칭률 경고 · 픽스처 end-to-end 20→16.

---

## 난이도 점수 · 7티어 (02-08)

> ⚠ 아래 숫자는 전부 **손수 만든 샘플 16표제어 기반**이다 (실데이터 아님, 00-01 승인 대기).

`tools/score.py` — `build/merged.jsonl` → `build/scored.jsonl` (`score`·`tier` 두 필드 추가).
`tools/hangul.py` — 자모 분해·복잡 자모 판정. 산식·비율은
[docs/plan/02-08.score-tier.md](../docs/plan/02-08.score-tier.md) 가 정한 것이고 그대로 구현했다.

```
base   = (rank - 1) / (max_rank - 1)      빈도 없음 -> NO_FREQ_BASE (1.0)
adj    = ADJ_VOCAB[grade]                 A -0.15 / B -0.10 / C -0.05
adj   += ADJ_IN_KRDICT (-0.10)            기초사전 등재
adj   += ADJ_PER_EXTRA_SYLLABLE x (음절수 - 2)   (+0.03/음절)
adj   += ADJ_COMPLEX_JAMO (+0.05)         겹받침·이중모음 포함
score  = round(clamp(base + adj, 0, 1), 6)
```

조정 손잡이는 전부 `config.py` 에 있다. 산식을 바꿀 때는 merge 까지 다시 돌릴 필요 없이
`python -m tools build --only score` 로 재실행한다 (02-08 "막히면").

### 실적

| 입력 | 읽은 행 | 출력 | 소요 시간 |
|---|---|---|---|
| 샘플 `merged.jsonl`(16) | 16 | **16** | 0.0s |
| 실데이터 | **미측정 — 승인 대기** | — | — |

명령: `tools\.venv\Scripts\python.exe -m tools build --only score --fixtures`

```
    score: 16 words
      tier 1        4   25.0%
      tier 2        4   25.0%
      tier 3        2   12.5%
      tier 4        3   18.8%
      tier 5        1    6.2%
      tier 6        1    6.2%
      tier 7        1    6.2%
```

배정 결과 (점수 오름차순):

| 티어 | 표제어 |
|---|---|
| 1 | 나무 · 사람 · 학교 (0.000000) · 어머니 (0.037732) |
| 2 | 사과 · 하늘 · 바다 · 책상 |
| 3 | 연필 · 도서관 |
| 4 | 김치찌개 · 강아지 · 구름 |
| 5 | 대한민국 |
| 6 | 미분방정식 (빈도 없음 → 1.000000) |
| 7 | 심근경색 (빈도 없음 → 1.000000) |

6·7티어가 **빈도 조사에 없는 전문어**로 채워졌다. 02-08 "`base` 정규화" 주의가 말한
정상 동작이다 — 빈도 조사에 안 나오는 단어는 실제로 어렵다. 실데이터에서 1.0 에 단어가
대량으로 몰려 상위 티어가 전부 이런 단어면 `NO_FREQ_BASE` 를 0.85 로 낮춰 다른 신호와
섞는다 (02-08 "막히면"). 판단은 **02-10 눈 검수**에서 한다.

### 티어 비율 ±1% 는 16행에서 성립하지 않는다 (샘플 크기 한계)

DoD 의 "`TIER_RATIO` 피라미드와 일치 (±1%)" 는 위 16행 로그에서 안 맞는다
(25.0 / 25.0 / 12.5 / 18.8 / 6.2 / 6.2 / 6.2 vs 목표 25 / 22 / 18 / 14 / 10 / 7 / 4).
**한 행이 6.25% 라서 산술적으로 ±1% 안에 들어갈 수가 없다** — 산식이나 `bounds` 의
문제가 아니다. `bounds[-1] = n` 은 들어가 있고(02-08 "막히면" 점검 항목), 1000행을
넣으면 250 / 220 / 180 / 140 / 100 / 70 / 40 으로 **정확히** 떨어진다.
그래서 비율·피라미드 DoD 는 1000행 합성 입력으로 테스트에서 강제하고
(`test_tier_ratio_matches_config` · `test_tier_distribution_is_pyramid`),
16행 샘플 로그는 실적 기록으로만 남긴다. 실데이터가 도착하면 `--fixtures` 없이 한 번
돌려 위 표의 둘째 행과 실제 티어 분포를 채운다.

### 복잡 자모 — `사과` 는 복잡 단어다

`hangul.COMPLEX_JUNG` 에 `ㅘ` 가 들어 있어 `사과` 의 `과` 가 이중모음으로 잡힌다.
02-08 이 "의도한 동작" 이라고 못 박은 케이스이고, `test_simple_syllable` 이 회귀 케이스다.
이중모음이 너무 흔해 패널티가 무의미해지면 `{"ㅙ","ㅚ","ㅞ","ㅟ","ㅢ"}` 로 좁히기로 돼 있는데,
**이건 `config` 값이 아니라 `hangul.py` 코드**이므로 바꿀 때 그 파일에 결정을 주석으로 남긴다.
16표제어 중 복잡 자모로 잡힌 건 `사과`(ㅘ)·`도서관`(ㅘ) 둘뿐이라 지금은 판단할 근거가
없다. 02-10 눈 검수에서 실데이터 비율을 보고 정한다.

`decompose` 는 완성형이 아니면 **ValueError 를 던진다**. 02-08 "막히면" 이 정한 대로
여기서 try/except 로 덮지 않는다 — 비완성형이 도달했다면 02-06 의 F1 필터가 안 먹은 것이다.

### `hangul.py` 로 모은 것

02-08 이 `tools/hangul.py` 주석으로 "02-06/02-07이 쓰는 정규화 함수도 여기로 모은다" 고
지시해서, `normalize_headword` · `is_hangul_syllable` · `is_all_hangul` 을 여기로 옮겼다.
`normalize.py` 는 같은 이름으로 **다시 내보내기만** 한다 — 02-06 이 정한 공개 이름과
`tools/tests/test_normalize.py` 의 import 를 그대로 유지하기 위해서다
(`test_normalization_helpers_moved_here` 가 두 이름이 같은 객체인지 확인한다).

### 출력 바이트 재현성

`assign_tiers` 가 `(score, headword)` 로 정렬하므로 동점이어도 배정이 흔들리지 않고,
`round(score, 6)` 이 부동소수 꼬리를 잘라 실행마다 파일이 달라지는 걸 막는다.
회귀 케이스는 `test_ties_are_assigned_stably`(전원 동점 40행을 입력 순서 뒤집어 두 번 실행)와
`test_score_is_rounded_to_six_places`. 실제로 `--only score --fixtures` 를 두 번 돌려
`scored.jsonl` 이 바이트 단위로 같은 것을 확인했다.

### 검증

```powershell
tools\.venv\Scripts\python.exe -m tools build --only score --fixtures
tools\.venv\Scripts\python.exe -m pytest tools/tests/test_score.py tools/tests/test_hangul.py -q
```

`test_score.py` 12개 + `test_hangul.py` 7개 = **19개** (파라미터 전개 218건).
02-08 "테스트" 표 15종 — 빈도 1위 base 0 · 빈도 없음 base 1.0 · 등급 A 보정 ·
기초 등재 보정 · 음절 패널티 · 복잡 자모 패널티 · clamp · 티어 비율 · 피라미드 ·
티어 범위 · 동점 안정 정렬 · 자모 분해 · 겹받침 판정 · 이중모음 판정 · 단순 음절 —
을 전부 덮고, 여기에 비완성형 ValueError · 자모 표 길이 · `run()` 출력 스키마와 티어 로그 ·
`round(,6)` 자릿수를 더했다.
(02-08 DoD 는 "테스트 14종" 이라고 적었지만 같은 문서 "테스트" 표는 15행이다.
표를 정본으로 보고 15종을 전부 구현했다 — 문서 자체가 해소한 불일치이지 임의 결정이 아니다.)


---

## schema.sql · SQLite 빌드 (02-09)

> ⚠ 아래 숫자는 전부 **손수 만든 샘플 16표제어 기반**이다 (실데이터 아님, 00-01 승인 대기).

`tools/schema.sql` — word · sense · word_char · word_stat · meta 5개 테이블 +
idx_word_c1..c5 · idx_sense_headword 6개 인덱스.
[docs/plan/02-09.build-sqlite.md](../docs/plan/02-09.build-sqlite.md) 의 SQL 을 그대로 옮겼다.
**이 파일이 3단계 drift 스키마(03-01)·5단계 db-swapper(05-03)와 1:1 대응하는 단일 진실**이다
(PLAN.md 3절 계약). 여기가 바뀌면 03-01·05-03 문서도 같이 고친다.

`tools/build_sqlite.py` — `build/scored.jsonl` → `build/words.sqlite`.

### 실적

| 입력 | 단어 | 뜻풀이 | word_char | 파일 크기 | 소요 시간 |
|---|---|---|---|---|---|
| 샘플 `scored.jsonl`(16) | 16 | 16 | 44 | **0.07 MB** | 0.0s |
| 실데이터 | **미측정 — 승인 대기** | — | — | — | — |

명령: `tools\.venv\Scripts\python.exe -m tools build --fixtures`

용량 목표는 10MB(DESIGN 6절)다. 샘플은 0.07MB라 목표 검증이 사실상 무의미하다 —
실데이터가 오면 다시 재야 하는 항목이다. 초과 시 대응은 02-09 "막히면" 순서
(`DEFINITION_MAX_CHARS` 80→60 → `word_char` 제거 검토 → `freq_rank` 제거)를 따른다.

### meta 6키

| key | 이번 빌드 값 |
|---|---|
| `schema_version` | `config.SCHEMA_VERSION` (1) |
| `db_version` | `config.DB_VERSION` (1) |
| `built_at` | ISO8601 UTC. **매 실행 달라진다** |
| `word_count` | 16 |
| `source_versions` | `{"origin": "fixtures", "files": {파일명: {bytes, mtime}}}` |
| `license_notice` | `LICENSE_PENDING` 문구 (아래) |

02-09 표는 두 값의 **뜻**만 정하고 계산법은 안 정했다. 문서가 준 뜻 안에서 이렇게 구현했다.

- `source_versions` — "원본 자료 버전/날짜 JSON". 자료 자체에 버전 필드가 없으므로
  입력 디렉터리(`--fixtures` 면 `tools/fixtures/`, 아니면 `tools/raw/`)를 훑어
  파일별 바이트 수·수정일을 적는다. `origin` 키가 **이 DB가 실데이터인지 샘플인지**를 말한다.
  02-10 리포트와 눈 검수가 그걸 알아야 해서 넣었다.
- `license_notice` — "`docs/LICENSES.md` 요약 문자열". 그 파일의 `## 제목` 과 바로 뒤
  `- 라이선스:` 줄을 짝지어 ` / ` 로 이은 것이다. **지금 `docs/LICENSES.md` 는 없다**
  (00-01 은 HUMAN 문서, 이용 신청 승인 대기). 없을 때는 `build_sqlite.LICENSE_PENDING`
  ("출처 표기 미확정 …")이 들어간다. 00-01 이 끝나면 재빌드만 하면 실제 문구로 바뀐다.

### 재현성

`built_at` 을 빼면 같은 입력 → **같은 바이트**다. 확인 방법:
`--fixtures` 로 두 번 빌드해 각각 `meta.built_at` 을 같은 값으로 덮고 `VACUUM` 한 뒤
sha256 을 비교했더니 동일했다 (`01b2fa3da0a28115…`, 73,728 바이트).

세 가지를 고정해서 얻은 결과다.

1. 빌드마다 기존 파일을 지우고 새로 만든다 (`dst.unlink()`).
2. `rows.sort(key=headword)` 로 삽입 순서를 고정 → SQLite rowid 도 같아진다.
3. `word_char` 는 `set()` 으로 고유 음절만 뽑는데, **set 순회 순서에 기대면 안 되므로**
   `char_rows.sort()` 를 한 번 더 건다. 02-09 골격에는 없던 한 줄인데, 없으면
   같은 입력에서 파일 바이트가 흔들려 05-01 의 sha256 비교가 깨진다.

`built_at` 만은 피할 수 없다. 05-01 이 릴리스 시점에 파일 sha256 을 계산하므로 문제되지는
않지만, "입력이 같은데 파일이 다르다" 를 디버깅할 때 헷갈리니 기억해 둘 것 (02-09 "재현성").

### 패턴 질의 인덱스 — 16행에서는 검증할 수 없다

`test_pattern_query_uses_index` 는 3단계 격자 탐색 성능의 선행 검증이다.
`EXPLAIN QUERY PLAN` 에 `idx_word_c2` 가 나와야 한다. 그런데 행이 몇십 개뿐이면
플래너가 full scan 을 고르는 게 정상이라, 02-09 "막히면" 이 지시한 대로
**합성 3,000행**(중복 제거 후)으로 돌린다. 샘플 16행 DB로 같은 질의를 하면 통과하지 않는다.

`(len, tier, cN)` 순서로 통과했다 — `tier IN (1,2)` 가 범위 조건이라 `cN` 을 못 쓸 수도
있다는 02-09 의 경고는 이번에는 현실이 되지 않았다. 실데이터에서 깨지면 그때
`(len, cN, tier)` 로 바꾸고 `schema.sql` · 03-01 을 같이 고친다.

### 골격에서 바꾼 것

- 용량 초과 경고에 `⚠` 대신 `경고:` 를 쓴다. 콘솔이 cp949 일 수 있어서다
  (02-06·02-07 에서 이미 같은 이유로 정해 둔 규칙).
- `char_rows.sort()` 추가 (위 "재현성" 3번).
- `_source_versions()` 가 `use_fixtures` 를 받는다. 파이프라인이 모듈에 넘겨주는 유일한
  인자이고, 실데이터/샘플 구분이 바로 그 값이다.

### app/assets 복사

```powershell
Copy-Item tools/build/words.sqlite app/assets/words.sqlite -Force
```

**커밋한다** — 02-09 "app/assets 복사" 의 권고를 따랐고, 결정을 `docs/DESIGN.md` 5절
"그 외" 에 기록했다. 지금 커밋된 파일은 **샘플로 만든 것**이라 실데이터가 아니다.
DB 안 `meta.source_versions.origin` 이 `fixtures` 이므로 파일만 봐도 구분된다.

### 검증

```powershell
tools\.venv\Scripts\python.exe -m tools build --fixtures
tools\.venv\Scripts\python.exe -m pytest tools/tests/test_build_sqlite.py -q
```

`test_build_sqlite.py` **12개** — 02-09 "테스트" 절 표 12행(테이블 존재 · 인덱스 존재 ·
word 행 수 · c1..c5 매핑 · word_stat 빈 테이블 · meta 필수 키 · 뜻풀이 길이 컷 ·
유의어 직렬화 · word_char 역색인 · FK 무결성 · 재실행 · 패턴 질의 인덱스 사용)과 1:1이다.
DoD 의 "테스트 12종" 과도 수가 맞는다.

`tools/tests/test_cli.py` 의 "아직 스텁" 대상은 `build_sqlite` 에서 `report`/`check`(02-10)로
옮겼다. build 파이프라인 8단계는 이제 전부 구현됐다.
