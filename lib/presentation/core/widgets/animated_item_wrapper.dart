import 'package:flutter/material.dart';

/// Reusable animated wrapper for list/grid items.
/// Combines an AnimatedSwitcher with a subtle scale+fade tween
/// so resorting or content changes feel smoother.
class AnimatedItemWrapper extends StatelessWidget {
  final Key switchKey;
  final Widget child;
  final Duration switchDuration;
  final Duration tweenDuration;

  const AnimatedItemWrapper({
    super.key,
    required this.switchKey,
    required this.child,
    this.switchDuration = const Duration(milliseconds: 280),
    this.tweenDuration = const Duration(milliseconds: 260),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: switchDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1.0).animate(anim),
          child: child,
        ),
      ),
      child: KeyedSubtree(
        key: switchKey,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.98, end: 1.0),
          duration: tweenDuration,
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            final opacity = ((value - 0.95) / 0.05).clamp(0.0, 1.0);
            return Opacity(
              opacity: opacity,
              child: Transform.scale(scale: value, child: child),
            );
          },
          child: child,
        ),
      ),
    );
  }
}

