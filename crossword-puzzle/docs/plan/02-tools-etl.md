# 2단계 — tools ETL (Python, 오프라인 전용)

규모: M · 선행: 0단계 + 데이터 승인 · 다음: 3단계 · 병행 가능: 1단계

## 목표

사전 원본 4종을 받아 **재현 가능한 한 번의 명령**으로 `words.sqlite`를 만든다. 이 파일은 `app/assets/`에 복사되어 앱에 동봉된다. 파이썬 코드는 앱에 들어가지 않는다.

```
tools/raw/*.xml, *.csv  ──(python -m tools build)──→  tools/build/words.sqlite  ──복사──→  app/assets/words.sqlite
```

## 입력 자료

| 자료 | 역할 | 예상 포맷 | 라이선스 |
|---|---|---|---|
| 한국어기초사전 전체 | 표제어(주), 뜻풀이, 유의어, 품사 | XML | CC BY-SA 2.0 KR |
| 표준국어대사전 전체 | 표제어 보충, 뜻풀이 보충 | XML | CC BY-SA 2.0 KR |
| 현대 국어 사용 빈도 조사 2 | 빈도 순위 (난이도 주 지표) | xlsx/hwp → csv 수동 변환 | 공공누리 1유형 |
| 한국어 학습용 어휘 목록 | 등급 A/B/C (난이도 보정) | xlsx → csv | 공공누리 1유형 |

**첫 작업은 받은 파일을 열어 실제 필드 구조를 `tools/README.md`에 기록하는 것.** 포맷이 예상과 다르면 여기 계획을 고친다.

## 파이프라인 (모듈 분리, 중간 산출물은 JSONL)

```
tools/
├─ __main__.py          python -m tools build | report | check
├─ config.py            티어 비율, 길이 컷, 뜻풀이 길이 컷, 품사 허용 목록
├─ parse_krdict.py      기초사전 XML → entries.krdict.jsonl
├─ parse_stdict.py      표준 XML → entries.stdict.jsonl
├─ parse_freq.py        빈도 csv → freq.jsonl
├─ parse_vocab.py       학습용 어휘 csv → vocab.jsonl
├─ normalize.py         표제어 정규화·필터 (아래 규칙)
├─ merge.py             표제어 기준 결합. 기초 우선, 표준 보충
├─ score.py             복합 점수 → 7티어 (피라미드)
├─ build_sqlite.py      schema.sql 적용 + 적재 + 인덱스 + meta
├─ report.py            티어×길이 분포, 용량, 샘플 출력
├─ schema.sql           ← 3단계 drift 스키마와 1:1 대응. 단일 진실
└─ tests/
```

각 단계가 파일을 남기므로 중간에 눈으로 확인 가능. 전체 재실행이 1~2분 안에 끝나야 한다.

## 표제어 정규화·필터 규칙 (DESIGN에 없던 것, 여기서 확정)

포함 조건 (전부 만족):
- 동형어 번호·첨자 제거 후(`가다01` → `가다`), 하이픈·띄어쓰기·특수문자 없음.
- 모든 글자가 한글 완성형(U+AC00~U+D7A3). `PC방`, `MP3` 제외.
- 길이 2~5음절.
- 품사 허용 목록에 있음. **1차: 명사** (`pos` 컬럼은 남겨 나중에 확장).
- 구·속담·관용구 유형 항목 제외. 고유명사 제외.

동형어 병합: 같은 표제어 문자열은 `word` 1행. `sense`는 여러 행 가능하되 **앱에 넣는 것은 단어당 1개** (기초사전 첫 뜻풀이 우선, 없으면 표준). 뜻풀이 길이 80자 컷(설정값).

라이선스: 예문·발음·음성·이미지 필드는 **파싱 단계에서 버린다.** 유의어는 기초사전 관계 정보에서 추출.

## 난이도 7티어 산식 (초안, `config.py`에서 조정)

```
base   = 빈도 순위 정규화 (0=최빈, 1=최저). 빈도 없음 → 1.0
adj    = -0.15 (학습용 A) / -0.10 (B) / -0.05 (C)
adj   += -0.10 (기초사전 등재)
adj   += +0.03 × (음절수 - 2)
adj   += +0.05 (겹받침·이중모음 등 복잡 자모 포함)
score  = clamp(base + adj, 0, 1)
```

