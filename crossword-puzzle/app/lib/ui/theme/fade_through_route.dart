// lib/ui/theme/fade_through_route.dart
//
// E-09 화면 전환 (07-07-01). "모양은 PageTransitionsTheme이, 시간은 GameRoute가"
// 정한다 — PageTransitionsBuilder는 지속 시간을 정할 수 없기 때문이다.
// `0.3`(페이드 구간)·`0.98`(2% 스케일)은 UI-GUIDE 3.3 E-09 행이 정한 값이고
// 새 값이 아니라 `lib/ui/theme/` 안에 둬도 INV-05·INV-12에 걸리지 않는다.
import 'package:flutter/material.dart';

import 'motion.dart';

class FadeThroughPageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeThroughPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(PageRoute<T>? route, BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return FadeTransition(                      // 나가는 화면: 0~0.3 구간에 1→0
      opacity: Tween<double>(begin: 1, end: 0).animate(
        CurvedAnimation(parent: secondaryAnimation, curve: const Interval(0.0, 0.3))),
      child: FadeTransition(                    // 들어오는 화면: 0.3~1.0 구간에 0→1
        opacity: CurvedAnimation(parent: animation, curve: const Interval(0.3, 1.0)),
        child: ScaleTransition(                 // + 2% 스케일, curveEmphasized
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(CurvedAnimation(
              parent: animation, curve: GameMotion.of(context).curveEmphasized)),
          child: child)),
    );
  }
}

class GameRoute<T> extends PageRouteBuilder<T> {
  GameRoute({required WidgetBuilder builder, super.settings})
      : super(pageBuilder: (context, _, _) => builder(context));

  /// `navigator`는 `install()` 직전에 채워지고 `transitionDuration`은 그 뒤에
  /// 읽힌다. 라우트를 만드는 `onGenerateRoute`에는 context가 없으므로 늦게
  /// 읽는다 — 그래야 감소 모션이 `Duration.zero`로 내려온다.
  @override
  Duration get transitionDuration {
    final nav = navigator;
    return nav == null ? GameMotion.standard.base : GameMotion.of(nav.context).base;
  }
  @override
  Duration get reverseTransitionDuration => transitionDuration;
  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
          Animation<double> secondaryAnimation, Widget child) =>
      const FadeThroughPageTransitionsBuilder().buildTransitions<T>(
          this, context, animation, secondaryAnimation, child);
}
