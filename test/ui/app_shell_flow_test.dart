import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/core/di/service_locator.dart';
import 'package:codictionary/main.dart';
import 'package:codictionary/domain/entities/word_entity.dart';
import 'package:codictionary/services/gpt_service.dart';
import 'package:codictionary/services/translate_service.dart';

import '../fakes/json_storage_service.dart';

Future<void> _pumpApp(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MyApp(
      gpt: GptService(''),
      translate: TranslateService(''),
      storage: JsonStorageService(),
      defaultWords: [
        WordEntity(
          id: '1',
          source: 'apple',
          target: 'яблоко',
          createdAt: DateTime.now(),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => sl.reset());

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
}
