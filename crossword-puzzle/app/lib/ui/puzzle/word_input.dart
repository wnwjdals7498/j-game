// 단어 입력 (04-04.word-input.md). 격자 셀에 직접 타이핑하지 않는다 — 문서
// "핵심 결정" 그대로, 조합 중(composing) 상태 처리가 셀 단위 TextField로는
// 기기별 편차가 크기 때문이다. 하단 텍스트 필드 1개로 단어 전체를 받고,
// 확정된 음절만 [committedSyllables]로 걸러 격자에 반영한다
// (`PuzzleModel.setWordInput`, 04-03 selection_test.dart 옆의 puzzle_model.dart 참고).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/model/puzzle.dart';

/// 완성형 한글 음절만 남긴다. 조합 중인 자모(`ㄱ`, `ㅏ` 등)와 그 외 문자는
/// 버린다. **이게 IME 문제를 푸는 핵심이다** (04-04 "`_committed` — 확정
/// 음절만 남기기"):
/// - 조합 중 자모는 완성형 범위(U+AC00~U+D7A3) 밖 → 자동으로 걸러진다.
/// - 영문·숫자·공백도 걸러진다.
/// - 조합이 끝나 완성형이 되면 그때 격자에 반영된다.
///
/// `package:characters`의 `.characters`를 쓰는 이유: 이모지 등 서로게이트
/// 페어를 안전하게 순회하기 위해서다. 별도로 `import 'package:characters/…'`
/// 하지 않는 이유: `package:flutter/material.dart`가 이미 그 확장을
/// re-export한다 — 직접 import하면 `unnecessary_import` 린트가 걸린다
/// (`dart analyze`로 확인).
///
/// 문서 skeleton은 이 함수를 위젯 내부의 private `_committed`로 두지만,
/// 여기서는 최상위 public 함수로 뺐다. 04-02 `grid_view.dart`의
/// `cellForOffset`과 같은 이유다 — 04-04 테스트 표가 이 함수를 독립적으로
/// 단위 테스트하길 요구하는데(`word_input_test.dart`는 별도 라이브러리라
/// private 심볼에 접근할 수 없다), 위젯을 통째로 pump하지 않고도 검증할 수
/// 있게 하기 위해서다. 동작은 문서와 동일하다.
String committedSyllables(String raw) {
  final buf = StringBuffer();
  for (final ch in raw.characters) {
    final code = ch.runes.first;
    if (code >= 0xAC00 && code <= 0xD7A3) buf.write(ch);
  }
  return buf.toString();
}

/// 퍼즐 화면 하단의 단어 입력 필드. [selected]가 있어야 활성화되고, 그
/// 길이만큼만 입력을 받는다.
class WordInput extends StatefulWidget {
  /// 현재 선택된 단어. null이면 미선택 상태(필드 비활성).
  final PlacedWord? selected;

  /// [selected]가 바뀔 때 필드에 실을 현재 입력값 (`PuzzleModel.textOf`).
  final String initialText;

  /// 확정 음절 문자열이 바뀔 때마다 호출한다 (`PuzzleModel.setWordInput`).
  final void Function(String) onChanged;

  /// "다음" 버튼과 키보드의 다음 액션이 공유하는 콜백
  /// (`PuzzleModel.selectNextWord`).
  final VoidCallback onNext;

  const WordInput({
    super.key,
    required this.selected,
    required this.initialText,
    required this.onChanged,
    required this.onNext,
  });

  @override
  State<WordInput> createState() => _WordInputState();
}

class _WordInputState extends State<WordInput> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialText;
  }

  @override
  void didUpdateWidget(WordInput old) {
    super.didUpdateWidget(old);
    if (widget.selected != old.selected) {
      // 선택이 바뀌면 필드를 새 단어의 현재 입력으로 교체한다.
      _controller.text = widget.initialText;
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final len = widget.selected?.length ?? 0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: widget.selected != null,
            autofocus: false,
            // 문서 skeleton은 `maxLength: len`을 그대로 쓰지만, 미선택
            // 상태에서는 len == 0이라 `TextField`의
            // `maxLength > 0` 어서션(0을 유효한 길이로 인정하지 않는다)에
            // 걸려 위젯이 그대로 크래시한다 — DoD "미선택 상태" 자체가
            // 성립할 수 없게 되므로 문서의 의도에 맞게 0을 null로 바꾼다.
            maxLength: len > 0 ? len : null,
            // maxLengthEnforcement는 조합 중 글자 처리가 기기마다 다르다.
            // 우리가 직접 자른다 (아래 "길이 제한을 직접 자르는 이유").
            maxLengthEnforcement: MaxLengthEnforcement.none,
            textInputAction: TextInputAction.next,
            onChanged: _handle,
            onSubmitted: (_) => widget.onNext(),
            decoration: InputDecoration(
              counterText:
                  '${committedSyllables(_controller.text).length} / $len',
              hintText:
                  widget.selected == null ? '칸을 눌러 단어를 고르세요' : null,
            ),
          ),
        ),
        IconButton(
          onPressed: widget.selected == null ? null : widget.onNext,
          icon: const Icon(Icons.arrow_forward),
          tooltip: '다음 단어',
        ),
      ],
    );
  }

  void _handle(String raw) {
    final len = widget.selected?.length ?? 0;
    var s = committedSyllables(raw);
    if (s.length > len) {
      s = s.substring(0, len);
      _controller.text = s;
      _controller.selection = TextSelection.collapsed(offset: s.length);
    }
    widget.onChanged(s);
  }
}
