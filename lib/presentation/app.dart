import 'package:flutter/material.dart';

import '../domain/entities/app_settings.dart';
import 'app_scope.dart';
import 'shell/app_shell.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

/// Root widget. Receives its dependencies and the saved settings; it never
/// creates or registers services, so rebuilding it is side-effect free.
class CodictionaryApp extends StatefulWidget {
  const CodictionaryApp({
    super.key,
    required this.useCases,
    this.initialSettings = const AppSettings(),
  });

  final AppUseCases useCases;
  final AppSettings initialSettings;

  @override
  State<CodictionaryApp> createState() => _CodictionaryAppState();
}

class _CodictionaryAppState extends State<CodictionaryApp> {
  late final ThemeController _theme = ThemeController(
    ThemeController.fromPreference(widget.initialSettings.theme),
  )..addListener(_saveTheme);

  late AppSettings _settings = widget.initialSettings;

  Future<void> _saveTheme() async {
    _settings = _settings.copyWith(
      theme: ThemeController.toPreference(_theme.value),
    );
    try {
      await widget.useCases.saveSettings(_settings);
    } catch (_) {
      // A preference that fails to save only affects the next launch; the
      // theme still applies now.
    }
  }

  @override
  void dispose() {
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      useCases: widget.useCases,
      child: ThemeScope(
        controller: _theme,
        child: ValueListenableBuilder<ThemeMode>(
          valueListenable: _theme,
          builder: (context, mode, _) => MaterialApp(
            title: 'Codictionary',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: mode,
            home: const AppShell(),
          ),
        ),
      ),
    );
  }
}