티어 컷: 점수 오름차순 정렬 후 **피라미드 비율**로 자름. 초안 `[25, 22, 18, 14, 10, 7, 4]%` (티어1이 가장 쉬움·가장 많음). 등분위 금지.

## 스키마 (`schema.sql`, 3단계와 공유)

```sql
CREATE TABLE word (
  headword TEXT PRIMARY KEY,
  len      INTEGER NOT NULL,
  c1 TEXT NOT NULL, c2 TEXT NOT NULL, c3 TEXT, c4 TEXT, c5 TEXT,
  tier     INTEGER NOT NULL,           -- 1..7
  pos      TEXT NOT NULL,
  freq_rank INTEGER,
  source   INTEGER NOT NULL            -- bit: 1=기초, 2=표준
);
CREATE INDEX idx_word_c1 ON word(len, tier, c1);
CREATE INDEX idx_word_c2 ON word(len, tier, c2);
CREATE INDEX idx_word_c3 ON word(len, tier, c3);
CREATE INDEX idx_word_c4 ON word(len, tier, c4);
CREATE INDEX idx_word_c5 ON word(len, tier, c5);

CREATE TABLE sense (
  sense_id   TEXT PRIMARY KEY,         -- 사전 고유 ID (출처 접두어)
  headword   TEXT NOT NULL REFERENCES word(headword),
  definition TEXT NOT NULL,
  synonyms   TEXT,                     -- 쉼표 구분
  source     INTEGER NOT NULL
);
CREATE INDEX idx_sense_headword ON sense(headword);

CREATE TABLE word_char (               -- "~와 ~를 포함한 단어" 역색인
  ch TEXT NOT NULL, headword TEXT NOT NULL,
  PRIMARY KEY (ch, headword)
);

CREATE TABLE word_stat (               -- 앱이 씀. ETL은 빈 테이블만 만든다
  headword TEXT PRIMARY KEY,
  correct  INTEGER NOT NULL DEFAULT 0,
  wrong    INTEGER NOT NULL DEFAULT 0,
  last_seen INTEGER
);

CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
-- db_version, schema_version, built_at, source_versions, license_notice
```

`word_stat`은 갱신 시 보존 대상. `meta.db_version`은 5단계 갱신 비교 키.

## 테스트 · 리포트

- `tests/`: 정규화 규칙 단위 테스트(입력 표제어 → 포함/제외/변환 결과), 티어 컷 비율 테스트, 소형 샘플 XML로 end-to-end.
- `python -m tools report` → `docs/reports/02-db-report.md`: 전체 단어 수, 티어×길이 분포표, 파일 용량, 티어별 랜덤 샘플 30개.
- **눈 검수**: 티어별 샘플을 보고 "1티어에 어려운 단어가 있다 / 7티어에 쉬운 단어가 있다"를 체크. 산식 조정 근거.

## 완료 기준 (DoD)

1. `python -m tools build` 한 번으로 raw → `words.sqlite` 재현.
2. 용량 **10MB 이하** 목표 (초과 시 뜻풀이 컷 조정 후 기록).
3. 2~5음절 명사 단어 수와 티어 분포가 리포트에 있고 눈 검수 통과.
4. `word_stat` 빈 테이블 존재, `meta` 채워짐.
5. 3단계 drift가 이 파일을 열어 스키마 검증 테스트를 통과 (3단계에서 확인).
6. `docs/LICENSES.md`에 4개 자료 출처·라이선스 문구 확정.

## 리스크

- **데이터 승인 지연** → 승인 전엔 손수 만든 100단어 샘플 XML로 파이프라인 개발.
- XML 구조가 예상과 다름 → 파서 모듈만 갈아끼우도록 파서와 이후 단계를 JSONL로 격리.
- 표준국어대사전 전체 XML은 수백 MB → `iterparse` 스트리밍 필수. 메모리에 한 번에 올리지 않는다.
- 빈도조사 파일이 hwp면 수동으로 xlsx/csv 변환 필요. 변환 결과를 `tools/raw/`에 두고 절차를 README에 남긴다.
- 기초사전만으로 채움 풀이 부족하면 표준 보충분 투입 (DESIGN 5절 결정). 3단계 실패율 측정 후 판단.
