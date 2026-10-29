import 'package:codictionary/presentation/app_scope.dart';
import 'package:codictionary/domain/services/word_explainer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/data/repositories/word_repository_impl.dart';
import 'package:codictionary/domain/entities/word_entity.dart';
import 'package:codictionary/domain/exceptions/storage_exceptions.dart';
import 'package:codictionary/presentation/dictionary/dictionary_view_model.dart';
import 'package:codictionary/data/storage/safe_json_storage.dart';
import 'package:codictionary/data/storage/storage_service.dart';

import '../fakes/json_storage_service.dart';
import '../fakes/memory_backend.dart';
import '../helpers/test_dependencies.dart';

class _Gpt implements WordExplainer {
  _Gpt();
  @override
  Future<String> explainShort(String word) async => 'desc:$word';

  @override
  Future<String> explainLong(String word) async => 'long:$word';

  @override
  bool get isAvailable => false;
}

WordEntity _w(String id, String source, int day) => WordEntity(
  id: id,
  source: source,
  target: 'ru:$source',
  createdAt: DateTime.utc(2025, 1, day),
);

/// Manual order: pear, apple, mango. Newest is pear, oldest apple.
final _initial = [_w('p', 'pear', 3), _w('a', 'apple', 1), _w('m', 'mango', 2)];

void main() {
  late AppUseCases useCases;
  late StorageService storage;

  Future<DictionaryViewModel> launch() async {
    final vm = DictionaryViewModel(useCases);
    await vm.load();
    return vm;
  }

  Future<DictionaryViewModel> start({
    StorageService? withStorage,
    List<WordEntity>? words,
  }) async {
    storage = withStorage ?? JsonStorageService();
    useCases = testUseCases(storage: storage, explainer: _Gpt());
    await seedWords(storage, words ?? _initial);
    return launch();
  }

  List<String> shown(DictionaryViewModel vm) =>
      vm.filtered.map((w) => w.source).toList();
  List<String> manual(DictionaryViewModel vm) =>
      vm.words.map((w) => w.source).toList();

  test('dragging while searching is ignored and hides nothing', () async {
    final vm = await start();
    vm.onQueryChanged('ap');

    expect(vm.canReorder, isFalse);
    expect(vm.reorderBlockedReason, contains('search'));
    await vm.reorder(0, 0);

    vm.onQueryChanged('');
    expect(shown(vm), ['pear', 'apple', 'mango']);
    expect(manual(await launch()), ['pear', 'apple', 'mango']);
  });

  test('a manual order survives a restart', () async {
    final vm = await start();

    await vm.reorder(0, 2); // pear to the end

    expect(shown(vm), ['apple', 'mango', 'pear']);
    expect(shown(await launch()), ['apple', 'mango', 'pear']);
  });

  test('sorting changes only the view, never the manual order', () async {
    final vm = await start();

    vm.setSort(SortMode.alphaAsc);
    expect(shown(vm), ['apple', 'mango', 'pear']);
    expect(manual(vm), ['pear', 'apple', 'mango']);
    expect(manual(await launch()), ['pear', 'apple', 'mango']);

    vm.setSort(null);
    expect(shown(vm), ['pear', 'apple', 'mango']);
  });

  test('dragging is not available while sorted', () async {
    final vm = await start();
    vm.setSort(SortMode.alphaDesc);

    expect(vm.canReorder, isFalse);
    expect(vm.reorderBlockedReason, contains('sorting'));
    await vm.reorder(0, 2);
    expect(manual(vm), ['pear', 'apple', 'mango']);
  });

  test('a new word appears where the current sort puts it', () async {
    final vm = await start();
    vm.setSort(SortMode.alphaAsc);

    await vm.addWord(eng: 'banana', rus: 'банан');

    expect(shown(vm), ['apple', 'banana', 'mango', 'pear']);
    vm.setSort(null);
    expect(shown(vm), ['pear', 'apple', 'mango', 'banana']);
  });

  test('an edited word is re-sorted but keeps its manual place', () async {
    final vm = await start();
    vm.setSort(SortMode.alphaAsc);

    await vm.editWord('p', eng: 'avocado', rus: 'авокадо');

    expect(shown(vm), ['apple', 'avocado', 'mango']);
    expect(manual(vm), ['avocado', 'apple', 'mango']);
  });

  test(
    'Recent shows newest first; equal dates keep the manual order',
    () async {
      final same = DateTime.utc(2025, 1, 1);
      final vm = await start(
        words: [
          WordEntity(id: 'y', source: 'yak', target: 'як', createdAt: same),
          WordEntity(id: 'x', source: 'ox', target: 'бык', createdAt: same),
          _w('z', 'zebra', 9),
        ],
      );

      vm.setSort(SortMode.dateAdded);

      expect(shown(vm), ['zebra', 'yak', 'ox']);
    },
  );

  test('Undo puts a deleted word back in its place', () async {
    final vm = await start();
    final apple = vm.wordById('a')!;

    await vm.deleteById('a');
    await vm.restoreWord(apple);

    expect(manual(vm), ['pear', 'apple', 'mango']);
    expect(manual(await launch()), ['pear', 'apple', 'mango']);
  });

  test('Undo of a bulk delete restores the exact previous order', () async {
    final vm = await start();
    final removed = [vm.wordById('p')!, vm.wordById('m')!];
    vm
      ..toggleSelectionMode(true)
      ..toggleSelect('p')
      ..toggleSelect('m');

    await vm.deleteSelected();
    expect(manual(vm), ['apple']);
    await vm.restoreWords(removed);

    expect(manual(vm), ['pear', 'apple', 'mango']);
    expect(manual(await launch()), ['pear', 'apple', 'mango']);
  });

  test('a failed reorder is undone', () async {
    final backend = MemoryBackend();
    final vm = await start(
      withStorage: SafeJsonStorage(
        backend,
        wordsKey: 'dictionary.json',
        vocabsKey: 'vocabularies.json',
      ),
    );
    backend.failWrite = (_) => true;

    await expectLater(vm.reorder(0, 2), throwsA(isA<StorageWriteException>()));
    expect(manual(vm), ['pear', 'apple', 'mango']);
  });

  test('repository reorder keeps words missing from the list', () async {
    storage = JsonStorageService();
    final repo = WordRepositoryImpl(storage);
    for (final w in _initial) {
      await repo.create(w);
    }

    await repo.reorder(['m', 'unknown', 'p', 'm']);

    expect((await repo.getAll()).map((w) => w.id), ['m', 'p', 'a']);
  });
}
