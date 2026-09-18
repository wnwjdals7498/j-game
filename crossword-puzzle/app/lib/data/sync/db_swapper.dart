// 통계 보존 + 원자 교체 (05-03). DESIGN 4절 핵심 설계("word_stat은 건드리지
// 않음")가 여기서 실현된다. 05-02의 SyncService가 이 클래스의 `swap`을
// `DbSwap` 타입(sync_service.dart)에 맞는 함수로 그대로 주입받는다.
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../db/app_database.dart';

class DbSwapper {
  DbSwapper({
    required AppDatabase Function(File) open,
    required this.currentFile,
    this.seedAsset = 'assets/words.sqlite',
    // ignore: prefer_initializing_formals
  }) : _open = open;

  /// 주입: 테스트 용이성. 실제로는 `(f) => AppDatabase(NativeDatabase(f))`.
  /// 외부에는 `open`으로 노출하고 내부적으로만 `_open`으로 갈무리한다 —
  /// `this._open` 초기화 축약형을 쓰면 생성자 인자 이름 자체가 `_open`이 돼
  /// 다른 파일에서 이 이름 있는 인자를 못 넘긴다(프라이빗 식별자라서).
  final AppDatabase Function(File) _open;

  /// 살아있는 DB 파일 경로 (앱 문서 디렉터리의 `words.sqlite`).
  final File currentFile;

  /// [reseedFromAsset] 이 rootBundle에서 읽어올 자산 경로.
  final String seedAsset;

  /// 갱신 시 보존할 테이블. `puzzle_log`를 빠뜨리기 쉽다 — 03-04에서 뒤늦게
  /// 추가된 테이블이라 `tools/schema.sql`을 처음 볼 때 놓치기 쉽기 때문이다.
  static const _preserved = ['word_stat', 'puzzle_log'];

  /// [newDb]는 검증이 끝난 새 DB 파일(05-02가 다운로드한 임시 파일, 또는
  /// [reseedFromAsset]이 만든 시드 사본)이다. 성공하면 새로 연 [AppDatabase]를
  /// 반환한다 — 인자로 받은 [current]는 이 메서드 안에서 닫히므로, 호출자는
  /// 이후 반환값을 써야 한다(계속 [current]를 쓰면 닫힌 연결에 질의하게 된다).
  Future<AppDatabase> swap(AppDatabase current, File newDb) async {
    // 1~3. 새 DB에 기존 것을 붙여 통계를 복사한다. 기존 DB에 ATTACH해서
    // 쓰면 기존 파일을 건드리게 되고, 중간에 실패하면 기존 DB가 손상된다 —
    // 그래서 복사는 새 DB 쪽에서 한다.
    await _copyPreservedTables(newDb, currentFile);

    // 4. 기존 연결을 닫는다. 이걸 안 하면 rename이 실패할 수 있다.
    await current.close();

    // 5. 원자 교체
    final backup = File('${currentFile.path}.bak');
    if (await backup.exists()) await backup.delete();
    if (await currentFile.exists()) {
      await currentFile.rename(backup.path); // 기존 것을 백업으로
    }
    try {
      await newDb.rename(currentFile.path);
    } catch (e) {
      // 롤백: 백업을 되돌린다. 이 롤백 자체가 실패해도 원래 예외([e])를
      // 삼켜서는 안 된다 — 그래야 SyncResult.error가 "무엇이 실패했는지"를
      // 보여준다(복구 실패 시의 디스크 상태는 recoverOrCopySeed가 다음 실행에
      // 처리한다).
      try {
        if (await backup.exists()) await backup.rename(currentFile.path);
      } catch (_) {}
      rethrow;
    }

    // 6. 새 DB를 연다. 여기서 실패하면(손상된 파일 등) 이미 옮겨 놓은
    // newDb를 되돌리고 백업을 복구한다 — 안 그러면 검증에 실패한 새 DB가
    // 살아있는 자리를 차지한 채, 유일하게 온전한 사본인 백업은
    // `recoverOrCopySeed`가 "words.sqlite가 이미 있다"고 보고 절대 안
    // 건드리는 상태로 영영 남는다(유저 통계가 든 유일한 사본이 미아가 된다).
    AppDatabase? opened;
    try {
      opened = _open(currentFile);
      await opened.wordCount; // 열리는지 즉시 확인
    } catch (e) {
      // 반드시 먼저 닫는다 — sqlite는 Windows에서 열린 파일에 FILE_SHARE_DELETE
      // 를 안 주므로, opened를 안 닫으면 바로 아래 delete/rename이 전부
      // 조용히(catch로 삼켜져) 실패해 롤백이 통째로 무효가 된다.
      try {
        await opened?.close();
      } catch (_) {}
      try {
        await currentFile.delete();
      } catch (_) {}
      try {
        if (await backup.exists()) await backup.rename(currentFile.path);
      } catch (_) {}
      rethrow;
    }
    final next = opened;

    // 성공했으니 백업 삭제. 실패해도 무해하므로(용량만 남는다) 예외를 삼킨다.
    try {
      if (await backup.exists()) await backup.delete();
    } catch (_) {}

    return next;
  }

