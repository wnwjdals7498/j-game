import 'package:drift/drift.dart';

part 'app_database.g.dart';

@DataClassName('WordRow')
class Words extends Table {
  @override String get tableName => 'word';

  TextColumn get headword => text()();
  IntColumn get len => integer()();
  TextColumn get c1 => text()();
  TextColumn get c2 => text()();
  TextColumn get c3 => text().nullable()();
  TextColumn get c4 => text().nullable()();
  TextColumn get c5 => text().nullable()();
  IntColumn get tier => integer()();
  TextColumn get pos => text()();
  IntColumn get freqRank => integer().named('freq_rank').nullable()();
  IntColumn get source => integer()();

  @override Set<Column> get primaryKey => {headword};
}

@DataClassName('SenseRow')
class Senses extends Table {
  @override String get tableName => 'sense';

  TextColumn get senseId => text().named('sense_id')();
  TextColumn get headword => text()();
  TextColumn get definition => text()();
  TextColumn get synonyms => text().nullable()();
  IntColumn get source => integer()();

  @override Set<Column> get primaryKey => {senseId};
}

@DataClassName('WordCharRow')
class WordChars extends Table {
  @override String get tableName => 'word_char';

  TextColumn get ch => text()();
  TextColumn get headword => text()();

  @override Set<Column> get primaryKey => {ch, headword};
}

@DataClassName('WordStatRow')
class WordStats extends Table {
  @override String get tableName => 'word_stat';

  TextColumn get headword => text()();
  IntColumn get correct => integer().withDefault(const Constant(0))();
  IntColumn get wrong => integer().withDefault(const Constant(0))();
  IntColumn get lastSeen => integer().named('last_seen').nullable()();

  @override Set<Column> get primaryKey => {headword};
}

@DataClassName('MetaRow')
class Metas extends Table {
  @override String get tableName => 'meta';

  TextColumn get key => text()();
  TextColumn get value => text()();

  @override Set<Column> get primaryKey => {key};
}

/// 퍼즐 단위 "첫 제출" 판정 (03-04). `tools/schema.sql`에 03-04에서 추가된 테이블.
@DataClassName('PuzzleLogRow')
class PuzzleLogs extends Table {
  @override String get tableName => 'puzzle_log';

  IntColumn get levelId => integer().named('level_id')();
  IntColumn get seed => integer()();
  IntColumn get firstScore => integer().named('first_score')();
  IntColumn get submittedAt => integer().named('submitted_at')();

  @override Set<Column> get primaryKey => {levelId, seed};
}

@DriftDatabase(
    tables: [Words, Senses, WordChars, WordStats, Metas, PuzzleLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// `meta.schema_version` 에 들어있어야 할 값 (tools/config.py `SCHEMA_VERSION`,
  /// 02-09 참조). db_bootstrap(03-02)이 시드 DB를 연 뒤 이 값과 비교한다.
  static const int expectedSchemaVersion = 1;

  /// 시드 DB가 완성된 스키마로 오므로 drift 마이그레이션을 쓰지 않는다.
  /// 버전 불일치 처리는 db_bootstrap(03-02)이 담당한다.
  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          // 아무것도 하지 않는다. 시드 DB에 이미 테이블이 있다.
        },
      );

  Future<String?> metaValue(String key) async {
    final row = await (select(metas)..where((t) => t.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<int> get wordCount async {
    final r = await customSelect('SELECT COUNT(*) AS n FROM word')
        .getSingle();
    return r.read<int>('n');
  }
}
