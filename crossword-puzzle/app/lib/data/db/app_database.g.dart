// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $WordsTable extends Words with TableInfo<$WordsTable, WordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _headwordMeta = const VerificationMeta(
    'headword',
  );
  @override
  late final GeneratedColumn<String> headword = GeneratedColumn<String>(
    'headword',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lenMeta = const VerificationMeta('len');
  @override
  late final GeneratedColumn<int> len = GeneratedColumn<int>(
    'len',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _c1Meta = const VerificationMeta('c1');
  @override
  late final GeneratedColumn<String> c1 = GeneratedColumn<String>(
    'c1',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _c2Meta = const VerificationMeta('c2');
  @override
  late final GeneratedColumn<String> c2 = GeneratedColumn<String>(
    'c2',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _c3Meta = const VerificationMeta('c3');
  @override
  late final GeneratedColumn<String> c3 = GeneratedColumn<String>(
    'c3',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _c4Meta = const VerificationMeta('c4');
  @override
  late final GeneratedColumn<String> c4 = GeneratedColumn<String>(
    'c4',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _c5Meta = const VerificationMeta('c5');
  @override
  late final GeneratedColumn<String> c5 = GeneratedColumn<String>(
    'c5',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tierMeta = const VerificationMeta('tier');
  @override
  late final GeneratedColumn<int> tier = GeneratedColumn<int>(
    'tier',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _posMeta = const VerificationMeta('pos');
  @override
  late final GeneratedColumn<String> pos = GeneratedColumn<String>(
    'pos',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _freqRankMeta = const VerificationMeta(
    'freqRank',
  );
  @override
  late final GeneratedColumn<int> freqRank = GeneratedColumn<int>(
    'freq_rank',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<int> source = GeneratedColumn<int>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    headword,
    len,
    c1,
    c2,
    c3,
    c4,
    c5,
    tier,
    pos,
    freqRank,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word';
  @override
  VerificationContext validateIntegrity(
    Insertable<WordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('headword')) {
      context.handle(
        _headwordMeta,
        headword.isAcceptableOrUnknown(data['headword']!, _headwordMeta),
      );
    } else if (isInserting) {
      context.missing(_headwordMeta);
    }
    if (data.containsKey('len')) {
      context.handle(
        _lenMeta,
        len.isAcceptableOrUnknown(data['len']!, _lenMeta),
      );
    } else if (isInserting) {
      context.missing(_lenMeta);
    }
    if (data.containsKey('c1')) {
      context.handle(_c1Meta, c1.isAcceptableOrUnknown(data['c1']!, _c1Meta));
    } else if (isInserting) {
      context.missing(_c1Meta);
    }
    if (data.containsKey('c2')) {
      context.handle(_c2Meta, c2.isAcceptableOrUnknown(data['c2']!, _c2Meta));
    } else if (isInserting) {
      context.missing(_c2Meta);
    }
    if (data.containsKey('c3')) {
      context.handle(_c3Meta, c3.isAcceptableOrUnknown(data['c3']!, _c3Meta));
    }
    if (data.containsKey('c4')) {
      context.handle(_c4Meta, c4.isAcceptableOrUnknown(data['c4']!, _c4Meta));
    }
    if (data.containsKey('c5')) {
      context.handle(_c5Meta, c5.isAcceptableOrUnknown(data['c5']!, _c5Meta));
    }
    if (data.containsKey('tier')) {
      context.handle(
        _tierMeta,
        tier.isAcceptableOrUnknown(data['tier']!, _tierMeta),
      );
    } else if (isInserting) {
      context.missing(_tierMeta);
    }
    if (data.containsKey('pos')) {
      context.handle(
        _posMeta,
        pos.isAcceptableOrUnknown(data['pos']!, _posMeta),
      );
    } else if (isInserting) {
      context.missing(_posMeta);
    }
    if (data.containsKey('freq_rank')) {
      context.handle(
        _freqRankMeta,
        freqRank.isAcceptableOrUnknown(data['freq_rank']!, _freqRankMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {headword};
  @override
  WordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordRow(
      headword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}headword'],
      )!,
      len: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}len'],
      )!,
      c1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}c1'],
      )!,
      c2: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}c2'],
      )!,
      c3: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}c3'],
      ),
      c4: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}c4'],
      ),
      c5: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}c5'],
      ),
      tier: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}tier'],
      )!,
      pos: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pos'],
      )!,
      freqRank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}freq_rank'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $WordsTable createAlias(String alias) {
    return $WordsTable(attachedDatabase, alias);
  }
}

class WordRow extends DataClass implements Insertable<WordRow> {
  final String headword;
  final int len;
  final String c1;
  final String c2;
  final String? c3;
  final String? c4;
  final String? c5;
  final int tier;
  final String pos;
  final int? freqRank;
  final int source;
  const WordRow({
    required this.headword,
    required this.len,
    required this.c1,
    required this.c2,
    this.c3,
    this.c4,
    this.c5,
    required this.tier,
    required this.pos,
    this.freqRank,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['headword'] = Variable<String>(headword);
    map['len'] = Variable<int>(len);
    map['c1'] = Variable<String>(c1);
    map['c2'] = Variable<String>(c2);
    if (!nullToAbsent || c3 != null) {
      map['c3'] = Variable<String>(c3);
    }
    if (!nullToAbsent || c4 != null) {
      map['c4'] = Variable<String>(c4);
    }
    if (!nullToAbsent || c5 != null) {
      map['c5'] = Variable<String>(c5);
    }
    map['tier'] = Variable<int>(tier);
    map['pos'] = Variable<String>(pos);
    if (!nullToAbsent || freqRank != null) {
      map['freq_rank'] = Variable<int>(freqRank);
    }
    map['source'] = Variable<int>(source);
    return map;
  }

  WordsCompanion toCompanion(bool nullToAbsent) {
    return WordsCompanion(
      headword: Value(headword),
      len: Value(len),
      c1: Value(c1),
      c2: Value(c2),
      c3: c3 == null && nullToAbsent ? const Value.absent() : Value(c3),
      c4: c4 == null && nullToAbsent ? const Value.absent() : Value(c4),
      c5: c5 == null && nullToAbsent ? const Value.absent() : Value(c5),
      tier: Value(tier),
      pos: Value(pos),
      freqRank: freqRank == null && nullToAbsent
          ? const Value.absent()
          : Value(freqRank),
      source: Value(source),
    );
  }

  factory WordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordRow(
      headword: serializer.fromJson<String>(json['headword']),
      len: serializer.fromJson<int>(json['len']),
      c1: serializer.fromJson<String>(json['c1']),
      c2: serializer.fromJson<String>(json['c2']),
      c3: serializer.fromJson<String?>(json['c3']),
      c4: serializer.fromJson<String?>(json['c4']),
      c5: serializer.fromJson<String?>(json['c5']),
      tier: serializer.fromJson<int>(json['tier']),
      pos: serializer.fromJson<String>(json['pos']),
      freqRank: serializer.fromJson<int?>(json['freqRank']),
      source: serializer.fromJson<int>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'headword': serializer.toJson<String>(headword),
      'len': serializer.toJson<int>(len),
      'c1': serializer.toJson<String>(c1),
      'c2': serializer.toJson<String>(c2),
      'c3': serializer.toJson<String?>(c3),
      'c4': serializer.toJson<String?>(c4),
      'c5': serializer.toJson<String?>(c5),
      'tier': serializer.toJson<int>(tier),
      'pos': serializer.toJson<String>(pos),
      'freqRank': serializer.toJson<int?>(freqRank),
      'source': serializer.toJson<int>(source),
    };
  }

