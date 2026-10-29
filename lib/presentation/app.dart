import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'shell/app_shell.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

/// Root widget. Receives its dependencies; it never creates or registers
/// them, so rebuilding it is side-effect free.
class CodictionaryApp extends StatelessWidget {
  const CodictionaryApp({super.key, required this.useCases});

  final AppUseCases useCases;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      useCases: useCases,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeController.instance,
        builder: (context, mode, _) => MaterialApp(
          title: 'Codictionary',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const AppShell(),
        ),
      ),
    );
  }
}
