// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/main.dart';
import 'package:codictionary/models/word.dart';
import 'package:codictionary/services/storage/storage_interface.dart';
import 'package:codictionary/services/gpt_service.dart';
import 'package:codictionary/services/translate_service.dart';

class _MemoryStorageService implements StorageService {
  List<Word> _words = [];
  @override
  Future<List<Word>> loadWords() async => _words;
  @override
  Future<void> saveWords(List<Word> words) async {
    _words = List.of(words);
  }
}

void main() {
  testWidgets('App builds and shows Add Word button', (
    WidgetTester tester,
  ) async {
    final storage = _MemoryStorageService();
    final defaults = const [Word(id: '1', eng: 'apple', rus: 'яблоко')];

    await tester.pumpWidget(
      MyApp(
        gpt: GptService(''),
        translate: TranslateService(''),
        storage: storage,
        defaultWords: defaults,
      ),
    );

    // Expect the Add Word FAB to be present
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Add Word'), findsOneWidget);
  });
}
