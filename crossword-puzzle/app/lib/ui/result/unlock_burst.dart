// lib/ui/result/unlock_burst.dart
//
// 07-06-03 산출물: 레벨 해제 연출(E-08, UI-GUIDE 3.3). 첫 제출로 다음 레벨이
// 열렸을 때만, 헤더 위로 사각 조각 24개가 1회 떨어진다. 외부 컨페티 패키지
// 없이 자체 `CustomPainter`로 그린다(N-05, INV-11).
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

const int _pieceCount = 24; // UI-GUIDE 3.3 E-08 "사각 조각 24개"
const double _pieceW = 6, _pieceH = 10; // 07-06 부모 문서 도식
const double _startY = 20, _overshoot = 40;
const double _maxDelay = 0.2, _fadeStart = 0.7;

/// 전 필드 `operator ==`/`hashCode`를 붙인다 — 결정성 테스트가 두 리스트를
/// `equals`로 비교한다.
@immutable
class BurstPiece {
  final double xRatio; // 0~1. 실제 x = xRatio * 폭
  final double fall; // 낙하 속도 배수
  final double spin; // 회전 바퀴 수 (부호가 방향)
  final double delay; // 0~0.2, 진행값 기준
  final int colorIndex; // 0 ink / 1 accent / 2 accentSoft

  const BurstPiece({
    required this.xRatio,
    required this.fall,
    required this.spin,
    required this.delay,
    required this.colorIndex,
  });

  @override
  bool operator ==(Object other) =>
      other is BurstPiece &&
      other.xRatio == xRatio &&
      other.fall == fall &&
      other.spin == spin &&
      other.delay == delay &&
      other.colorIndex == colorIndex;

  @override
  int get hashCode => Object.hash(xRatio, fall, spin, delay, colorIndex);
}

/// `Random(42)` 고정 시드라 실행·플랫폼과 무관하게 같은 배치가 나온다
/// (07-06 "결정성", 골든 재현성). `Random()`(시드 없음)은 쓰지 않는다.
List<BurstPiece> buildBurstPieces() {
  final rnd = Random(42);
  return [
    for (var i = 0; i < _pieceCount; i++)
      BurstPiece(
        xRatio: rnd.nextDouble(),
        fall: 0.85 + rnd.nextDouble() * 0.3,
        spin: rnd.nextDouble() * 4 - 2,
        delay: rnd.nextDouble() * _maxDelay,
        colorIndex: i % 3, // 24 / 3 → ink·accent·accentSoft 정확히 8개씩
      ),
  ];
}

final List<BurstPiece> kBurstPieces = buildBurstPieces();

class _BurstPainter extends CustomPainter {
  final double t; // 0 → 1
  final Color ink, accent, accentSoft; // List로 받으면 shouldRepaint 비교가 항상 true다
  const _BurstPainter(
      {required this.t,
      required this.ink,
      required this.accent,
      required this.accentSoft});

  @override
  void paint(Canvas canvas, Size size) {
    final palette = [ink, accent, accentSoft];
    final alpha = t <= _fadeStart
        ? 1.0
        : (1 - (t - _fadeStart) / (1 - _fadeStart)).clamp(0.0, 1.0).toDouble();
    for (final p in kBurstPieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      canvas.save();
      canvas.translate(p.xRatio * size.width,
          -_startY + local * p.fall * (size.height + _startY + _overshoot));
      canvas.rotate(p.spin * 2 * pi * local);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: _pieceW, height: _pieceH),
        Paint()..color = palette[p.colorIndex].withValues(alpha: alpha),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) =>
      old.t != t ||
      old.ink != ink ||
      old.accent != accent ||
      old.accentSoft != accentSoft;
}

// 낙하 규칙: 헤더 위 -20에서 출발해 헤더 아래 +40까지 내려간다. 회전은
// 진행값에 비례하고, 알파는 t > 0.7부터 선형으로 0이 된다. t가 바뀔 때만
// 다시 그린다.

class UnlockBurst extends StatefulWidget {
  const UnlockBurst({super.key});

  @override
  State<UnlockBurst> createState() => _UnlockBurstState();
}

class _UnlockBurstState extends State<UnlockBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);
  late final Animation<double> _t;
  bool _started = false, _done = false;

  @override
  void didChangeDependencies() {
    // GameMotion.of는 context가 필요해 initState에서 못 쓴다. _started 플래그가
    // "initState에서 한 번"과 같은 보장을 준다 — 리빌드해도 다시 재생하지 않는다.
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final motion = GameMotion.of(context);
    _c.duration = motion.celebrate; // 감소 모션이면 0 → 즉시 완료
    _t = CurvedAnimation(parent: _c, curve: motion.curveStandard);
    _c.forward().whenComplete(() {
      if (mounted) setState(() => _done = true);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return const SizedBox.shrink(); // 끝나면 스스로 사라진다
    final c = GameColors.of(context);
    return IgnorePointer(
      // 버튼 탭을 가로채지 않는다
      child: AnimatedBuilder(
        animation: _t,
        builder: (_, _) => CustomPaint(
            painter: _BurstPainter(
                t: _t.value, ink: c.ink, accent: c.accent, accentSoft: c.accentSoft)),
      ),
    );
  }
}
