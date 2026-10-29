import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/presentation/app.dart';

import '../fakes/json_storage_service.dart';
import '../helpers/test_dependencies.dart';

Map<String, dynamic> _word(String id, String eng, String rus) => {
  'id': id,
  'eng': eng,
  'rus': rus,
  'addedAt': '2025-01-01T00:00:00.000Z',
};

void main() {
  testWidgets('copy a backup, reject garbage, restore another dictionary', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 1000);
    addTearDown(tester.view.reset);

    String? clipboard;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboard = (call.arguments as Map)['text'] as String?;
            return null;
          case 'Clipboard.getData':
            return {'text': clipboard};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    // A backup of another dictionary with "pear", made with the real codec.
    final other = testUseCases(
      storage: JsonStorageService(rawWords: [_word('p', 'pear', 'груша')]),
    );
    final pearBackup = await other.exportDictionary();

    final storage = JsonStorageService(
      rawWords: [_word('a', 'apple', 'яблоко')],
    );
    final files = MemoryBackupFiles();
    await tester.pumpWidget(
      CodictionaryApp(
        useCases: testUseCases(storage: storage, backupFiles: files),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('apple'), findsOneWidget);

    await tester.tap(find.text('Backup').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('1 word and 0 vocabularies'), findsOneWidget);

    // Export to the clipboard.
    await tester.tap(find.text('Copy to clipboard'));
    await tester.pumpAndSettle();
    expect(clipboard, contains('"source": "apple"'));

    // Garbage is rejected and nothing changes.
    clipboard = 'not a backup';
    await tester.tap(find.text('Paste from clipboard'));
    await tester.pumpAndSettle();
    expect(find.textContaining('not valid JSON'), findsOneWidget);
    expect(find.textContaining('Nothing was changed'), findsOneWidget);
    expect(storage.rawWords.single['eng'], 'apple');

    // A real backup replaces the dictionary after confirmation.
    clipboard = pearBackup;
    await tester.tap(find.text('Paste from clipboard'));
    await tester.pumpAndSettle();
    expect(find.text('Replace your dictionary?'), findsOneWidget);
    await tester.tap(find.text('Replace'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Restored 1 word'), findsOneWidget);
    expect(files.saved.keys.single, startsWith('codictionary-before-restore'));
    expect(storage.rawWords.single['eng'], 'pear');

    await tester.tap(find.text('Dictionary'));
    await tester.pumpAndSettle();
    expect(find.text('pear'), findsOneWidget);
    expect(find.text('apple'), findsNothing);
  });
}
