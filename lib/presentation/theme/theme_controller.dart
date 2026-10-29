import 'package:flutter/material.dart';

import '../../domain/entities/app_settings.dart';

/// The user's light/dark preference. Created by the app with the saved
/// value; changes are reported through [onChanged] so they can be saved.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController([super.value = ThemeMode.system]);

  /// Cycles system → light → dark → system.
  void cycle() {
    value = switch (value) {
      ThemeMode.system => ThemeMode.light,
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
    };
  }

  IconData get icon => switch (value) {
    ThemeMode.system => Icons.brightness_auto_rounded,
    ThemeMode.light => Icons.light_mode_rounded,
    ThemeMode.dark => Icons.dark_mode_rounded,
  };

  static ThemeMode fromPreference(ThemePreference p) => switch (p) {
    ThemePreference.system => ThemeMode.system,
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
  };

  static ThemePreference toPreference(ThemeMode m) => switch (m) {
    ThemeMode.system => ThemePreference.system,
    ThemeMode.light => ThemePreference.light,
    ThemeMode.dark => ThemePreference.dark,
  };
}

/// Provides the app's [ThemeController] to the widget tree.
class ThemeScope extends InheritedNotifier<ThemeController> {
  const ThemeScope({
    super.key,
    required ThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'No ThemeScope above this widget');
    return scope!.notifier!;
  }
}
