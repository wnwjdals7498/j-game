// manifest.json 파싱 (05-01 계약). `tools/release_db.py`가 만드는 형식과 반드시
// 같아야 한다 — 샘플은 tools/fixtures/manifest_sample.json과
// app/test/fixtures/manifest_sample.json에 동일한 내용으로 있다(05-01).

class ManifestError implements Exception {
  final String message;
  const ManifestError(this.message);

  @override
  String toString() => 'ManifestError: $message';
}

/// 05-01의 manifest.json 계약. **모르는 필드는 무시한다** — 05-01이 "필드를
/// 추가할 수는 있어도 제거·의미 변경은 안 된다"고 못박은 것의 앱 쪽 반쪽이다.
class Manifest {
  final int dbVersion;
  final int schemaVersion;
  final String url;
  final String sha256;
  final int sizeBytes;
  final String minAppVersion;
  final String publishedAt;
  final int wordCount;
  final String notes;

  const Manifest({
    required this.dbVersion,
    required this.schemaVersion,
    required this.url,
    required this.sha256,
    required this.sizeBytes,
    required this.minAppVersion,
    required this.publishedAt,
    required this.wordCount,
    required this.notes,
  });

  /// 필수 필드가 없거나 타입이 다르면 [ManifestError]. `word_count`/`notes`는
  /// 05-01 표에서도 선택 필드라 없으면 기본값(0/'')으로 채운다.
  factory Manifest.fromJson(Map<String, dynamic> j) {
    int reqInt(String k) {
      final v = j[k];
      if (v is int) return v;
      throw ManifestError('필드 누락/타입 오류: $k');
    }

    String reqStr(String k) {
      final v = j[k];
      if (v is String) return v;
      throw ManifestError('필드 누락/타입 오류: $k');
    }

    return Manifest(
      dbVersion: reqInt('db_version'),
      schemaVersion: reqInt('schema_version'),
      url: reqStr('url'),
      sha256: reqStr('sha256'),
      sizeBytes: reqInt('size_bytes'),
      minAppVersion: reqStr('min_app_version'),
      publishedAt: reqStr('published_at'),
      wordCount: j['word_count'] is int ? j['word_count'] as int : 0,
      notes: j['notes'] is String ? j['notes'] as String : '',
    );
  }
}

/// "1.2.3" 형식 버전 비교. `a >= b`면 true. 문자열 비교(`"1.10.0" < "1.9.0"`)를
/// 쓰지 않는다 — 05-02가 지목한 흔한 버그. 자릿수가 다르면(`"1.2"` vs
/// `"1.2.0"`) 짧은 쪽을 0으로 채운다.
bool versionAtLeast(String a, String b) {
  final pa = a.split('.').map(int.parse).toList();
  final pb = b.split('.').map(int.parse).toList();
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x > y;
  }
  return true;
}
