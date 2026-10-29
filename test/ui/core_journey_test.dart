// The main user journey end to end through the real UI, real use cases,
// repositories and SafeJsonStorage. Only the paid APIs are faked (instant
// answers), and the "disk" is in memory so a restart can be simulated.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/data/storage/safe_json_storage.dart';
import 'package:codictionary/domain/services/translator.dart';
import 'package:codictionary/domain/services/word_explainer.dart';
import 'package:codictionary/presentation/app.dart';
import 'package:codictionary/presentation/dictionary/widgets/word_card.dart';
import 'package:codictionary/presentation/dictionary/widgets/word_editor_dialog.dart';

import '../fakes/memory_backend.dart';
import '../helpers/test_dependencies.dart';

class _InstantTranslator implements Translator {
  static const _ru = {'apple': 'яблоко', 'zebra': 'зебра'};

  @override
  bool get isAvailable => true;

  @override
  Future<String> translateToRu(String eng) async => _ru[eng] ?? '?';
}

class _InstantExplainer implements WordExplainer {
  @override
  bool get isAvailable => true;

  @override
  Future<String> explainShort(String word) async => 'Коротко про $word';

  @override
  Future<String> explainLong(String word) async => 'Подробно про $word';
}

/// Starts the app over [backend], as a fresh launch would.
Future<void> _launch(WidgetTester tester, MemoryBackend backend) async {
  await tester.pumpWidget(const SizedBox()); // close any previous app
  await tester.pumpWidget(
    CodictionaryApp(
      useCases: testUseCases(
        storage: SafeJsonStorage(
          backend,
          wordsKey: 'dictionary.json',
          vocabsKey: 'vocabularies.json',
        ),
        explainer: _InstantExplainer(),
        translator: _InstantTranslator(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _inEditor(Finder f) =>
    find.descendant(of: find.byType(WordEditorDialog), matching: f);

Finder _field(String label) => _inEditor(find.widgetWithText(TextField, label));

Finder _card(String word) =>
    find.ancestor(of: find.text(word), matching: find.byType(WordCard));

Future<void> _addWord(WidgetTester tester, String eng, String expectRu) async {
  await tester.tap(find.text('Add word').first);
  await tester.pumpAndSettle();
  await tester.enterText(_field('English'), eng);
  await tester.pump(const Duration(milliseconds: 600)); // translate debounce
  await tester.pumpAndSettle();
  expect(
    tester.widget<TextField>(_field('Russian')).controller!.text,
    expectRu,
  );
  await tester.tap(_inEditor(find.text('Add word')));
  await tester.pumpAndSettle();
  await tester.pump(const Duration(seconds: 3)); // "added" popup closes
  await tester.pumpAndSettle();
}

Future<void> _cardMenu(WidgetTester tester, String word, String item) async {
  await tester.tap(
    find.descendant(of: _card(word), matching: find.byTooltip('More options')),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(MenuItemButton, item));
  await tester.pumpAndSettle();
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(SearchBar),
      matching: find.byType(EditableText),
    ),
    query,
  );
  await tester.pump(const Duration(milliseconds: 300)); // search debounce
  await tester.pumpAndSettle();
}

/// Whether card [a] comes before card [b] in reading order (the wide layout
/// is a grid: rows first, then columns).
bool _above(WidgetTester tester, String a, String b) {
  final pa = tester.getTopLeft(_card(a));
  final pb = tester.getTopLeft(_card(b));
  return pa.dy < pb.dy || (pa.dy == pb.dy && pa.dx < pb.dx);
}

void main() {
  testWidgets('add, search, sort, edit, delete with undo, and restart', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(tester.view.reset);
    final backend = MemoryBackend();

    // First launch: empty dictionary.
    await _launch(tester, backend);
    expect(find.text('Your dictionary is empty'), findsOneWidget);

    // Add two words: translated automatically, explained in the background.
    await _addWord(tester, 'zebra', 'зебра');
    await _addWord(tester, 'apple', 'яблоко');
    expect(find.byType(WordCard), findsNWidgets(2));
    expect(find.text('яблоко'), findsOneWidget);
    expect(find.text('Коротко про apple'), findsOneWidget);
    expect(find.text('Коротко про zebra'), findsOneWidget);

    // Search narrows the list; clearing it brings everything back.
    await _search(tester, 'zeb');
    expect(find.byType(WordCard), findsOneWidget);
    expect(find.text('apple'), findsNothing);
    await _search(tester, '');
    expect(find.byType(WordCard), findsNWidgets(2));

    // Sorting both ways.
    await tester.tap(find.text('Z–A'));
    await tester.pumpAndSettle();
    expect(_above(tester, 'zebra', 'apple'), isTrue);
    await tester.tap(find.text('A–Z'));
    await tester.pumpAndSettle();
    expect(_above(tester, 'apple', 'zebra'), isTrue);

    // Edit the translation.
    await _cardMenu(tester, 'apple', 'Edit word');
    await tester.enterText(_field('Russian'), 'яблочко');
    await tester.tap(_inEditor(find.text('Save changes')));
    await tester.pumpAndSettle();
    expect(find.text('Word updated.'), findsOneWidget);
    expect(find.text('яблочко'), findsOneWidget);
    expect(find.text('яблоко'), findsNothing);

    // Delete asks first, then offers Undo.
    await _cardMenu(tester, 'zebra', 'Delete');
    expect(find.text('Delete this word?'), findsOneWidget);
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('Delete')),
    );
    await tester.pumpAndSettle();
    expect(find.text('zebra'), findsNothing);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('zebra'), findsOneWidget);
    expect(find.text('Коротко про zebra'), findsOneWidget);

    // Restart: everything above was saved.
    await _launch(tester, backend);
    expect(find.byType(WordCard), findsNWidgets(2));
    expect(find.text('apple'), findsOneWidget);
    expect(find.text('яблочко'), findsOneWidget);
    expect(find.text('Коротко про apple'), findsOneWidget);
    expect(find.text('zebra'), findsOneWidget);
    expect(find.text('зебра'), findsOneWidget);
    expect(find.text('Коротко про zebra'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