  WordRow copyWith({
    String? headword,
    int? len,
    String? c1,
    String? c2,
    Value<String?> c3 = const Value.absent(),
    Value<String?> c4 = const Value.absent(),
    Value<String?> c5 = const Value.absent(),
    int? tier,
    String? pos,
    Value<int?> freqRank = const Value.absent(),
    int? source,
  }) => WordRow(
    headword: headword ?? this.headword,
    len: len ?? this.len,
    c1: c1 ?? this.c1,
    c2: c2 ?? this.c2,
    c3: c3.present ? c3.value : this.c3,
    c4: c4.present ? c4.value : this.c4,
    c5: c5.present ? c5.value : this.c5,
    tier: tier ?? this.tier,
    pos: pos ?? this.pos,
    freqRank: freqRank.present ? freqRank.value : this.freqRank,
    source: source ?? this.source,
  );
  WordRow copyWithCompanion(WordsCompanion data) {
    return WordRow(
      headword: data.headword.present ? data.headword.value : this.headword,
      len: data.len.present ? data.len.value : this.len,
      c1: data.c1.present ? data.c1.value : this.c1,
      c2: data.c2.present ? data.c2.value : this.c2,
      c3: data.c3.present ? data.c3.value : this.c3,
      c4: data.c4.present ? data.c4.value : this.c4,
      c5: data.c5.present ? data.c5.value : this.c5,
      tier: data.tier.present ? data.tier.value : this.tier,
      pos: data.pos.present ? data.pos.value : this.pos,
      freqRank: data.freqRank.present ? data.freqRank.value : this.freqRank,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordRow(')
          ..write('headword: $headword, ')
          ..write('len: $len, ')
          ..write('c1: $c1, ')
          ..write('c2: $c2, ')
          ..write('c3: $c3, ')
          ..write('c4: $c4, ')
          ..write('c5: $c5, ')
          ..write('tier: $tier, ')
          ..write('pos: $pos, ')
          ..write('freqRank: $freqRank, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    headword,
    len,
    c1,
    c2,
    c3,
    c4,
    c5,
    tier,
    pos,
    freqRank,
    source,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordRow &&
          other.headword == this.headword &&
          other.len == this.len &&
          other.c1 == this.c1 &&
          other.c2 == this.c2 &&
          other.c3 == this.c3 &&
          other.c4 == this.c4 &&
          other.c5 == this.c5 &&
          other.tier == this.tier &&
          other.pos == this.pos &&
          other.freqRank == this.freqRank &&
          other.source == this.source);
}

class WordsCompanion extends UpdateCompanion<WordRow> {
  final Value<String> headword;
  final Value<int> len;
  final Value<String> c1;
  final Value<String> c2;
  final Value<String?> c3;
  final Value<String?> c4;
  final Value<String?> c5;
  final Value<int> tier;
  final Value<String> pos;
  final Value<int?> freqRank;
  final Value<int> source;
  final Value<int> rowid;
  const WordsCompanion({
    this.headword = const Value.absent(),
    this.len = const Value.absent(),
    this.c1 = const Value.absent(),
    this.c2 = const Value.absent(),
    this.c3 = const Value.absent(),
    this.c4 = const Value.absent(),
    this.c5 = const Value.absent(),
    this.tier = const Value.absent(),
    this.pos = const Value.absent(),
    this.freqRank = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordsCompanion.insert({
    required String headword,
    required int len,
    required String c1,
    required String c2,
    this.c3 = const Value.absent(),
    this.c4 = const Value.absent(),
    this.c5 = const Value.absent(),
    required int tier,
    required String pos,
    this.freqRank = const Value.absent(),
    required int source,
    this.rowid = const Value.absent(),
  }) : headword = Value(headword),
       len = Value(len),
       c1 = Value(c1),
       c2 = Value(c2),
       tier = Value(tier),
       pos = Value(pos),
       source = Value(source);
  static Insertable<WordRow> custom({
    Expression<String>? headword,
    Expression<int>? len,
    Expression<String>? c1,
    Expression<String>? c2,
    Expression<String>? c3,
    Expression<String>? c4,
    Expression<String>? c5,
    Expression<int>? tier,
    Expression<String>? pos,
    Expression<int>? freqRank,
    Expression<int>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (headword != null) 'headword': headword,
      if (len != null) 'len': len,
      if (c1 != null) 'c1': c1,
      if (c2 != null) 'c2': c2,
      if (c3 != null) 'c3': c3,
      if (c4 != null) 'c4': c4,
      if (c5 != null) 'c5': c5,
      if (tier != null) 'tier': tier,
      if (pos != null) 'pos': pos,
      if (freqRank != null) 'freq_rank': freqRank,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordsCompanion copyWith({
    Value<String>? headword,
    Value<int>? len,
    Value<String>? c1,
    Value<String>? c2,
    Value<String?>? c3,
    Value<String?>? c4,
    Value<String?>? c5,
    Value<int>? tier,
    Value<String>? pos,
    Value<int?>? freqRank,
    Value<int>? source,
    Value<int>? rowid,
  }) {
    return WordsCompanion(
      headword: headword ?? this.headword,
      len: len ?? this.len,
      c1: c1 ?? this.c1,
      c2: c2 ?? this.c2,
      c3: c3 ?? this.c3,
      c4: c4 ?? this.c4,
      c5: c5 ?? this.c5,
      tier: tier ?? this.tier,
      pos: pos ?? this.pos,
      freqRank: freqRank ?? this.freqRank,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (headword.present) {
      map['headword'] = Variable<String>(headword.value);
    }
    if (len.present) {
      map['len'] = Variable<int>(len.value);
    }
    if (c1.present) {
      map['c1'] = Variable<String>(c1.value);
    }
    if (c2.present) {
      map['c2'] = Variable<String>(c2.value);
    }
    if (c3.present) {
      map['c3'] = Variable<String>(c3.value);
    }
    if (c4.present) {
      map['c4'] = Variable<String>(c4.value);
    }
    if (c5.present) {
      map['c5'] = Variable<String>(c5.value);
    }
    if (tier.present) {
      map['tier'] = Variable<int>(tier.value);
    }
    if (pos.present) {
      map['pos'] = Variable<String>(pos.value);
    }
    if (freqRank.present) {
      map['freq_rank'] = Variable<int>(freqRank.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordsCompanion(')
          ..write('headword: $headword, ')
          ..write('len: $len, ')
          ..write('c1: $c1, ')
          ..write('c2: $c2, ')
          ..write('c3: $c3, ')
          ..write('c4: $c4, ')
          ..write('c5: $c5, ')
          ..write('tier: $tier, ')
          ..write('pos: $pos, ')
          ..write('freqRank: $freqRank, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SensesTable extends Senses with TableInfo<$SensesTable, SenseRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SensesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _senseIdMeta = const VerificationMeta(
    'senseId',
  );
  @override
  late final GeneratedColumn<String> senseId = GeneratedColumn<String>(
    'sense_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _headwordMeta = const VerificationMeta(
    'headword',
  );
  @override
  late final GeneratedColumn<String> headword = GeneratedColumn<String>(
    'headword',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _definitionMeta = const VerificationMeta(
    'definition',
  );
  @override
  late final GeneratedColumn<String> definition = GeneratedColumn<String>(
    'definition',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _synonymsMeta = const VerificationMeta(
    'synonyms',
  );
  @override
  late final GeneratedColumn<String> synonyms = GeneratedColumn<String>(
    'synonyms',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<int> source = GeneratedColumn<int>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    senseId,
    headword,
    definition,
    synonyms,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sense';
  @override
  VerificationContext validateIntegrity(
    Insertable<SenseRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sense_id')) {
      context.handle(
        _senseIdMeta,
        senseId.isAcceptableOrUnknown(data['sense_id']!, _senseIdMeta),
      );
    } else if (isInserting) {
      context.missing(_senseIdMeta);
    }
    if (data.containsKey('headword')) {
      context.handle(
        _headwordMeta,
        headword.isAcceptableOrUnknown(data['headword']!, _headwordMeta),
      );
    } else if (isInserting) {
      context.missing(_headwordMeta);
    }
    if (data.containsKey('definition')) {
      context.handle(
        _definitionMeta,
        definition.isAcceptableOrUnknown(data['definition']!, _definitionMeta),
      );
    } else if (isInserting) {
      context.missing(_definitionMeta);
    }
    if (data.containsKey('synonyms')) {
      context.handle(
        _synonymsMeta,
        synonyms.isAcceptableOrUnknown(data['synonyms']!, _synonymsMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {senseId};
  @override
  SenseRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SenseRow(
      senseId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sense_id'],
      )!,
      headword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}headword'],
      )!,
      definition: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}definition'],
      )!,
      synonyms: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}synonyms'],
      ),
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $SensesTable createAlias(String alias) {
    return $SensesTable(attachedDatabase, alias);
  }
}

class SenseRow extends DataClass implements Insertable<SenseRow> {
  final String senseId;
  final String headword;
  final String definition;
  final String? synonyms;
  final int source;
  const SenseRow({
    required this.senseId,
    required this.headword,
    required this.definition,
    this.synonyms,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sense_id'] = Variable<String>(senseId);
    map['headword'] = Variable<String>(headword);
    map['definition'] = Variable<String>(definition);
    if (!nullToAbsent || synonyms != null) {
      map['synonyms'] = Variable<String>(synonyms);
    }
    map['source'] = Variable<int>(source);
    return map;
  }

  SensesCompanion toCompanion(bool nullToAbsent) {
    return SensesCompanion(
      senseId: Value(senseId),
      headword: Value(headword),
      definition: Value(definition),
      synonyms: synonyms == null && nullToAbsent
          ? const Value.absent()
          : Value(synonyms),
      source: Value(source),
    );
  }

  factory SenseRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SenseRow(
      senseId: serializer.fromJson<String>(json['senseId']),
      headword: serializer.fromJson<String>(json['headword']),
      definition: serializer.fromJson<String>(json['definition']),
      synonyms: serializer.fromJson<String?>(json['synonyms']),
      source: serializer.fromJson<int>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'senseId': serializer.toJson<String>(senseId),
      'headword': serializer.toJson<String>(headword),
      'definition': serializer.toJson<String>(definition),
      'synonyms': serializer.toJson<String?>(synonyms),
      'source': serializer.toJson<int>(source),
    };
  }

  SenseRow copyWith({
    String? senseId,
    String? headword,
    String? definition,
    Value<String?> synonyms = const Value.absent(),
    int? source,
  }) => SenseRow(
    senseId: senseId ?? this.senseId,
    headword: headword ?? this.headword,
    definition: definition ?? this.definition,
    synonyms: synonyms.present ? synonyms.value : this.synonyms,
    source: source ?? this.source,
  );
  SenseRow copyWithCompanion(SensesCompanion data) {
    return SenseRow(
      senseId: data.senseId.present ? data.senseId.value : this.senseId,
      headword: data.headword.present ? data.headword.value : this.headword,
      definition: data.definition.present
          ? data.definition.value
          : this.definition,
      synonyms: data.synonyms.present ? data.synonyms.value : this.synonyms,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SenseRow(')
          ..write('senseId: $senseId, ')
          ..write('headword: $headword, ')
          ..write('definition: $definition, ')
          ..write('synonyms: $synonyms, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(senseId, headword, definition, synonyms, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SenseRow &&
          other.senseId == this.senseId &&
          other.headword == this.headword &&
          other.definition == this.definition &&
          other.synonyms == this.synonyms &&
          other.source == this.source);
}

class SensesCompanion extends UpdateCompanion<SenseRow> {
  final Value<String> senseId;
  final Value<String> headword;
  final Value<String> definition;
  final Value<String?> synonyms;
  final Value<int> source;
  final Value<int> rowid;
  const SensesCompanion({
    this.senseId = const Value.absent(),
    this.headword = const Value.absent(),
    this.definition = const Value.absent(),
    this.synonyms = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SensesCompanion.insert({
    required String senseId,
    required String headword,
    required String definition,
    this.synonyms = const Value.absent(),
    required int source,
    this.rowid = const Value.absent(),
  }) : senseId = Value(senseId),
       headword = Value(headword),
       definition = Value(definition),
       source = Value(source);
  static Insertable<SenseRow> custom({
    Expression<String>? senseId,
    Expression<String>? headword,
    Expression<String>? definition,
    Expression<String>? synonyms,
    Expression<int>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (senseId != null) 'sense_id': senseId,
      if (headword != null) 'headword': headword,
      if (definition != null) 'definition': definition,
      if (synonyms != null) 'synonyms': synonyms,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SensesCompanion copyWith({
    Value<String>? senseId,
    Value<String>? headword,
    Value<String>? definition,
    Value<String?>? synonyms,
    Value<int>? source,
    Value<int>? rowid,
  }) {
    return SensesCompanion(
      senseId: senseId ?? this.senseId,
      headword: headword ?? this.headword,
      definition: definition ?? this.definition,
      synonyms: synonyms ?? this.synonyms,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (senseId.present) {
      map['sense_id'] = Variable<String>(senseId.value);
    }
    if (headword.present) {
      map['headword'] = Variable<String>(headword.value);
    }
    if (definition.present) {
      map['definition'] = Variable<String>(definition.value);
    }
    if (synonyms.present) {
      map['synonyms'] = Variable<String>(synonyms.value);
    }
    if (source.present) {
      map['source'] = Variable<int>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SensesCompanion(')
          ..write('senseId: $senseId, ')
          ..write('headword: $headword, ')
          ..write('definition: $definition, ')
          ..write('synonyms: $synonyms, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WordCharsTable extends WordChars
    with TableInfo<$WordCharsTable, WordCharRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordCharsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _chMeta = const VerificationMeta('ch');
  @override
  late final GeneratedColumn<String> ch = GeneratedColumn<String>(
    'ch',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _headwordMeta = const VerificationMeta(
    'headword',
  );
  @override
  late final GeneratedColumn<String> headword = GeneratedColumn<String>(
    'headword',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [ch, headword];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word_char';
  @override
  VerificationContext validateIntegrity(
    Insertable<WordCharRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ch')) {
      context.handle(_chMeta, ch.isAcceptableOrUnknown(data['ch']!, _chMeta));
    } else if (isInserting) {
      context.missing(_chMeta);
    }
    if (data.containsKey('headword')) {
      context.handle(
        _headwordMeta,
        headword.isAcceptableOrUnknown(data['headword']!, _headwordMeta),
      );
    } else if (isInserting) {
      context.missing(_headwordMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {ch, headword};
  @override
  WordCharRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordCharRow(
      ch: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ch'],
      )!,
      headword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}headword'],
      )!,
    );
  }

  @override
  $WordCharsTable createAlias(String alias) {
    return $WordCharsTable(attachedDatabase, alias);
  }
}

class WordCharRow extends DataClass implements Insertable<WordCharRow> {
  final String ch;
  final String headword;
  const WordCharRow({required this.ch, required this.headword});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ch'] = Variable<String>(ch);
    map['headword'] = Variable<String>(headword);
    return map;
  }

  WordCharsCompanion toCompanion(bool nullToAbsent) {
    return WordCharsCompanion(ch: Value(ch), headword: Value(headword));
  }

  factory WordCharRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordCharRow(
      ch: serializer.fromJson<String>(json['ch']),
      headword: serializer.fromJson<String>(json['headword']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'ch': serializer.toJson<String>(ch),
      'headword': serializer.toJson<String>(headword),
    };
  }

  WordCharRow copyWith({String? ch, String? headword}) =>
      WordCharRow(ch: ch ?? this.ch, headword: headword ?? this.headword);
  WordCharRow copyWithCompanion(WordCharsCompanion data) {
    return WordCharRow(
      ch: data.ch.present ? data.ch.value : this.ch,
      headword: data.headword.present ? data.headword.value : this.headword,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordCharRow(')
          ..write('ch: $ch, ')
          ..write('headword: $headword')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(ch, headword);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordCharRow &&
          other.ch == this.ch &&
          other.headword == this.headword);
}

class WordCharsCompanion extends UpdateCompanion<WordCharRow> {
  final Value<String> ch;
  final Value<String> headword;
  final Value<int> rowid;
  const WordCharsCompanion({
    this.ch = const Value.absent(),
    this.headword = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordCharsCompanion.insert({
    required String ch,
    required String headword,
    this.rowid = const Value.absent(),
  }) : ch = Value(ch),
       headword = Value(headword);
  static Insertable<WordCharRow> custom({
    Expression<String>? ch,
    Expression<String>? headword,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (ch != null) 'ch': ch,
      if (headword != null) 'headword': headword,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordCharsCompanion copyWith({
    Value<String>? ch,
    Value<String>? headword,
    Value<int>? rowid,
  }) {
    return WordCharsCompanion(
      ch: ch ?? this.ch,
      headword: headword ?? this.headword,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (ch.present) {
      map['ch'] = Variable<String>(ch.value);
    }
    if (headword.present) {
      map['headword'] = Variable<String>(headword.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordCharsCompanion(')
          ..write('ch: $ch, ')
          ..write('headword: $headword, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WordStatsTable extends WordStats
    with TableInfo<$WordStatsTable, WordStatRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WordStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _headwordMeta = const VerificationMeta(
    'headword',
  );
  @override
  late final GeneratedColumn<String> headword = GeneratedColumn<String>(
    'headword',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _correctMeta = const VerificationMeta(
    'correct',
  );
  @override
  late final GeneratedColumn<int> correct = GeneratedColumn<int>(
    'correct',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _wrongMeta = const VerificationMeta('wrong');
  @override
  late final GeneratedColumn<int> wrong = GeneratedColumn<int>(
    'wrong',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastSeenMeta = const VerificationMeta(
    'lastSeen',
  );
  @override
  late final GeneratedColumn<int> lastSeen = GeneratedColumn<int>(
    'last_seen',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [headword, correct, wrong, lastSeen];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'word_stat';
  @override
  VerificationContext validateIntegrity(
    Insertable<WordStatRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('headword')) {
      context.handle(
        _headwordMeta,
        headword.isAcceptableOrUnknown(data['headword']!, _headwordMeta),
      );
    } else if (isInserting) {
      context.missing(_headwordMeta);
    }
    if (data.containsKey('correct')) {
      context.handle(
        _correctMeta,
        correct.isAcceptableOrUnknown(data['correct']!, _correctMeta),
      );
    }
    if (data.containsKey('wrong')) {
      context.handle(
        _wrongMeta,
        wrong.isAcceptableOrUnknown(data['wrong']!, _wrongMeta),
      );
    }
    if (data.containsKey('last_seen')) {
      context.handle(
        _lastSeenMeta,
        lastSeen.isAcceptableOrUnknown(data['last_seen']!, _lastSeenMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {headword};
  @override
  WordStatRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WordStatRow(
      headword: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}headword'],
      )!,
      correct: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}correct'],
      )!,
      wrong: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wrong'],
      )!,
      lastSeen: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_seen'],
      ),
    );
  }

  @override
  $WordStatsTable createAlias(String alias) {
    return $WordStatsTable(attachedDatabase, alias);
  }
}

class WordStatRow extends DataClass implements Insertable<WordStatRow> {
  final String headword;
  final int correct;
  final int wrong;
  final int? lastSeen;
  const WordStatRow({
    required this.headword,
    required this.correct,
    required this.wrong,
    this.lastSeen,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['headword'] = Variable<String>(headword);
    map['correct'] = Variable<int>(correct);
    map['wrong'] = Variable<int>(wrong);
    if (!nullToAbsent || lastSeen != null) {
      map['last_seen'] = Variable<int>(lastSeen);
    }
    return map;
  }

  WordStatsCompanion toCompanion(bool nullToAbsent) {
    return WordStatsCompanion(
      headword: Value(headword),
      correct: Value(correct),
      wrong: Value(wrong),
      lastSeen: lastSeen == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSeen),
    );
  }

  factory WordStatRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WordStatRow(
      headword: serializer.fromJson<String>(json['headword']),
      correct: serializer.fromJson<int>(json['correct']),
      wrong: serializer.fromJson<int>(json['wrong']),
      lastSeen: serializer.fromJson<int?>(json['lastSeen']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'headword': serializer.toJson<String>(headword),
      'correct': serializer.toJson<int>(correct),
      'wrong': serializer.toJson<int>(wrong),
      'lastSeen': serializer.toJson<int?>(lastSeen),
    };
  }

  WordStatRow copyWith({
    String? headword,
    int? correct,
    int? wrong,
    Value<int?> lastSeen = const Value.absent(),
  }) => WordStatRow(
    headword: headword ?? this.headword,
    correct: correct ?? this.correct,
    wrong: wrong ?? this.wrong,
    lastSeen: lastSeen.present ? lastSeen.value : this.lastSeen,
  );
  WordStatRow copyWithCompanion(WordStatsCompanion data) {
    return WordStatRow(
      headword: data.headword.present ? data.headword.value : this.headword,
      correct: data.correct.present ? data.correct.value : this.correct,
      wrong: data.wrong.present ? data.wrong.value : this.wrong,
      lastSeen: data.lastSeen.present ? data.lastSeen.value : this.lastSeen,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WordStatRow(')
          ..write('headword: $headword, ')
          ..write('correct: $correct, ')
          ..write('wrong: $wrong, ')
          ..write('lastSeen: $lastSeen')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(headword, correct, wrong, lastSeen);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WordStatRow &&
          other.headword == this.headword &&
          other.correct == this.correct &&
          other.wrong == this.wrong &&
          other.lastSeen == this.lastSeen);
}

class WordStatsCompanion extends UpdateCompanion<WordStatRow> {
  final Value<String> headword;
  final Value<int> correct;
  final Value<int> wrong;
  final Value<int?> lastSeen;
  final Value<int> rowid;
  const WordStatsCompanion({
    this.headword = const Value.absent(),
    this.correct = const Value.absent(),
    this.wrong = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WordStatsCompanion.insert({
    required String headword,
    this.correct = const Value.absent(),
    this.wrong = const Value.absent(),
    this.lastSeen = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : headword = Value(headword);
  static Insertable<WordStatRow> custom({
    Expression<String>? headword,
    Expression<int>? correct,
    Expression<int>? wrong,
    Expression<int>? lastSeen,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (headword != null) 'headword': headword,
      if (correct != null) 'correct': correct,
      if (wrong != null) 'wrong': wrong,
      if (lastSeen != null) 'last_seen': lastSeen,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WordStatsCompanion copyWith({
    Value<String>? headword,
    Value<int>? correct,
    Value<int>? wrong,
    Value<int?>? lastSeen,
    Value<int>? rowid,
  }) {
    return WordStatsCompanion(
      headword: headword ?? this.headword,
      correct: correct ?? this.correct,
      wrong: wrong ?? this.wrong,
      lastSeen: lastSeen ?? this.lastSeen,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (headword.present) {
      map['headword'] = Variable<String>(headword.value);
    }
    if (correct.present) {
      map['correct'] = Variable<int>(correct.value);
    }
    if (wrong.present) {
      map['wrong'] = Variable<int>(wrong.value);
    }
    if (lastSeen.present) {
      map['last_seen'] = Variable<int>(lastSeen.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WordStatsCompanion(')
          ..write('headword: $headword, ')
          ..write('correct: $correct, ')
          ..write('wrong: $wrong, ')
          ..write('lastSeen: $lastSeen, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MetasTable extends Metas with TableInfo<$MetasTable, MetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetasTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MetasTable createAlias(String alias) {
    return $MetasTable(attachedDatabase, alias);
  }
}

class MetaRow extends DataClass implements Insertable<MetaRow> {
  final String key;
  final String value;
  const MetaRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetasCompanion toCompanion(bool nullToAbsent) {
    return MetasCompanion(key: Value(key), value: Value(value));
  }

  factory MetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaRow copyWith({String? key, String? value}) =>
      MetaRow(key: key ?? this.key, value: value ?? this.value);
  MetaRow copyWithCompanion(MetasCompanion data) {
    return MetaRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaRow && other.key == this.key && other.value == this.value);
}

class MetasCompanion extends UpdateCompanion<MetaRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetasCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetasCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetasCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetasCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetasCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PuzzleLogsTable extends PuzzleLogs
    with TableInfo<$PuzzleLogsTable, PuzzleLogRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PuzzleLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _levelIdMeta = const VerificationMeta(
    'levelId',
  );
  @override
  late final GeneratedColumn<int> levelId = GeneratedColumn<int>(
    'level_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seedMeta = const VerificationMeta('seed');
  @override
  late final GeneratedColumn<int> seed = GeneratedColumn<int>(
    'seed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firstScoreMeta = const VerificationMeta(
    'firstScore',
  );
  @override
  late final GeneratedColumn<int> firstScore = GeneratedColumn<int>(
    'first_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _submittedAtMeta = const VerificationMeta(
    'submittedAt',
  );
  @override
  late final GeneratedColumn<int> submittedAt = GeneratedColumn<int>(
    'submitted_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    levelId,
    seed,
    firstScore,
    submittedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'puzzle_log';
  @override
  VerificationContext validateIntegrity(
    Insertable<PuzzleLogRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('level_id')) {
      context.handle(
        _levelIdMeta,
        levelId.isAcceptableOrUnknown(data['level_id']!, _levelIdMeta),
      );
    } else if (isInserting) {
      context.missing(_levelIdMeta);
    }
    if (data.containsKey('seed')) {
      context.handle(
        _seedMeta,
        seed.isAcceptableOrUnknown(data['seed']!, _seedMeta),
      );
    } else if (isInserting) {
      context.missing(_seedMeta);
    }
    if (data.containsKey('first_score')) {
      context.handle(
        _firstScoreMeta,
        firstScore.isAcceptableOrUnknown(data['first_score']!, _firstScoreMeta),
      );
    } else if (isInserting) {
      context.missing(_firstScoreMeta);
    }
    if (data.containsKey('submitted_at')) {
      context.handle(
        _submittedAtMeta,
        submittedAt.isAcceptableOrUnknown(
          data['submitted_at']!,
          _submittedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_submittedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {levelId, seed};
  @override
  PuzzleLogRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PuzzleLogRow(
      levelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level_id'],
      )!,
      seed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seed'],
      )!,
      firstScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}first_score'],
      )!,
      submittedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}submitted_at'],
      )!,
    );
  }

  @override
  $PuzzleLogsTable createAlias(String alias) {
    return $PuzzleLogsTable(attachedDatabase, alias);
  }
}

class PuzzleLogRow extends DataClass implements Insertable<PuzzleLogRow> {
  final int levelId;
  final int seed;
  final int firstScore;
  final int submittedAt;
  const PuzzleLogRow({
    required this.levelId,
    required this.seed,
    required this.firstScore,
    required this.submittedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['level_id'] = Variable<int>(levelId);
    map['seed'] = Variable<int>(seed);
    map['first_score'] = Variable<int>(firstScore);
    map['submitted_at'] = Variable<int>(submittedAt);
    return map;
  }

  PuzzleLogsCompanion toCompanion(bool nullToAbsent) {
    return PuzzleLogsCompanion(
      levelId: Value(levelId),
      seed: Value(seed),
      firstScore: Value(firstScore),
      submittedAt: Value(submittedAt),
    );
  }

  factory PuzzleLogRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PuzzleLogRow(
      levelId: serializer.fromJson<int>(json['levelId']),
      seed: serializer.fromJson<int>(json['seed']),
      firstScore: serializer.fromJson<int>(json['firstScore']),
      submittedAt: serializer.fromJson<int>(json['submittedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'levelId': serializer.toJson<int>(levelId),
      'seed': serializer.toJson<int>(seed),
      'firstScore': serializer.toJson<int>(firstScore),
      'submittedAt': serializer.toJson<int>(submittedAt),
    };
  }

  PuzzleLogRow copyWith({
    int? levelId,
    int? seed,
    int? firstScore,
    int? submittedAt,
  }) => PuzzleLogRow(
    levelId: levelId ?? this.levelId,
    seed: seed ?? this.seed,
    firstScore: firstScore ?? this.firstScore,
    submittedAt: submittedAt ?? this.submittedAt,
  );
  PuzzleLogRow copyWithCompanion(PuzzleLogsCompanion data) {
    return PuzzleLogRow(
      levelId: data.levelId.present ? data.levelId.value : this.levelId,
      seed: data.seed.present ? data.seed.value : this.seed,
      firstScore: data.firstScore.present
          ? data.firstScore.value
          : this.firstScore,
      submittedAt: data.submittedAt.present
          ? data.submittedAt.value
          : this.submittedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PuzzleLogRow(')
          ..write('levelId: $levelId, ')
          ..write('seed: $seed, ')
          ..write('firstScore: $firstScore, ')
          ..write('submittedAt: $submittedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(levelId, seed, firstScore, submittedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PuzzleLogRow &&
          other.levelId == this.levelId &&
          other.seed == this.seed &&
          other.firstScore == this.firstScore &&
          other.submittedAt == this.submittedAt);
}

class PuzzleLogsCompanion extends UpdateCompanion<PuzzleLogRow> {
  final Value<int> levelId;
  final Value<int> seed;
  final Value<int> firstScore;
  final Value<int> submittedAt;
  final Value<int> rowid;
  const PuzzleLogsCompanion({
    this.levelId = const Value.absent(),
    this.seed = const Value.absent(),
    this.firstScore = const Value.absent(),
    this.submittedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PuzzleLogsCompanion.insert({
    required int levelId,
    required int seed,
    required int firstScore,
    required int submittedAt,
    this.rowid = const Value.absent(),
  }) : levelId = Value(levelId),
       seed = Value(seed),
       firstScore = Value(firstScore),
       submittedAt = Value(submittedAt);
  static Insertable<PuzzleLogRow> custom({
    Expression<int>? levelId,
    Expression<int>? seed,
    Expression<int>? firstScore,
    Expression<int>? submittedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (levelId != null) 'level_id': levelId,
      if (seed != null) 'seed': seed,
      if (firstScore != null) 'first_score': firstScore,
      if (submittedAt != null) 'submitted_at': submittedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PuzzleLogsCompanion copyWith({
    Value<int>? levelId,
    Value<int>? seed,
    Value<int>? firstScore,
    Value<int>? submittedAt,
    Value<int>? rowid,
  }) {
    return PuzzleLogsCompanion(
      levelId: levelId ?? this.levelId,
      seed: seed ?? this.seed,
      firstScore: firstScore ?? this.firstScore,
      submittedAt: submittedAt ?? this.submittedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (levelId.present) {
      map['level_id'] = Variable<int>(levelId.value);
    }
    if (seed.present) {
      map['seed'] = Variable<int>(seed.value);
    }
    if (firstScore.present) {
      map['first_score'] = Variable<int>(firstScore.value);
    }
    if (submittedAt.present) {
      map['submitted_at'] = Variable<int>(submittedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PuzzleLogsCompanion(')
          ..write('levelId: $levelId, ')
          ..write('seed: $seed, ')
          ..write('firstScore: $firstScore, ')
          ..write('submittedAt: $submittedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $WordsTable words = $WordsTable(this);
  late final $SensesTable senses = $SensesTable(this);
  late final $WordCharsTable wordChars = $WordCharsTable(this);
  late final $WordStatsTable wordStats = $WordStatsTable(this);
  late final $MetasTable metas = $MetasTable(this);
  late final $PuzzleLogsTable puzzleLogs = $PuzzleLogsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    words,
    senses,
    wordChars,
    wordStats,
    metas,
    puzzleLogs,
  ];
}

typedef $$WordsTableCreateCompanionBuilder = WordsCompanion Function({
  required String headword,
  required int len,
  required String c1,
  required String c2,
  Value<String?> c3,
  Value<String?> c4,
  Value<String?> c5,
  required int tier,
  required String pos,
  Value<int?> freqRank,
  required int source,
  Value<int> rowid,
});
typedef $$WordsTableUpdateCompanionBuilder = WordsCompanion Function({
  Value<String> headword,
  Value<int> len,
  Value<String> c1,
  Value<String> c2,
  Value<String?> c3,
  Value<String?> c4,
  Value<String?> c5,
  Value<int> tier,
  Value<String> pos,
  Value<int?> freqRank,
  Value<int> source,
  Value<int> rowid,
});

class $$WordsTableFilterComposer extends Composer<_$AppDatabase, $WordsTable> {
  $$WordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get headword => $composableBuilder(
    column: $table.headword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get len => $composableBuilder(
    column: $table.len,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get c1 => $composableBuilder(
    column: $table.c1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get c2 => $composableBuilder(
    column: $table.c2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get c3 => $composableBuilder(
    column: $table.c3,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get c4 => $composableBuilder(
    column: $table.c4,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get c5 => $composableBuilder(
    column: $table.c5,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get freqRank => $composableBuilder(
    column: $table.freqRank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WordsTableOrderingComposer
    extends Composer<_$AppDatabase, $WordsTable> {
  $$WordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get headword => $composableBuilder(
    column: $table.headword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get len => $composableBuilder(
    column: $table.len,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get c1 => $composableBuilder(
    column: $table.c1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get c2 => $composableBuilder(
    column: $table.c2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get c3 => $composableBuilder(
    column: $table.c3,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get c4 => $composableBuilder(
    column: $table.c4,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get c5 => $composableBuilder(
    column: $table.c5,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get tier => $composableBuilder(
    column: $table.tier,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get freqRank => $composableBuilder(
    column: $table.freqRank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WordsTable> {
  $$WordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get headword =>
      $composableBuilder(column: $table.headword, builder: (column) => column);

  GeneratedColumn<int> get len =>
      $composableBuilder(column: $table.len, builder: (column) => column);

  GeneratedColumn<String> get c1 =>
      $composableBuilder(column: $table.c1, builder: (column) => column);

  GeneratedColumn<String> get c2 =>
      $composableBuilder(column: $table.c2, builder: (column) => column);

  GeneratedColumn<String> get c3 =>
      $composableBuilder(column: $table.c3, builder: (column) => column);

  GeneratedColumn<String> get c4 =>
      $composableBuilder(column: $table.c4, builder: (column) => column);

  GeneratedColumn<String> get c5 =>
      $composableBuilder(column: $table.c5, builder: (column) => column);

  GeneratedColumn<int> get tier =>
      $composableBuilder(column: $table.tier, builder: (column) => column);

  GeneratedColumn<String> get pos =>
      $composableBuilder(column: $table.pos, builder: (column) => column);

  GeneratedColumn<int> get freqRank =>
      $composableBuilder(column: $table.freqRank, builder: (column) => column);

  GeneratedColumn<int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$WordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WordsTable,
          WordRow,
          $$WordsTableFilterComposer,
          $$WordsTableOrderingComposer,
          $$WordsTableAnnotationComposer,
          $$WordsTableCreateCompanionBuilder,
          $$WordsTableUpdateCompanionBuilder,
          (WordRow, BaseReferences<_$AppDatabase, $WordsTable, WordRow>),
          WordRow,
          PrefetchHooks Function()
        > {
  $$WordsTableTableManager(_$AppDatabase db, $WordsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> headword = const Value.absent(),
                Value<int> len = const Value.absent(),
                Value<String> c1 = const Value.absent(),
                Value<String> c2 = const Value.absent(),
                Value<String?> c3 = const Value.absent(),
                Value<String?> c4 = const Value.absent(),
                Value<String?> c5 = const Value.absent(),
                Value<int> tier = const Value.absent(),
                Value<String> pos = const Value.absent(),
                Value<int?> freqRank = const Value.absent(),
                Value<int> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordsCompanion(
                headword: headword,
                len: len,
                c1: c1,
                c2: c2,
                c3: c3,
                c4: c4,
                c5: c5,
                tier: tier,
                pos: pos,
                freqRank: freqRank,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String headword,
                required int len,
                required String c1,
                required String c2,
                Value<String?> c3 = const Value.absent(),
                Value<String?> c4 = const Value.absent(),
                Value<String?> c5 = const Value.absent(),
                required int tier,
                required String pos,
                Value<int?> freqRank = const Value.absent(),
                required int source,
                Value<int> rowid = const Value.absent(),
              }) => WordsCompanion.insert(
                headword: headword,
                len: len,
                c1: c1,
                c2: c2,
                c3: c3,
                c4: c4,
                c5: c5,
                tier: tier,
                pos: pos,
                freqRank: freqRank,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WordsTable, WordRow>(table),
                  BaseReferences<_$AppDatabase, $WordsTable, WordRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WordsTable,
      WordRow,
      $$WordsTableFilterComposer,
      $$WordsTableOrderingComposer,
      $$WordsTableAnnotationComposer,
      $$WordsTableCreateCompanionBuilder,
      $$WordsTableUpdateCompanionBuilder,
      (WordRow, BaseReferences<_$AppDatabase, $WordsTable, WordRow>),
      WordRow,
      PrefetchHooks Function()
    >;
typedef $$SensesTableCreateCompanionBuilder = SensesCompanion Function({
  required String senseId,
  required String headword,
  required String definition,
  Value<String?> synonyms,
  required int source,
  Value<int> rowid,
});
typedef $$SensesTableUpdateCompanionBuilder = SensesCompanion Function({
  Value<String> senseId,
  Value<String> headword,
  Value<String> definition,
  Value<String?> synonyms,
  Value<int> source,
  Value<int> rowid,
});

class $$SensesTableFilterComposer
    extends Composer<_$AppDatabase, $SensesTable> {
  $$SensesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get senseId => $composableBuilder(
    column: $table.senseId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headword => $composableBuilder(
    column: $table.headword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get synonyms => $composableBuilder(
    column: $table.synonyms,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SensesTableOrderingComposer
    extends Composer<_$AppDatabase, $SensesTable> {
  $$SensesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get senseId => $composableBuilder(
    column: $table.senseId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headword => $composableBuilder(
    column: $table.headword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get synonyms => $composableBuilder(
    column: $table.synonyms,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SensesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SensesTable> {
  $$SensesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get senseId =>
      $composableBuilder(column: $table.senseId, builder: (column) => column);

  GeneratedColumn<String> get headword =>
      $composableBuilder(column: $table.headword, builder: (column) => column);

  GeneratedColumn<String> get definition => $composableBuilder(
    column: $table.definition,
    builder: (column) => column,
  );

  GeneratedColumn<String> get synonyms =>
      $composableBuilder(column: $table.synonyms, builder: (column) => column);

  GeneratedColumn<int> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$SensesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SensesTable,
          SenseRow,
          $$SensesTableFilterComposer,
          $$SensesTableOrderingComposer,
          $$SensesTableAnnotationComposer,
          $$SensesTableCreateCompanionBuilder,
          $$SensesTableUpdateCompanionBuilder,
          (SenseRow, BaseReferences<_$AppDatabase, $SensesTable, SenseRow>),
          SenseRow,
          PrefetchHooks Function()
        > {
  $$SensesTableTableManager(_$AppDatabase db, $SensesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SensesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SensesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SensesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> senseId = const Value.absent(),
                Value<String> headword = const Value.absent(),
                Value<String> definition = const Value.absent(),
                Value<String?> synonyms = const Value.absent(),
                Value<int> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SensesCompanion(
                senseId: senseId,
                headword: headword,
                definition: definition,
                synonyms: synonyms,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String senseId,
                required String headword,
                required String definition,
                Value<String?> synonyms = const Value.absent(),
                required int source,
                Value<int> rowid = const Value.absent(),
              }) => SensesCompanion.insert(
                senseId: senseId,
                headword: headword,
                definition: definition,
                synonyms: synonyms,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SensesTable, SenseRow>(table),
                  BaseReferences<_$AppDatabase, $SensesTable, SenseRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SensesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SensesTable,
      SenseRow,
      $$SensesTableFilterComposer,
      $$SensesTableOrderingComposer,
      $$SensesTableAnnotationComposer,
      $$SensesTableCreateCompanionBuilder,
      $$SensesTableUpdateCompanionBuilder,
      (SenseRow, BaseReferences<_$AppDatabase, $SensesTable, SenseRow>),
      SenseRow,
      PrefetchHooks Function()
    >;
typedef $$WordCharsTableCreateCompanionBuilder = WordCharsCompanion Function({
  required String ch,
  required String headword,
  Value<int> rowid,
});
typedef $$WordCharsTableUpdateCompanionBuilder = WordCharsCompanion Function({
  Value<String> ch,
  Value<String> headword,
  Value<int> rowid,
});

class $$WordCharsTableFilterComposer
    extends Composer<_$AppDatabase, $WordCharsTable> {
  $$WordCharsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get ch => $composableBuilder(
    column: $table.ch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get headword => $composableBuilder(
    column: $table.headword,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WordCharsTableOrderingComposer
    extends Composer<_$AppDatabase, $WordCharsTable> {
  $$WordCharsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get ch => $composableBuilder(
    column: $table.ch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get headword => $composableBuilder(
    column: $table.headword,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WordCharsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WordCharsTable> {
  $$WordCharsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get ch =>
      $composableBuilder(column: $table.ch, builder: (column) => column);

  GeneratedColumn<String> get headword =>
      $composableBuilder(column: $table.headword, builder: (column) => column);
}

class $$WordCharsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WordCharsTable,
          WordCharRow,
          $$WordCharsTableFilterComposer,
          $$WordCharsTableOrderingComposer,
          $$WordCharsTableAnnotationComposer,
          $$WordCharsTableCreateCompanionBuilder,
          $$WordCharsTableUpdateCompanionBuilder,
          (
            WordCharRow,
            BaseReferences<_$AppDatabase, $WordCharsTable, WordCharRow>,
          ),
          WordCharRow,
          PrefetchHooks Function()
        > {
  $$WordCharsTableTableManager(_$AppDatabase db, $WordCharsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordCharsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordCharsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordCharsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> ch = const Value.absent(),
            Value<String> headword = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => WordCharsCompanion(ch: ch, headword: headword, rowid: rowid),
          createCompanionCallback:
              ({
                required String ch,
                required String headword,
                Value<int> rowid = const Value.absent(),
              }) => WordCharsCompanion.insert(
                ch: ch,
                headword: headword,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WordCharsTable, WordCharRow>(table),
                  BaseReferences<_$AppDatabase, $WordCharsTable, WordCharRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WordCharsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WordCharsTable,
      WordCharRow,
      $$WordCharsTableFilterComposer,
      $$WordCharsTableOrderingComposer,
      $$WordCharsTableAnnotationComposer,
      $$WordCharsTableCreateCompanionBuilder,
      $$WordCharsTableUpdateCompanionBuilder,
      (
        WordCharRow,
        BaseReferences<_$AppDatabase, $WordCharsTable, WordCharRow>,
      ),
      WordCharRow,
      PrefetchHooks Function()
    >;
typedef $$WordStatsTableCreateCompanionBuilder = WordStatsCompanion Function({
  required String headword,
  Value<int> correct,
  Value<int> wrong,
  Value<int?> lastSeen,
  Value<int> rowid,
});
typedef $$WordStatsTableUpdateCompanionBuilder = WordStatsCompanion Function({
  Value<String> headword,
  Value<int> correct,
  Value<int> wrong,
  Value<int?> lastSeen,
  Value<int> rowid,
});

class $$WordStatsTableFilterComposer
    extends Composer<_$AppDatabase, $WordStatsTable> {
  $$WordStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get headword => $composableBuilder(
    column: $table.headword,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wrong => $composableBuilder(
    column: $table.wrong,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WordStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $WordStatsTable> {
  $$WordStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get headword => $composableBuilder(
    column: $table.headword,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get correct => $composableBuilder(
    column: $table.correct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wrong => $composableBuilder(
    column: $table.wrong,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSeen => $composableBuilder(
    column: $table.lastSeen,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WordStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WordStatsTable> {
  $$WordStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get headword =>
      $composableBuilder(column: $table.headword, builder: (column) => column);

  GeneratedColumn<int> get correct =>
      $composableBuilder(column: $table.correct, builder: (column) => column);

  GeneratedColumn<int> get wrong =>
      $composableBuilder(column: $table.wrong, builder: (column) => column);

  GeneratedColumn<int> get lastSeen =>
      $composableBuilder(column: $table.lastSeen, builder: (column) => column);
}

class $$WordStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WordStatsTable,
          WordStatRow,
          $$WordStatsTableFilterComposer,
          $$WordStatsTableOrderingComposer,
          $$WordStatsTableAnnotationComposer,
          $$WordStatsTableCreateCompanionBuilder,
          $$WordStatsTableUpdateCompanionBuilder,
          (
            WordStatRow,
            BaseReferences<_$AppDatabase, $WordStatsTable, WordStatRow>,
          ),
          WordStatRow,
          PrefetchHooks Function()
        > {
  $$WordStatsTableTableManager(_$AppDatabase db, $WordStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WordStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WordStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WordStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> headword = const Value.absent(),
                Value<int> correct = const Value.absent(),
                Value<int> wrong = const Value.absent(),
                Value<int?> lastSeen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordStatsCompanion(
                headword: headword,
                correct: correct,
                wrong: wrong,
                lastSeen: lastSeen,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String headword,
                Value<int> correct = const Value.absent(),
                Value<int> wrong = const Value.absent(),
                Value<int?> lastSeen = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => WordStatsCompanion.insert(
                headword: headword,
                correct: correct,
                wrong: wrong,
                lastSeen: lastSeen,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WordStatsTable, WordStatRow>(table),
                  BaseReferences<_$AppDatabase, $WordStatsTable, WordStatRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WordStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WordStatsTable,
      WordStatRow,
      $$WordStatsTableFilterComposer,
      $$WordStatsTableOrderingComposer,
      $$WordStatsTableAnnotationComposer,
      $$WordStatsTableCreateCompanionBuilder,
      $$WordStatsTableUpdateCompanionBuilder,
      (
        WordStatRow,
        BaseReferences<_$AppDatabase, $WordStatsTable, WordStatRow>,
      ),
      WordStatRow,
      PrefetchHooks Function()
    >;
typedef $$MetasTableCreateCompanionBuilder = MetasCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$MetasTableUpdateCompanionBuilder = MetasCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$MetasTableFilterComposer extends Composer<_$AppDatabase, $MetasTable> {
  $$MetasTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetasTableOrderingComposer
    extends Composer<_$AppDatabase, $MetasTable> {
  $$MetasTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetasTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetasTable> {
  $$MetasTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetasTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetasTable,
          MetaRow,
          $$MetasTableFilterComposer,
          $$MetasTableOrderingComposer,
          $$MetasTableAnnotationComposer,
          $$MetasTableCreateCompanionBuilder,
          $$MetasTableUpdateCompanionBuilder,
          (MetaRow, BaseReferences<_$AppDatabase, $MetasTable, MetaRow>),
          MetaRow,
          PrefetchHooks Function()
        > {
  $$MetasTableTableManager(_$AppDatabase db, $MetasTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetasTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetasTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetasTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => MetasCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => MetasCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MetasTable, MetaRow>(table),
                  BaseReferences<_$AppDatabase, $MetasTable, MetaRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetasTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetasTable,
      MetaRow,
      $$MetasTableFilterComposer,
      $$MetasTableOrderingComposer,
      $$MetasTableAnnotationComposer,
      $$MetasTableCreateCompanionBuilder,
      $$MetasTableUpdateCompanionBuilder,
      (MetaRow, BaseReferences<_$AppDatabase, $MetasTable, MetaRow>),
      MetaRow,
      PrefetchHooks Function()
    >;
typedef $$PuzzleLogsTableCreateCompanionBuilder = PuzzleLogsCompanion Function({
  required int levelId,
  required int seed,
  required int firstScore,
  required int submittedAt,
  Value<int> rowid,
});
typedef $$PuzzleLogsTableUpdateCompanionBuilder = PuzzleLogsCompanion Function({
  Value<int> levelId,
  Value<int> seed,
  Value<int> firstScore,
  Value<int> submittedAt,
  Value<int> rowid,
});

class $$PuzzleLogsTableFilterComposer
    extends Composer<_$AppDatabase, $PuzzleLogsTable> {
  $$PuzzleLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get levelId => $composableBuilder(
    column: $table.levelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seed => $composableBuilder(
    column: $table.seed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get firstScore => $composableBuilder(
    column: $table.firstScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get submittedAt => $composableBuilder(
    column: $table.submittedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PuzzleLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $PuzzleLogsTable> {
  $$PuzzleLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get levelId => $composableBuilder(
    column: $table.levelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seed => $composableBuilder(
    column: $table.seed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get firstScore => $composableBuilder(
    column: $table.firstScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get submittedAt => $composableBuilder(
    column: $table.submittedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PuzzleLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PuzzleLogsTable> {
  $$PuzzleLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get levelId =>
      $composableBuilder(column: $table.levelId, builder: (column) => column);

  GeneratedColumn<int> get seed =>
      $composableBuilder(column: $table.seed, builder: (column) => column);

  GeneratedColumn<int> get firstScore => $composableBuilder(
    column: $table.firstScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get submittedAt => $composableBuilder(
    column: $table.submittedAt,
    builder: (column) => column,
  );
}

class $$PuzzleLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PuzzleLogsTable,
          PuzzleLogRow,
          $$PuzzleLogsTableFilterComposer,
          $$PuzzleLogsTableOrderingComposer,
          $$PuzzleLogsTableAnnotationComposer,
          $$PuzzleLogsTableCreateCompanionBuilder,
          $$PuzzleLogsTableUpdateCompanionBuilder,
          (
            PuzzleLogRow,
            BaseReferences<_$AppDatabase, $PuzzleLogsTable, PuzzleLogRow>,
          ),
          PuzzleLogRow,
          PrefetchHooks Function()
        > {
  $$PuzzleLogsTableTableManager(_$AppDatabase db, $PuzzleLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PuzzleLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PuzzleLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PuzzleLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> levelId = const Value.absent(),
                Value<int> seed = const Value.absent(),
                Value<int> firstScore = const Value.absent(),
                Value<int> submittedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PuzzleLogsCompanion(
                levelId: levelId,
                seed: seed,
                firstScore: firstScore,
                submittedAt: submittedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int levelId,
                required int seed,
                required int firstScore,
                required int submittedAt,
                Value<int> rowid = const Value.absent(),
              }) => PuzzleLogsCompanion.insert(
                levelId: levelId,
                seed: seed,
                firstScore: firstScore,
                submittedAt: submittedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PuzzleLogsTable, PuzzleLogRow>(table),
                  BaseReferences<_$AppDatabase, $PuzzleLogsTable, PuzzleLogRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PuzzleLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PuzzleLogsTable,
      PuzzleLogRow,
      $$PuzzleLogsTableFilterComposer,
      $$PuzzleLogsTableOrderingComposer,
      $$PuzzleLogsTableAnnotationComposer,
      $$PuzzleLogsTableCreateCompanionBuilder,
      $$PuzzleLogsTableUpdateCompanionBuilder,
      (
        PuzzleLogRow,
        BaseReferences<_$AppDatabase, $PuzzleLogsTable, PuzzleLogRow>,
      ),
      PuzzleLogRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$WordsTableTableManager get words =>
      $$WordsTableTableManager(_db, _db.words);
  $$SensesTableTableManager get senses =>
      $$SensesTableTableManager(_db, _db.senses);
  $$WordCharsTableTableManager get wordChars =>
      $$WordCharsTableTableManager(_db, _db.wordChars);
  $$WordStatsTableTableManager get wordStats =>
      $$WordStatsTableTableManager(_db, _db.wordStats);
  $$MetasTableTableManager get metas =>
      $$MetasTableTableManager(_db, _db.metas);
  $$PuzzleLogsTableTableManager get puzzleLogs =>
      $$PuzzleLogsTableTableManager(_db, _db.puzzleLogs);
}
