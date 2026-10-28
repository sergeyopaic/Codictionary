// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/main.dart';
import 'package:codictionary/services/gpt_service.dart';
import 'package:codictionary/services/translate_service.dart';

import 'fakes/json_storage_service.dart';

void main() {
  testWidgets('App builds and shows Add Word button', (
    WidgetTester tester,
  ) async {
    // Expand the test surface to avoid AppBar title overflow exceptions
    final previousSize = tester.view.physicalSize;
    final previousDpr = tester.view.devicePixelRatio;
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const ui.Size(1600, 1200);
    addTearDown(() {
      tester.view.devicePixelRatio = previousDpr;
      tester.view.physicalSize = previousSize;
    });
    final storage = JsonStorageService();

    await tester.pumpWidget(
      MyApp(
        gpt: GptService(''),
        translate: TranslateService(''),
        storage: storage,
      ),
    );

    // Expect the Add Word FAB to be present
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Add word'), findsOneWidget);
  });
}