  /// 시드 DB로 되돌리되 통계는 보존한다 (03-02 "스키마 버전 불일치 정책").
  /// `db_bootstrap.dart`의 `open()`이 `SchemaMismatch`를 잡아 이 메서드를
  /// 호출한다(`open_native.dart`의 `makeReseeder` 참고).
  Future<AppDatabase> reseedFromAsset(AppDatabase current) async {
    final tmp = File('${currentFile.path}.seed');
    try {
      final bytes = await rootBundle.load(seedAsset);
      await tmp.writeAsBytes(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        flush: true,
      );
      return await swap(current, tmp);
    } catch (e) {
      // swap()이 tmp를 이미 옮겼을 수도, 아직 그대로일 수도 있다 — 어느
      // 쪽이든 존재하면 임시 파일이 남지 않게 정리한다.
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _copyPreservedTables(File target, File source) async {
    // 기존 DB 파일 자체가 없을 수 있다(방어적으로만 다룬다 — 갱신은 기존 DB가
    // 있어야 호출될 일이 있다). 보존할 것이 없으면 그냥 넘어간다.
    if (!await source.exists()) return;

    final db = _open(target);
    try {
      await db.customStatement('ATTACH DATABASE ? AS old', [source.path]);
      try {
        for (final t in _preserved) {
          // 기존 DB에 그 테이블이 없을 수도 있다 (03-04 이전의 구 DB에서
          // 올라온 경우 — puzzle_log가 아예 없다).
          final exists = await db.customSelect(
            "SELECT 1 FROM old.sqlite_master WHERE type='table' AND name=?",
            variables: [Variable.withString(t)],
          ).getSingleOrNull();
          if (exists == null) continue;

          await db.customStatement('DELETE FROM main.$t');
          await _insertPreserved(db, t);
        }
      } finally {
        await db.customStatement('DETACH DATABASE old');
      }
    } finally {
      await db.close();
    }
  }

  /// 컬럼을 명시한다 — `INSERT ... SELECT *`는 두 DB의 컬럼 순서가 같다는
  /// 가정에 기대는데, 조용히 어긋나는 것보다 여기서 확실히 하는 게 낫다.
  /// `tools/schema.sql`을 고치면 여기 컬럼 목록도 고친다(PLAN.md 3절 계약).
  Future<void> _insertPreserved(AppDatabase db, String table) async {
    switch (table) {
      case 'word_stat':
        await db.customStatement(
          'INSERT INTO main.word_stat (headword, correct, wrong, last_seen) '
          'SELECT headword, correct, wrong, last_seen FROM old.word_stat',
        );
      case 'puzzle_log':
        await db.customStatement(
          'INSERT INTO main.puzzle_log (level_id, seed, first_score, submitted_at) '
          'SELECT level_id, seed, first_score, submitted_at FROM old.puzzle_log',
        );
      default:
        throw StateError('_preserved에 컬럼 목록이 없는 테이블: $table');
    }
  }
}
