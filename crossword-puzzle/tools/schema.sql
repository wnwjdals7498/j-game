-- words.sqlite 스키마 (02-09).
-- 이 파일은 3단계 drift 스키마(03-01)·5단계 db-swapper(05-03)와 1:1 대응하는
-- **단일 진실**이다 (PLAN.md 3절 계약). 여기가 바뀌면 03-01·05-03도 같이 바꾼다.

-- 게임이 쓰는 단어. PK = 표제어 문자열 (DESIGN 4절)
CREATE TABLE word (
  headword  TEXT PRIMARY KEY,
  len       INTEGER NOT NULL,
  c1 TEXT NOT NULL, c2 TEXT NOT NULL, c3 TEXT, c4 TEXT, c5 TEXT,
  tier      INTEGER NOT NULL,          -- 1..7
  pos       TEXT NOT NULL,
  freq_rank INTEGER,
  source    INTEGER NOT NULL           -- bit: 1=기초, 2=표준
);

-- 패턴 질의용 복합 인덱스. 음절 자리마다 하나 (DESIGN 4절)
CREATE INDEX idx_word_c1 ON word(len, tier, c1);
CREATE INDEX idx_word_c2 ON word(len, tier, c2);
CREATE INDEX idx_word_c3 ON word(len, tier, c3);
CREATE INDEX idx_word_c4 ON word(len, tier, c4);
CREATE INDEX idx_word_c5 ON word(len, tier, c5);

-- 사전이 주는 것. 갱신 시 통째로 갈아엎는다
CREATE TABLE sense (
  sense_id   TEXT PRIMARY KEY,         -- 출처 접두어 포함
  headword   TEXT NOT NULL REFERENCES word(headword),
  definition TEXT NOT NULL,
  synonyms   TEXT,                     -- 쉼표 구분. 없으면 NULL
  source     INTEGER NOT NULL
);
CREATE INDEX idx_sense_headword ON sense(headword);

-- "~와 ~를 포함한 단어" 역색인
CREATE TABLE word_char (
  ch       TEXT NOT NULL,
  headword TEXT NOT NULL,
  PRIMARY KEY (ch, headword)
);

-- 앱이 쓴다. ETL은 빈 테이블만 만든다. 갱신 시 보존 대상 (05-03)
CREATE TABLE word_stat (
  headword  TEXT PRIMARY KEY,
  correct   INTEGER NOT NULL DEFAULT 0,
  wrong     INTEGER NOT NULL DEFAULT 0,
  last_seen INTEGER
);

CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL);
