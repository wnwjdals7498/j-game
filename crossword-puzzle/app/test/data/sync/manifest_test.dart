// Manifest.fromJson / versionAtLeast 테스트 (05-02).
//
// 05-01의 샘플 fixture(app/test/fixtures/manifest_sample.json)를 그대로 읽어
// 파싱한다 — tools/fixtures/manifest_sample.json과 바이트가 같아야 한다는
// 계약은 tools/tests/test_release_db.py 쪽에서 확인한다(05-01).
import 'dart:convert';
import 'dart:io';

import 'package:jgame/data/sync/manifest.dart';
import 'package:test/test.dart';

Map<String, dynamic> _sample() =>
    jsonDecode(File('test/fixtures/manifest_sample.json').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('Manifest.fromJson', () {
    test('05-01 샘플 JSON → 모든 필드', () {
      final m = Manifest.fromJson(_sample());
      expect(m.dbVersion, 3);
      expect(m.schemaVersion, 1);
      expect(m.url,
          'https://github.com/wnwjdals7498/j-game/releases/download/db-v3/words-v3.sqlite');
      expect(m.sha256, hasLength(64));
      expect(m.sizeBytes, 9800000);
      expect(m.minAppVersion, '1.0.0');
      expect(m.publishedAt, '2027-03-01');
      expect(m.wordCount, 26000);
      expect(m.notes, '2027년 3월 사전 갱신');
    });

    test('모르는 필드는 무시하고 파싱 성공', () {
      final json = {..._sample(), 'future_field': 'nobody knows this yet'};
      expect(() => Manifest.fromJson(json), returnsNormally);
    });

    test('필수 필드 누락 → ManifestError', () {
      final json = _sample()..remove('sha256');
      expect(() => Manifest.fromJson(json), throwsA(isA<ManifestError>()));
    });

    test('타입 오류 → ManifestError', () {
      final json = {..._sample(), 'db_version': '3'}; // 문자열로 옴
      expect(() => Manifest.fromJson(json), throwsA(isA<ManifestError>()));
    });
  });

  group('versionAtLeast', () {
    test('1.10.0 >= 1.9.0 → true (문자열 비교였다면 false)', () {
      expect(versionAtLeast('1.10.0', '1.9.0'), isTrue);
    });

    test('자릿수 다름: 1.2 >= 1.2.0 → true', () {
      expect(versionAtLeast('1.2', '1.2.0'), isTrue);
    });
  });
}
