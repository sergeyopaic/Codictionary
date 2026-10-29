import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/domain/exceptions/backup_exceptions.dart';
import 'package:codictionary/domain/exceptions/service_exceptions.dart';
import 'package:codictionary/domain/exceptions/storage_exceptions.dart';
import 'package:codictionary/presentation/app.dart';
import 'package:codictionary/presentation/l10n/app_strings.dart';
import 'package:codictionary/presentation/l10n/strings_ru.dart';

import '../fakes/json_storage_service.dart';
import '../helpers/test_dependencies.dart';

/// Latin words allowed in the Russian interface: product and service names,
/// the user's own data and key names.
const _allowedLatin = {
  'codictionary', 'cody', 'ai', 'api', 'deepl', 'openai', 'json', 'env',
  'wordids', 'en', 'ru', 'a', 'z', 'ctrl', 'n', 'f', 'esc',
  // user data in the fixture and the hint example
  'apple', 'layover', 'travel', 'serendipity',
};

Iterable<String> _latinWords(String text) =>
    RegExp(r'[A-Za-z]+').allMatches(text).map((m) => m.group(0)!.toLowerCase());

List<String> _englishLeftovers(String text) =>
    _latinWords(text).where((w) => !_allowedLatin.contains(w)).toList();

JsonStorageService _storage() => JsonStorageService(
  rawWords: [
    {
      'id': 'a',
      'eng': 'apple',
      'rus': 'яблоко',
      'desc': 'Фрукт.',
      'addedAt': '2025-01-01T00:00:00.000Z',
    },
    {
      'id': 'l',
      'eng': 'layover',
      'rus': 'пересадка',
      'addedAt': '2025-01-02T00:00:00.000Z',
    },
  ],
  rawVocabularies: [
    {
      'id': 'v',
      'name': 'Travel',
      'description': '',
      'icon': '',
      'wordIds': ['l'],
    },
  ],
);

Future<void> _pump(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    CodictionaryApp(useCases: testUseCases(storage: _storage())),
  );
  await tester.pumpAndSettle();
}

/// Every visible text and tooltip on screen.
List<String> _screenTexts(WidgetTester tester) => [
  for (final t in tester.widgetList<Text>(find.byType(Text)))
    t.data ?? t.textSpan?.toPlainText() ?? '',
  for (final t in tester.widgetList<Tooltip>(find.byType(Tooltip)))
    t.message ?? '',
  for (final f in tester.widgetList<TextField>(find.byType(TextField))) ...[
    f.decoration?.labelText ?? '',
    f.decoration?.hintText ?? '',
  ],
];

void _expectRussianOnly(WidgetTester tester, String screen) {
  final leftovers = {
    for (final text in _screenTexts(tester))
      for (final w in _englishLeftovers(text)) '"$w" in "$text"',
  };
  expect(leftovers, isEmpty, reason: 'English text on $screen');
}

