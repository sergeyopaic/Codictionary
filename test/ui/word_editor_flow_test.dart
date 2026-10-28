import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/domain/exceptions/service_exceptions.dart';
import 'package:codictionary/presentation/dictionary/dictionary_view_model.dart';
import 'package:codictionary/presentation/dictionary/widgets/word_editor_dialog.dart';
import 'package:codictionary/presentation/theme/app_theme.dart';
import 'package:codictionary/services/translate_service.dart';

import '../fakes/json_storage_service.dart';
import '../helpers/test_dependencies.dart';

const _debounce = Duration(milliseconds: 600);

void main() {
  late DictionaryViewModel vm;
  late ControlledTranslate translate;

  Future<void> openEditor(
    WidgetTester tester, {
    TranslateService? withTranslate,
  }) async {
    translate = ControlledTranslate();
    await registerTestDependencies(
      storage: JsonStorageService(),
      gpt: ControlledGpt(),
      translate: withTranslate ?? translate,
    );
    vm = DictionaryViewModel();
    await vm.load();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showWordEditorDialog(context, vm: vm),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder field(String label) => find.widgetWithText(TextField, label);
  String rus(WidgetTester tester) =>
      tester.widget<TextField>(field('Russian')).controller!.text;

  testWidgets('fast typing: only the latest translation is used', (
    tester,
  ) async {
    await openEditor(tester);

    await tester.enterText(field('English'), 'ca');
    await tester.pump(_debounce); // request #0 for "ca"
    await tester.enterText(field('English'), 'cat');
    await tester.pump(_debounce); // request #1 for "cat"

    translate.calls[1].completer.complete('кот');
    translate.calls[0].completer.complete('СА'); // late answer for "ca"
    await tester.pumpAndSettle();

    expect(rus(tester), 'кот');
  });

  testWidgets('a typed translation is never overwritten', (tester) async {
    await openEditor(tester);

    await tester.enterText(field('English'), 'cat');
    await tester.pump(_debounce);
    await tester.enterText(field('Russian'), 'кошечка');
    translate.calls.single.completer.complete('кот');
    await tester.pumpAndSettle();

    expect(rus(tester), 'кошечка');
  });

  testWidgets('switching auto-translate off cancels pending and running', (
    tester,
  ) async {
    await openEditor(tester);

    await tester.enterText(field('English'), 'cat');
    await tester.pump(_debounce); // running
    await tester.tap(find.byType(Switch));
    translate.calls.single.completer.complete('кот');
    await tester.pumpAndSettle();
    expect(rus(tester), isEmpty);

    await tester.tap(find.byType(Switch)); // on again: translates "cat"
    await tester.pump();
    await tester.tap(find.byType(Switch)); // off before the delay ends
    await tester.pump(_debounce);
    expect(translate.calls, hasLength(1), reason: 'pending request cancelled');
  });

  testWidgets('a failed translation is shown; the word can be saved anyway', (
    tester,
  ) async {
    await openEditor(tester);

    await tester.enterText(field('English'), 'cat');
    await tester.pump(_debounce);
    translate.calls[0].completer.completeError(
      const ServiceException('DeepL', ServiceFailure.network),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Not translated'), findsOneWidget);

    // Saving retries the translation once; when it fails again the dialog
    // stays open and offers to save without a translation.
    await tester.tap(find.text('Add word'));
    await tester.pump();
    translate.calls[1].completer.completeError(
      const ServiceException('DeepL', ServiceFailure.network),
    );
    await tester.pumpAndSettle();
    expect(find.text('Save without translation'), findsOneWidget);

    await tester.tap(find.text('Save without translation'));
    await tester.pumpAndSettle();

    expect(find.byType(WordEditorDialog), findsNothing);
    expect(vm.words.single.source, 'cat');
    expect(vm.words.single.target, isEmpty);
  });

  testWidgets('closing the dialog during a translation is safe', (
    tester,
  ) async {
    await openEditor(tester);

    await tester.enterText(field('English'), 'cat');
    await tester.pump(_debounce);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    translate.calls.single.completer.complete('кот');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(vm.words, isEmpty);
  });

  testWidgets('local mode: no auto-translate is offered', (tester) async {
    await openEditor(tester, withTranslate: FakeTranslate()); // no key

    expect(find.text('DeepL is not set up in this app'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
  });
}
