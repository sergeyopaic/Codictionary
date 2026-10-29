import 'package:codictionary/presentation/app_scope.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/domain/entities/word_entity.dart';
import 'package:codictionary/domain/exceptions/storage_exceptions.dart';
import 'package:codictionary/presentation/dictionary/dictionary_view_model.dart';
import 'package:codictionary/presentation/dictionary/example_words.dart';
import 'package:codictionary/data/storage/safe_json_storage.dart';

import '../fakes/memory_backend.dart';
import '../helpers/test_dependencies.dart';

const _key = 'dictionary.json';

void main() {
  late AppUseCases useCases;
  late MemoryBackend backend;
  late SafeJsonStorage storage;
  late ControlledGpt gpt;

  setUp(() async {
    backend = MemoryBackend();
    storage = SafeJsonStorage(
      backend,
      wordsKey: _key,
      vocabsKey: 'vocabularies.json',
    );
    gpt = ControlledGpt();
    useCases = testUseCases(storage: storage, explainer: gpt);
  });

  /// A fresh view model over the same storage, i.e. an app (re)start.
  Future<DictionaryViewModel> launch() async {
    final vm = DictionaryViewModel(useCases);
    await vm.load();
    return vm;
  }

  test('first run shows an empty dictionary and writes nothing', () async {
    final vm = await launch();

    expect(vm.words, isEmpty);
    expect(vm.loadError, isNull);
    expect(backend.values, isEmpty);
  });

  test('an existing empty dictionary stays empty', () async {
    backend.values[_key] = '[]';

    expect((await launch()).words, isEmpty);
    expect(backend.values[_key], '[]');
  });

  test('after deleting the last word a restart stays empty', () async {
    await seedWords(storage, [
      WordEntity(
        id: '1',
        source: 'apple',
        target: 'яблоко',
        createdAt: DateTime.utc(2025),
      ),
    ]);
    final vm = await launch();
    await vm.deleteById('1');

    expect((await launch()).words, isEmpty);
  });

  test('a load error never adds example words', () async {
    backend.values[_key] = 'garbage';

    final vm = await launch();

    expect(vm.loadError, isA<StorageCorruptedException>());
    expect(vm.words, isEmpty);
    expect(backend.values[_key], 'garbage');
  });

  test('example words are added only on request, without AI', () async {
    final vm = await launch();

    expect(await vm.addExampleWords(), exampleWords.length);

    expect(gpt.calls, isEmpty, reason: 'examples ship with explanations');
    final reloaded = (await launch()).words;
    expect(reloaded.map((w) => w.source), exampleWords.map((e) => e.source));
    expect(reloaded.every((w) => w.hasShortExplanation), isTrue);
  });

  test('example words never duplicate existing ones', () async {
    final vm = await launch();
    await vm.addExampleWords();

    expect(await vm.addExampleWords(), 0);
    expect((await launch()).words, hasLength(exampleWords.length));
  });

  test('an example the user already has is skipped', () async {
    await seedWords(storage, [
      WordEntity(
        id: 'mine',
        source: 'Resilient',
        target: 'жизнестойкий',
        createdAt: DateTime.utc(2025),
      ),
    ]);
    final vm = await launch();

    expect(await vm.addExampleWords(), exampleWords.length - 1);
    expect(vm.wordById('mine')!.target, 'жизнестойкий');
  });
}
