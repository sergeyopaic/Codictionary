import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/presentation/app.dart';

import '../fakes/json_storage_service.dart';
import '../helpers/test_dependencies.dart';

/// Every main screen at phone to desktop widths, in a short window and with
/// text at 200%. Any overflow fails the test.
void main() {
  Map<String, dynamic> word(String id, String eng, String rus, [String? d]) => {
    'id': id,
    'eng': eng,
    'rus': rus,
    if (d != null) 'desc': d,
    'addedAt': '2025-01-01T00:00:00.000Z',
  };

  JsonStorageService storage() => JsonStorageService(
    rawWords: [
      word('1', 'serendipity', 'счастливая случайность', 'Удачное открытие.'),
      word(
        '2',
        'to take something with a grain of salt',
        'относиться скептически, не принимать на веру',
        'Не верить чему-то полностью; относиться с сомнением и проверять.',
      ),
      word('3', 'layover', 'пересадка'),
    ],
    rawVocabularies: [
      {
        'id': 'v',
        'name': 'Travel and everything about airports and long trips',
        'description': 'Airports, hotels, adventures and much more than that',
        'icon': 'assets/media/icons/new_dictionary/3.png',
        'wordIds': ['2', '3'],
      },
    ],
  );

  const sizes = [
    Size(320, 640),
    Size(400, 860),
    Size(900, 560), // wide but short
    Size(1400, 900),
  ];

  for (final scale in [1.0, 2.0]) {
    for (final size in sizes) {
      testWidgets('${size.width.toInt()}×${size.height.toInt()} at '
          '${(scale * 100).toInt()}% text', (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await tester.pumpWidget(
          CodictionaryApp(useCases: testUseCases(storage: storage())),
        );
        await tester.pumpAndSettle();
        expect(find.text('serendipity'), findsOneWidget);

        // Add-word dialog.
        await tester.tap(find.text('Add word').first);
        await tester.pumpAndSettle();
        expect(find.text('Add a word'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // Vocabularies and one vocabulary.
        await tester.tap(find.text('Vocabularies').last);
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Travel and everything'));
        await tester.pumpAndSettle();
        expect(find.textContaining('grain of salt'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();

        // Backup.
        await tester.tap(find.text('Backup').last);
        await tester.pumpAndSettle();
        expect(find.text('Back up your dictionary'), findsOneWidget);
      });
    }
  }
}
