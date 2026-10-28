import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'services/gpt_service.dart';
import 'services/storage_service.dart';
import 'services/translate_service.dart';
import 'core/di/initial_bindings.dart';
import 'core/di/service_locator.dart';
import 'presentation/shell/app_shell.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/theme/theme_controller.dart';

late String? apiKey;
late String? deeplApiKey;

late final GptService gpt;
late final TranslateService translate;
late final StorageService storage;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    apiKey = dotenv.env['OPENAI_API_KEY'];
    deeplApiKey = dotenv.env['DEEPL_API_KEY'];
  } catch (_) {
    // No or unreadable .env: run in local mode without AI and translation.
    apiKey = null;
    deeplApiKey = null;
  }
  storage = createStorageService();
  gpt = GptService(apiKey ?? '');
  translate = TranslateService(deeplApiKey ?? '');
  await registerInitialDependencies();
  // Register app services for presentation layer via DI
  sl
    ..registerLazySingleton<GptService>(() => gpt)
    ..registerLazySingleton<TranslateService>(() => translate);

  runApp(MyApp(gpt: gpt, translate: translate, storage: storage));
}

/// Root widget that wires services and hosts the adaptive [AppShell].
class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.gpt,
    required this.translate,
    required this.storage,
  });

  final GptService gpt;
  final TranslateService translate;
  final StorageService storage;

  @override
  Widget build(BuildContext context) {
    // Ensure DI also works when main() wasn't run (e.g., widget tests)
    if (!sl.isRegistered<StorageService>()) {
      sl.registerLazySingleton<StorageService>(() => storage);
    }
    registerInitialDependenciesSync();
    if (!sl.isRegistered<GptService>()) {
      sl.registerLazySingleton<GptService>(() => gpt);
    }
    if (!sl.isRegistered<TranslateService>()) {
      sl.registerLazySingleton<TranslateService>(() => translate);
    }
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.instance,
      builder: (context, mode, _) => MaterialApp(
        title: 'Codictionary',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        home: const AppShell(),
      ),
    );
  }
}
