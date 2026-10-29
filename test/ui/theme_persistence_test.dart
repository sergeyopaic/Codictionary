import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/data/storage/safe_json_storage.dart';
import 'package:codictionary/domain/entities/app_settings.dart';
import 'package:codictionary/presentation/app.dart';

import '../fakes/json_storage_service.dart';
import '../fakes/memory_backend.dart';
import '../helpers/test_dependencies.dart';

void main() {
  ThemeMode themeOf(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

  testWidgets('the chosen theme is restored on the next launch', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    final storage = JsonStorageService();

    // First launch: defaults to the system theme; pick dark in the sidebar.
    var useCases = testUseCases(storage: storage);
    await tester.pumpWidget(
      CodictionaryApp(
        useCases: useCases,
        initialSettings: await useCases.loadSettings(),
      ),
    );
    await tester.pumpAndSettle();
    expect(themeOf(tester), ThemeMode.system);
    await tester.tap(find.byTooltip('Dark'));
    await tester.pumpAndSettle();
    expect(themeOf(tester), ThemeMode.dark);
    expect(storage.settings['theme'], 'dark');

    // Next launch, the way main() starts the app.
    await tester.pumpWidget(const SizedBox());
    useCases = testUseCases(storage: storage);
    final settings = await useCases.loadSettings();
    await tester.pumpWidget(
      CodictionaryApp(useCases: useCases, initialSettings: settings),
    );
    await tester.pumpAndSettle();
    expect(settings.theme, ThemePreference.dark);
    expect(themeOf(tester), ThemeMode.dark);
  });

  test(
    'unreadable settings fall back to defaults instead of failing',
    () async {
      final storage = SafeJsonStorage(
        MemoryBackend({'settings.json': 'garbage'}),
        wordsKey: 'dictionary.json',
        vocabsKey: 'vocabularies.json',
      );
      final useCases = testUseCases(storage: storage);

      expect((await useCases.loadSettings()).theme, ThemePreference.system);

      // And they can be saved again over the damaged file.
      await useCases.saveSettings(
        const AppSettings(theme: ThemePreference.light),
      );
      expect((await useCases.loadSettings()).theme, ThemePreference.light);
    },
  );
}
