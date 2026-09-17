import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:jgame/data/db/app_database.dart';
import 'package:jgame/data/drift_word_repository.dart';
import 'package:jgame/domain/generator/grid_generator.dart';
import 'package:jgame/domain/levels.dart';
import 'package:jgame/domain/model/puzzle.dart';

/// 난이도 체감 확인 도구 (03-06 "난이도 체감 확인" 절).
///
/// 레벨 1개를 seed로 생성해 격자를 아스키로 그리고, 단어별 힌트(사전 뜻풀이)를
/// 출력한다. **HUMAN이 이 출력을 보고 직접 풀어보는 용도다.** 이 도구는 콘솔
/// 출력만 만든다 — 실제로 사람이 풀어 체감 항목(03-06 "확인 항목" 4개)을
/// 판정하는 것은 이 도구의 범위 밖이고, 여전히 사람이 해야 한다.
///
/// 사용법 (`app/` 디렉터리에서):
///   dart run tool/print_puzzle.dart --level 5 --seed 123
///   dart run tool/print_puzzle.dart --level 5 --seed 123 --answers   (정답도 출력)
///
/// `tool/measure_real.dart` 와 같은 이유로 assets 원본을 직접 열지 않고 임시
/// 복사본을 연다(word_stat 오염 방지, 03-05 "막히면").
Future<void> main(List<String> args) async {
  final levelId = _intArg(args, '--level', 1);
  final seed = _intArg(args, '--seed', 1);
  final showAnswers = args.contains('--answers');
  final dbPath = _strArg(args, '--db', 'assets/words.sqlite');

  final tmp = File('${Directory.systemTemp.path}/'
      'print_puzzle_${DateTime.now().microsecondsSinceEpoch}.sqlite');
  await File(dbPath).copy(tmp.path);

  final db = AppDatabase(NativeDatabase(tmp));
  final repo = DriftWordRepository(db);

  try {
    final spec = levelById(levelId);
    final gen = GridGenerator(repo);
    final outcome = await gen.tryGenerate(spec, seed);
    final puzzle = outcome.puzzle;
    if (puzzle == null) {
      stderr.writeln('생성 실패: 레벨 $levelId seed $seed '
          '(시도 ${outcome.stats.attempts}회, ${outcome.stats.failReason})');
      exit(1);
    }

    final definitions = await _fetchDefinitions(db, puzzle);

    stdout.writeln('레벨 $levelId (${spec.name}) — ${spec.width}×${spec.height}, '
        'seed $seed (실제 attemptSeed ${puzzle.seed}), '
        '${outcome.stats.attempts}번째 시도 성공');
    stdout.writeln();
    stdout.writeln(_renderGrid(puzzle));
    stdout.writeln();
    stdout.writeln(_renderClues(puzzle, definitions, showAnswers: showAnswers));
  } finally {
    await db.close();
    if (tmp.existsSync()) tmp.deleteSync();
  }
}

/// 퍼즐에 쓰인 표제어들의 대표 뜻풀이 1개씩. `sense` 는 WordRepository 계약
/// 밖이라(01-02) 여기서만 직접 SQL을 쓴다 — 이 도구는 진단용이라 괜찮다.
/// 4단계 실제 힌트 선택 로직은 `plan/04-03.selection-and-hint.md` 가 정한다.
Future<Map<String, String>> _fetchDefinitions(
    AppDatabase db, Puzzle puzzle) async {
  final headwords = puzzle.words.map((w) => w.headword).toSet().toList();
  if (headwords.isEmpty) return {};

  final placeholders = List.filled(headwords.length, '?').join(',');
  final rows = await db.customSelect(
    'SELECT headword, MIN(sense_id) AS sid, definition FROM sense '
    'WHERE headword IN ($placeholders) GROUP BY headword',
    variables: headwords.map((h) => Variable.withString(h)).toList(),
  ).get();

  return {
    for (final r in rows)
      r.read<String>('headword'): r.read<String>('definition'),
  };
}

/// 격자를 아스키로 그린다. 정답 음절은 감추고 슬롯 시작점에 번호를 매긴다
/// (표준 십자말풀이 표기와 같음). 빈 칸(단어가 지나지 않는 칸)은 공백.
String _renderGrid(Puzzle puzzle) {
  final numberAt = _numberSlots(puzzle);
  final b = StringBuffer();

  for (var r = 0; r < puzzle.height; r++) {
    final line = StringBuffer();
    for (var c = 0; c < puzzle.width; c++) {
      final cell = puzzle.cellAt(r, c);
      if (cell.blocked) {
        line.write('███');
        continue;
      }
      final n = numberAt[(r, c)];
      line.write(n != null ? n.toString().padLeft(2).padRight(3) : ' · ');
    }
    b.writeln(line.toString());
  }
  return b.toString().trimRight();
}

/// (row, col) → 슬롯 번호. 시작 셀 기준 reading order(위→아래, 왼→오른쪽)로
/// 매긴다. 가로·세로가 같은 칸에서 시작하면 번호 하나를 공유한다(표준 표기).
Map<(int, int), int> _numberSlots(Puzzle puzzle) {
  final starts = puzzle.words.map((w) => (w.row, w.col)).toSet().toList()
    ..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  return {for (var i = 0; i < starts.length; i++) starts[i]: i + 1};
}

/// 단어별 힌트(뜻풀이) 목록. 코어/채움, 티어를 같이 보여준다(체감 확인용 —
/// 실제 게임 UI는 이런 메타를 유저에게 보여주지 않는다).
String _renderClues(
  Puzzle puzzle,
  Map<String, String> definitions, {
  required bool showAnswers,
}) {
  final numberAt = _numberSlots(puzzle);
  final across =
      puzzle.words.where((w) => w.dir == Direction.across).toList();
  final down = puzzle.words.where((w) => w.dir == Direction.down).toList();
  for (final list in [across, down]) {
    list.sort((a, b) {
      final na = numberAt[(a.row, a.col)]!;
      final nb = numberAt[(b.row, b.col)]!;
      return na - nb;
    });
  }

  String line(PlacedWord w) {
    final n = numberAt[(w.row, w.col)];
    final tag = w.isCore ? '핵심' : '채움';
    final def = definitions[w.headword] ?? '(뜻풀이 없음)';
    final answer = showAnswers ? ' = ${w.headword}' : '';
    return '  $n. [$tag t${w.tier}, ${w.length}음절]$answer — $def';
  }

  final b = StringBuffer()
    ..writeln('가로:')
    ..writeAll(across.map(line).map((s) => '$s\n'))
    ..writeln('세로:')
    ..writeAll(down.map(line).map((s) => '$s\n'));
  return b.toString().trimRight();
}

int _intArg(List<String> args, String name, int fallback) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return fallback;
  return int.tryParse(args[i + 1]) ?? fallback;
}

String _strArg(List<String> args, String name, String fallback) {
  final i = args.indexOf(name);
  if (i < 0 || i + 1 >= args.length) return fallback;
  return args[i + 1];
}
