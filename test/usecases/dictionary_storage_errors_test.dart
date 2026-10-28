import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/domain/exceptions/storage_exceptions.dart';
import 'package:codictionary/models/word.dart';
import 'package:codictionary/presentation/dictionary/dictionary_view_model.dart';
import 'package:codictionary/services/gpt_service.dart';
import 'package:codictionary/services/storage/safe_json_storage.dart';

import '../fakes/memory_backend.dart';
import '../helpers/test_dependencies.dart';

const _key = 'dictionary.json';

class _Gpt extends GptService {
  _Gpt() : super('');
  @override
  Future<String> explainWordShort(String word) async => 'desc:$word';
  @override
  Future<String> explainWordLong(String word) async => 'long:$word';
}

String _stored(List<String> words) => jsonEncode([
  for (var i = 0; i < words.length; i++)
    Word(
      id: '${i + 1}',
      eng: words[i],
      rus: 'ru:${words[i]}',
      addedAt: DateTime.utc(2025),
    ).toMap(),
]);

void main() {
  late MemoryBackend backend;

  Future<DictionaryViewModel> start(Map<String, String> values) async {
    backend = MemoryBackend(values);
    await registerTestDependencies(
      storage: SafeJsonStorage(
        backend,
        wordsKey: _key,
        vocabsKey: 'vocabularies.json',
      ),
      gpt: _Gpt(),
    );
    final vm = DictionaryViewModel();
    await vm.load();
    return vm;
  }

  test('damaged storage is reported and nothing is written', () async {
    final vm = await start({_key: 'garbage'});

    expect(vm.loadError, isA<StorageCorruptedException>());
    expect(vm.words, isEmpty);
    expect(backend.values[_key], 'garbage');
  });

  test('adding while storage is damaged fails and changes nothing', () async {
    final vm = await start({_key: 'garbage'});

    await expectLater(
      vm.addWord(eng: 'cat', rus: 'кошка'),
      throwsA(isA<StorageCorruptedException>()),
    );
    expect(vm.words, isEmpty);
    expect(backend.values[_key], 'garbage');
  });

  test('recovering from the backup brings the words back', () async {
    final vm = await start({
      _key: 'garbage',
      '$_key.bak': _stored(['apple', 'pear']),
    });

    await vm.recover(StorageRecovery.restoreBackup);

    expect(vm.loadError, isNull);
    expect(vm.words.map((w) => w.source), ['apple', 'pear']);
  });

  test('a failed edit is rolled back, not shown as saved', () async {
    final vm = await start({
      _key: _stored(['apple']),
    });
    backend.failWrite = (_) => true;

    await expectLater(
      vm.editWord('1', eng: 'apple', rus: 'яблоко'),
      throwsA(isA<StorageWriteException>()),
    );

    expect(vm.wordById('1')!.target, 'ru:apple');
    expect(backend.values[_key], _stored(['apple']));
  });

  test('a failed add is not shown in the list', () async {
    final vm = await start({
      _key: _stored(['apple']),
    });
    backend.failWrite = (_) => true;

    await expectLater(
      vm.addWord(eng: 'pear', rus: 'груша'),
      throwsA(isA<StorageWriteException>()),
    );
    expect(vm.words.map((w) => w.source), ['apple']);
    // The word was not reserved forever: it can be added once saving works.
    backend.failWrite = (_) => false;
    expect(await vm.addWord(eng: 'pear', rus: 'груша'), isTrue);
  });

  test('a failed delete puts the word back', () async {
    final vm = await start({
      _key: _stored(['apple', 'pear']),
    });
    backend.failWrite = (_) => true;

    await expectLater(
      vm.deleteById('1'),
      throwsA(isA<StorageWriteException>()),
    );
    expect(vm.words.map((w) => w.source), ['apple', 'pear']);
  });

  test('a failed undo does not leave a ghost word', () async {
    final vm = await start({
      _key: _stored(['apple']),
    });
    final apple = vm.wordById('1')!;
    await vm.deleteById('1');
    backend.failWrite = (_) => true;

    await expectLater(
      vm.restoreWord(apple),
      throwsA(isA<StorageWriteException>()),
    );
    expect(vm.words, isEmpty);
  });
}
