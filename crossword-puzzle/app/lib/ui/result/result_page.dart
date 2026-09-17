// 결과 화면 (04-01 빈 껍데기). 실제 내용(단어별 채점·뜻풀이)은 04-05에서 채운다.
import 'package:flutter/material.dart';

class ResultPage extends StatelessWidget {
  const ResultPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('결과')),
      body: const Center(child: Text('결과 (04-05에서 채움)')),
    );
  }
}
