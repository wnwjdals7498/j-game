// 퍼즐 화면 (04-01 빈 껍데기). 실제 내용(격자·힌트·입력·제출)은
// 04-02~04-05에서 채운다.
import 'package:flutter/material.dart';

class PuzzlePage extends StatelessWidget {
  const PuzzlePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('퍼즐')),
      body: const Center(child: Text('퍼즐 (04-02~04-05에서 채움)')),
    );
  }
}
