import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/presentation/app.dart';

import '../fakes/json_storage_service.dart';
import '../helpers/test_dependencies.dart';

void main() {
  testWidgets('create a vocabulary, add a word, manage it from the word', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    final storage = JsonStorageService(
      rawWords: [
        {
          'id': 'a',
          'eng': 'apple',
          'rus': 'яблоко',
          'addedAt': '2025-01-01T00:00:00.000Z',
        },
      ],
    );
    await tester.pumpWidget(
      CodictionaryApp(useCases: testUseCases(storage: storage)),
    );
    await tester.pumpAndSettle();

    // Create "Travel".
    await tester.tap(find.text('Vocabularies').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create a vocabulary'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Travel',
    );
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    expect(find.text('0 words'), findsOneWidget);

    // Open it and add "apple" from the dictionary.
    await tester.tap(find.text('Travel'));
    await tester.pumpAndSettle();
    expect(find.text('No words here yet'), findsOneWidget);
    await tester.tap(find.text('Add words'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'apple'));
    await tester.pump();
    await tester.tap(find.text('Add word'));
    await tester.pumpAndSettle();
    expect(find.text('apple'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('1 word'), findsOneWidget);

    // From the dictionary: take the word out of "Travel" again.
    await tester.tap(find.text('Dictionary'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vocabularies…'));
    await tester.pumpAndSettle();
    final travel = find.widgetWithText(CheckboxListTile, 'Travel');
    expect(tester.widget<CheckboxListTile>(travel).value, isTrue);
    await tester.tap(travel);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Vocabularies').first);
    await tester.pumpAndSettle();
    expect(find.text('0 words'), findsOneWidget, reason: 'reloaded on show');
    expect(storage.rawVocabularies.single['wordIds'], isEmpty);
  });
}
