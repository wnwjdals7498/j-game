// 홈 화면 (04-01 빈 껍데기). 실제 내용(레벨 목록·누적 통계)은 04-06에서 채운다.
import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('단어 연상 퀴즈')),
      body: const Center(child: Text('홈 (04-06에서 채움)')),
    );
  }
}
