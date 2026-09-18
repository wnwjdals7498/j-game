// SyncService.sync()의 결과 타입 (05-02).

enum SyncOutcome {
  skippedNotDue,
  skippedOffline,
  skippedUpToDate,
  skippedSchemaIncompatible,
  skippedAppTooOld,
  failedDownload,
  failedChecksum,
  failedSanity,
  failedSwap,
  success,
}

class SyncResult {
  final SyncOutcome outcome;
  final int? newDbVersion;
  final int? wordCount;
  final Object? error;

  const SyncResult(this.outcome, {this.newDbVersion, this.wordCount, this.error});

  @override
  String toString() =>
      'SyncResult($outcome, newDbVersion: $newDbVersion, '
      'wordCount: $wordCount, error: $error)';
}
