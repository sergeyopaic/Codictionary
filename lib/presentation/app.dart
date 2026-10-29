import 'package:flutter/material.dart';

import '../domain/entities/app_settings.dart';
import 'app_scope.dart';
import 'l10n/app_strings.dart';
import 'l10n/material_ru.dart';
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

class _CodictionaryAppState extends State<CodictionaryApp>
    with WidgetsBindingObserver {
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

  /// The interface follows the system language (Russian or English).
  late AppStrings _strings = _systemStrings();

  static AppStrings _systemStrings() =>
      AppStrings.forLocale(WidgetsBinding.instance.platformDispatcher.locale);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    setState(() => _strings = _systemStrings());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      useCases: widget.useCases,
      child: StringsScope(
        strings: _strings,
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
              // Material's own texts (back button, text menu) follow the
              // interface language too.
              locale: _strings.locale,
              supportedLocales: const [Locale('en'), Locale('ru')],
              localizationsDelegates: const [
                RuMaterialLocalizations.delegate,
                DefaultMaterialLocalizations.delegate,
                DefaultWidgetsLocalizations.delegate,
                AnyLocaleCupertinoDelegate(),
              ],
              home: const AppShell(),
            ),
          ),
        ),
      ),
    );
  }
}
