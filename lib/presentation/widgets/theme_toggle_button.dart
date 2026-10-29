import 'package:flutter/material.dart';

import '../theme/theme_controller.dart';

/// Icon button cycling between system, light and dark themes.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.of(context);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: controller,
      builder: (context, _, _) => IconButton(
        tooltip: controller.label,
        onPressed: controller.cycle,
        icon: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, anim) => RotationTransition(
            turns: Tween(begin: 0.75, end: 1.0).animate(anim),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Icon(controller.icon, key: ValueKey(controller.value)),
        ),
      ),
    );
  }
}
