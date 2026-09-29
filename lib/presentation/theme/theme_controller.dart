import 'package:flutter/material.dart';

/// Holds the user's light/dark preference for the running session.
class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController([super.value = ThemeMode.system]);

  static final ThemeController instance = ThemeController();

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

  String get label => switch (value) {
    ThemeMode.system => 'System theme',
    ThemeMode.light => 'Light theme',
    ThemeMode.dark => 'Dark theme',
  };
}
