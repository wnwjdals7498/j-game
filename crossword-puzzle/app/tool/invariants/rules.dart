// tool/invariants/rules.dart
//
// UI-GUIDE.md 7절 INV 표의 Dart 사본. 규칙은 데이터로만 선언하고 해석은
// runner.dart가 한다 — 규칙을 추가할 때 실행기를 건드리지 않게 하기 위해서다.
// 여기서 규칙을 바꾸면 UI-GUIDE 7절 표도 같은 커밋에서 고친다.

/// 규칙 해석 방식. runner.dart의 switch와 1:1이다.
enum Kind { mustContain, mustNotContain, testNamesExist, levelsMax, depsExact, gitClean }

class Rule {
  final String id;              // 7절 표의 ID. a/b/c 접미는 한 INV의 분할
  final String title;           // 출력에 그대로 찍히는 한글 이름
  final Kind kind;
  final List<String> paths;     // root 기준 상대 경로. 디렉터리면 .dart 재귀
  final List<String> exclude;   // paths 안에서 건너뛸 경로 접두
  final List<String> needles;   // 찾을 / 없어야 할 문자열
  final int? max;               // levelsMax 전용
  const Rule(this.id, this.title, this.kind, {this.paths = const [],
      this.exclude = const [], this.needles = const [], this.max});
}

/// INV-08. UI-GUIDE 7절 "INV-08 보호 테스트 목록" 24개를 순서 그대로.
/// 전부 app/test/ui/*.dart에 실재하는 이름이다(2026-09-18 확인).
const protectedTests = <String>[
  '탭 → 셀 변환: (cell*2.5, cell*1.5) 탭 → (row 1, col 2)',
  '검은 칸 탭은 무시된다 (onCellTap 미호출)',
  '격자 크기: 5×5 퍼즐 → 위젯 크기가 정사각형',
  'shouldRepaint: 같은 입력 → false, 입력 변경 → true',
  '레벨 1 항상 해제: 통계 없어도 탭 가능',
  '잠금 표시: 이전 레벨 미클리어 → 자물쇠',
  '잠긴 레벨 탭: 이동 안 함, 스낵바 안내',
  '해제 레벨 탭: 퍼즐 화면으로, 새 seed',
  '힌트 모드 변경: SettingsModel 저장, 재시작 후 유지',
  '4개 자료명이 전부 보임 + assets/LICENSES.md와 동일한 문구',
  '1. 루프 전체: 홈 → 퍼즐 → 제출 → 결과 → 다음 레벨',
  '2. 격자 탭 → 올바른 단어 선택: 힌트 패널이 그 단어',
  '3. 입력 → 셀 반영: 격자에 글자',
  '5. 다시 풀기: 같은 퍼즐, 입력 초기화',
  '9. 생성 실패: GenerationFailed → 에러 화면, 크래시 없음',
  '교차 셀 두 번째 탭 → 세로 단어로 토글',
  '길이 초과 차단: 3글자 자리에 4글자 입력 → 3글자로 잘림',
  '완성형만: 조합 중 자모를 버린다',
  '빈칸 있음: 빈칸 개수 문구 표시',
  '재제출: isFirstSubmit == false, word_stat 불변',
  '상태 구분: 정답/오답/빈칸 아이콘이 다름',
  '마지막 레벨: "다음 레벨" 대신 "홈으로"',
  '레벨 해제 조건이어도 재제출이면 안내 없음',
  '처음 퍼즐에 들어가면 조작법 안내가 한 번 뜬다',
];

/// INV-09. UI-GUIDE 7절 "INV-09 유지 문구" 13개.
const protectedStrings = <String>[
  '제출', '다시 풀기', '다음 레벨', '홈으로', '설정', '출처 및 라이선스',
  '칸을 눌러 단어를 고르세요', '이전 레벨을 클리어해야 열립니다',
  '재제출이라 기록에 반영되지 않았습니다', '모든 칸을 채웠습니다.',
  '이렇게 플레이해요', '누적 정답률', '푼 단어',
];

/// INV-11. 현재 pubspec.yaml dependencies 13개와 집합이 같아야 한다.
const allowedDeps = <String>{
  'flutter', 'cupertino_icons', 'drift', 'drift_flutter', 'sqlite3_flutter_libs',
  'path_provider', 'provider', 'shared_preferences', 'http', 'crypto',
  'connectivity_plus', 'package_info_plus', 'sqlite3',
};

const _grid = ['lib/ui/puzzle/grid_painter.dart', 'lib/ui/puzzle/grid_view.dart'];

const rules = <Rule>[
  Rule('INV-01', '세로 고정', Kind.mustContain,
      paths: ['lib/main.dart'], needles: ['DeviceOrientation.portraitUp']),
  Rule('INV-02a', 'IME 하단 필드', Kind.mustContain,
      paths: ['lib/ui/puzzle/word_input.dart'], needles: ['TextField', 'committedSyllables(']),
  Rule('INV-02b', '격자에 텍스트 입력 없음', Kind.mustNotContain,
      paths: _grid, needles: ['TextField', 'EditableText']),
  Rule('INV-03', '격자 정답 미노출', Kind.mustNotContain,
      paths: ['lib/ui/puzzle/grid_painter.dart'], needles: ['.headword']),
  Rule('INV-04a', '격자 정답/오답 모양 구분', Kind.mustContain,
      paths: ['lib/ui/puzzle/grid_painter.dart'], needles: ['drawCircle', 'drawLine']),
  Rule('INV-04b', '결과 정답/오답 아이콘 구분', Kind.mustContain,
      paths: ['lib/ui/result/result_page.dart'], needles: ['Icons.check_circle', 'Icons.cancel']),
  Rule('INV-05', '하드코딩 색 금지', Kind.mustNotContain,   // transparent는 실행기가 허용
      paths: ['lib/ui', 'lib/main.dart'], exclude: ['lib/ui/theme/'],
      needles: ['Color(0x', 'Colors.']),
  Rule('INV-06a', '라이선스 화면', Kind.mustContain,
      paths: ['lib/ui/settings/license_page.dart'], needles: ['assets/LICENSES.md']),
  Rule('INV-06b', '라이선스 진입점', Kind.mustContain,
      paths: ['lib/ui/settings/settings_page.dart'], needles: ["'출처 및 라이선스'"]),
  Rule('INV-06c', '라이선스 에셋 등록', Kind.mustContain,
      paths: ['pubspec.yaml'], needles: ['assets/LICENSES.md']),
  Rule('INV-07', 'domain/data 무수정', Kind.gitClean, paths: ['lib/domain', 'lib/data']),
  Rule('INV-08', '보호 테스트 존재', Kind.testNamesExist, paths: ['test'], needles: protectedTests),
  Rule('INV-09', '사용자 문구 유지', Kind.mustContain, paths: ['lib/ui'], needles: protectedStrings),
  Rule('INV-10', '격자 상한 8', Kind.levelsMax, paths: ['lib/domain/levels.dart'], max: 8),
  Rule('INV-11', '새 의존성 금지', Kind.depsExact, paths: ['pubspec.yaml']),
];
