import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/presentation/app.dart';

import 'package:codictionary/data/storage/safe_json_storage.dart';
import 'package:codictionary/data/storage/storage_service.dart';

import '../fakes/json_storage_service.dart';
import '../helpers/test_dependencies.dart';
import '../fakes/memory_backend.dart';

final _apple = <Map<String, dynamic>>[
  {
    'id': '1',
    'eng': 'apple',
    'rus': 'яблоко',
    'addedAt': '2025-01-01T00:00:00.000Z',
  },
];

Future<void> _pumpApp(
  WidgetTester tester,
  Size size, {
  StorageService? storage,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    CodictionaryApp(
      useCases: testUseCases(
        storage: storage ?? JsonStorageService(rawWords: _apple),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('wide layout shows sidebar, seeded word and add dialog', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(1400, 900));

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Vocabularies'), findsOneWidget);
    expect(find.text('apple'), findsOneWidget);
    expect(find.text('яблоко'), findsOneWidget);

    await tester.tap(find.text('Add word'));
    await tester.pumpAndSettle();
    expect(find.text('Add a word'), findsOneWidget);
    expect(find.text('Auto-translate'), findsOneWidget);
  });

  testWidgets('narrow layout uses bottom navigation', (tester) async {
    await _pumpApp(tester, const Size(400, 860));

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('apple'), findsOneWidget);

    await tester.tap(find.text('Vocabularies'));
    await tester.pumpAndSettle();
    expect(find.text('No vocabularies yet'), findsOneWidget);
  });

  testWidgets('damaged dictionary offers recovery instead of demo words', (
    tester,
  ) async {
    final good =
        '[{"id":"9","eng":"pear","rus":"груша",'
        '"addedAt":"2025-01-01T00:00:00.000Z"}]';
    final backend = MemoryBackend({
      'dictionary.json': 'garbage',
      'dictionary.json.bak': good,
    });
    await _pumpApp(
      tester,
      const Size(1400, 900),
      storage: SafeJsonStorage(
        backend,
        wordsKey: 'dictionary.json',
        vocabsKey: 'vocabularies.json',
      ),
    );

    expect(find.text('Your dictionary file is damaged'), findsOneWidget);
    expect(find.text('apple'), findsNothing, reason: 'no demo words');
    // The add button is hidden and disabled while storage is damaged.
    final add = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Add word'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(add.onPressed, isNull);

    await tester.tap(find.text('Restore last good copy'));
    await tester.pumpAndSettle();

    expect(find.text('pear'), findsOneWidget);
    expect(find.text('Your dictionary file is damaged'), findsNothing);
  });

  testWidgets('empty dictionary offers example words on request', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      const Size(1400, 900),
      storage: JsonStorageService(),
    );

    expect(find.text('Your dictionary is empty'), findsOneWidget);
    expect(find.text('apple'), findsNothing, reason: 'no automatic demo words');

    await tester.tap(find.text('Add example words'));
    await tester.pumpAndSettle();

    expect(find.text('serendipity'), findsOneWidget);
    expect(find.text('Your dictionary is empty'), findsNothing);
  });

  testWidgets('long-press while searching explains why dragging is off', (
    tester,
  ) async {
    await _pumpApp(tester, const Size(1400, 900));

    await tester.enterText(
      find.descendant(
        of: find.byType(SearchBar),
        matching: find.byType(EditableText),
      ),
      'app',
    );
    await tester.pump(const Duration(milliseconds: 300)); // search debounce
    await tester.pumpAndSettle();

    await tester.longPress(find.text('apple'));
    await tester.pumpAndSettle();

    expect(find.text('Clear the search to reorder words.'), findsOneWidget);
  });

  testWidgets('apps built from separate dependencies share no state', (
    tester,
  ) async {
    // With a global service locator the second app silently reused the
    // first app's storage.
    await _pumpApp(tester, const Size(1400, 900));
    expect(find.text('apple'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await _pumpApp(
      tester,
      const Size(1400, 900),
      storage: JsonStorageService(),
    );
    expect(find.text('apple'), findsNothing);
    expect(find.text('Your dictionary is empty'), findsOneWidget);
  });

  testWidgets('rebuilding the app keeps the same dependencies', (tester) async {
    final useCases = testUseCases(
      storage: JsonStorageService(rawWords: _apple),
    );
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(CodictionaryApp(useCases: useCases));
    await tester.pumpAndSettle();
    await tester.pumpWidget(CodictionaryApp(useCases: useCases));
    await tester.pumpAndSettle();

    expect(find.text('apple'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
