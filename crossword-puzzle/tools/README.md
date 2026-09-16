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
- **표준국어대사전 승인 여부.** 거부·지연되면 빈 파일로 진행한다 (02-04 골격이 이미 허용).
