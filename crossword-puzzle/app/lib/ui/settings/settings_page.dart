// 설정·정보 화면 (04-01 빈 껍데기). 실제 내용(힌트 모드·출처·라이선스)은
// 04-06에서 채운다.
import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정·정보')),
      body: const Center(child: Text('설정·정보 (04-06에서 채움)')),
    );
  }
}