void main() {
  group('Russian interface', () {
    for (final size in [const Size(400, 860), const Size(1400, 900)]) {
      testWidgets('has no stray English at ${size.width.toInt()} px', (
        tester,
      ) async {
        tester.platformDispatcher.localeTestValue = const Locale('ru');
        addTearDown(tester.platformDispatcher.clearLocaleTestValue);
        await _pump(tester, size);

        expect(find.text('Словарь').first, findsOneWidget);
        _expectRussianOnly(tester, 'dictionary');

        // Editor.
        await tester.tap(find.text('Добавить слово').first);
        await tester.pumpAndSettle();
        expect(find.text('Новое слово'), findsOneWidget);
        _expectRussianOnly(tester, 'editor');
        await tester.tap(find.text('Отмена'));
        await tester.pumpAndSettle();

        // Explanation sheet.
        await tester.tap(find.text('apple'));
        await tester.pumpAndSettle();
        expect(find.text('Cody объясняет'), findsOneWidget);
        _expectRussianOnly(tester, 'explanation');
        if (size.width >= 900) {
          await tester.tap(find.byTooltip('Закрыть'));
        } else {
          await tester.tapAt(const Offset(10, 10)); // outside the sheet
        }
        await tester.pumpAndSettle();

        // Collections and one collection.
        await tester.tap(find.text('Коллекции').last);
        await tester.pumpAndSettle();
        expect(find.text('1 слово'), findsOneWidget);
        _expectRussianOnly(tester, 'collections');
        await tester.tap(find.text('Travel'));
        await tester.pumpAndSettle();
        _expectRussianOnly(tester, 'collection');
        // Material's back button is Russian too.
        await tester.tap(find.byTooltip('Назад'));
        await tester.pumpAndSettle();

        // Backups.
        await tester.tap(find.text('Копии').last);
        await tester.pumpAndSettle();
        expect(find.text('Сохранить копию словаря'), findsOneWidget);
        _expectRussianOnly(tester, 'backups');
      });
    }

    test('every error message is Russian', () {
      const ru = RuStrings();
      final messages = <String>[
        for (final f in ServiceFailure.values) ...[
          ru.serviceError(ServiceException('OpenAI', f)),
          ru.failureMessage(ServiceException('DeepL', f)),
          ru.failureShortReason(ServiceException('OpenAI', f)),
        ],
        ru.storageError(const StorageUnavailableException('x')),
        ru.storageError(
          const StorageCorruptedException('x', hasBackup: true, location: ''),
        ),
        ru.storageError(
          const StorageCorruptedException('x', hasBackup: false, location: ''),
        ),
        ru.storageError(const StorageWriteException('x')),
        ru.storageError(const StorageWriteException('x', quotaExceeded: true)),
        for (final p in BackupProblem.values)
          ru.backupProblem(
            BackupFormatException(
              p,
              item: 'word',
              index: 2,
              field: 'target',
              value: '7',
            ),
          ),
      ];
      final leftovers = {
        for (final m in messages)
          for (final w in _englishLeftovers(m)) '"$w" in "$m"',
      }..removeWhere((e) => e.startsWith('"target"'));
      expect(leftovers, isEmpty);
    });

    test('plural forms follow Russian grammar', () {
      const ru = RuStrings();
      expect([1, 2, 4, 5, 11, 12, 14, 21, 22, 25, 101, 111].map(ru.wordCount), [
        '1 слово',
        '2 слова',
        '4 слова',
        '5 слов',
        '11 слов',
        '12 слов',
        '14 слов',
        '21 слово',
        '22 слова',
        '25 слов',
        '101 слово',
        '111 слов',
      ]);
      expect(ru.collectionCount(3), '3 коллекции');
    });

    test('other languages fall back to English', () {
      expect(AppStrings.forLocale(const Locale('de')).addWord, 'Add word');
      expect(
        AppStrings.forLocale(const Locale('ru')).addWord,
        'Добавить слово',
      );
    });
  });

  group('keyboard', () {
    testWidgets('Ctrl+N, Esc and Ctrl+F; focus comes back after a dialog', (
      tester,
    ) async {
      await _pump(tester, const Size(1400, 900));
      final searchField = find.descendant(
        of: find.byType(SearchBar),
        matching: find.byType(EditableText),
      );
      bool searchFocused() =>
          tester.widget<EditableText>(searchField).focusNode.hasFocus;

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(searchFocused(), isTrue);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(find.text('Add a word'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.text('Add a word'), findsNothing);
      expect(searchFocused(), isTrue, reason: 'focus returns where it was');
    });

    testWidgets('macOS uses ⌘ instead of Ctrl', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await _pump(tester, const Size(1400, 900));

        expect(find.textContaining('⌘F'), findsOneWidget); // search hint
        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyN);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pumpAndSettle();
        expect(find.text('Add a word'), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });

  group('accessibility guidelines', () {
    for (final size in [const Size(400, 860), const Size(1400, 900)]) {
      testWidgets('every tap target is labelled at ${size.width.toInt()} px', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await _pump(tester, size);

        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        // Screen readers announce what the search field is for.
        expect(find.bySemanticsLabel(RegExp('Search words')), findsWidgets);
        await tester.tap(find.text('Vocabularies').last);
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await tester.tap(find.text('Backup').last);
        await tester.pumpAndSettle();
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }
  });
}
