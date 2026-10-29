import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/data/models/vocabulary_record.dart';
import 'package:codictionary/data/models/word_record.dart';
import 'package:codictionary/data/repositories/vocabulary_repository_impl.dart';
import 'package:codictionary/data/storage/safe_json_storage.dart';
import 'package:codictionary/data/storage/storage_service.dart';
import 'package:codictionary/domain/entities/vocabulary.dart';
import 'package:codictionary/domain/entities/word_entity.dart';
import 'package:codictionary/domain/exceptions/storage_exceptions.dart';
import 'package:codictionary/presentation/app_scope.dart';
import 'package:codictionary/presentation/dictionary/dictionary_view_model.dart';
import 'package:codictionary/presentation/vocabs/vocabs_view_model.dart';

import '../fakes/json_storage_service.dart';
import '../fakes/memory_backend.dart';
import '../helpers/test_dependencies.dart';

WordEntity _w(String id, String source) => WordEntity(
  id: id,
  source: source,
  target: 'ru:$source',
  createdAt: DateTime.utc(2025),
);

/// Storage whose writes take a little time, so concurrent membership
/// changes really overlap.
class _SlowStorage extends JsonStorageService {
  @override
  Future<List<VocabularyRecord>> loadVocabularies() async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return super.loadVocabularies();
  }

  @override
  Future<void> saveVocabularies(List<VocabularyRecord> vocabs) async {
    await Future<void>.delayed(const Duration(milliseconds: 5));
    return super.saveVocabularies(vocabs);
  }
}

void main() {
  late StorageService storage;
  late AppUseCases useCases;

  /// A fresh view model over the same storage, i.e. an app restart.
  Future<VocabsViewModel> restart() async {
    final vm = VocabsViewModel(testUseCases(storage: storage));
    await vm.load();
    return vm;
  }

  Future<VocabsViewModel> start({StorageService? withStorage}) async {
    storage = withStorage ?? JsonStorageService();
    useCases = testUseCases(storage: storage);
    await seedWords(storage, [_w('a', 'apple'), _w('p', 'pear')]);
    return restart();
  }

  List<String> wordsIn(VocabsViewModel vm, String vocabularyId) =>
      vm.wordsOf(vm.byId(vocabularyId)!).map((w) => w.source).toList();

  Future<Vocabulary> create(VocabsViewModel vm, String name) =>
      vm.create(name: name, description: '', iconPath: 'icon.png');

  test('create → add a word → open → restart keeps everything', () async {
    final vm = await start();
    final travel = await create(vm, 'Travel');

    await vm.setMembership(travel.id, 'a', member: true);
    expect(wordsIn(vm, travel.id), ['apple']);

    final after = await restart();
    expect(after.byId(travel.id)!.name, 'Travel');
    expect(wordsIn(after, travel.id), ['apple']);
  });

  test('one word can be in two collections', () async {
    final vm = await start();
    final travel = await create(vm, 'Travel');
    final food = await create(vm, 'Food');

    await vm.setMembership(travel.id, 'a', member: true);
    await vm.setMembership(food.id, 'a', member: true);
    await vm.setMembership(food.id, 'p', member: true);

    final after = await restart();
    expect(wordsIn(after, travel.id), ['apple']);
    expect(wordsIn(after, food.id), ['apple', 'pear']);
  });

  test('deleting a collection keeps its words; Undo restores links', () async {
    final vm = await start();
    await create(vm, 'First');
    final food = await create(vm, 'Food');
    await vm.addWords(food.id, ['a', 'p']);

    final deleted = await vm.delete(food.id);
    expect(vm.byId(food.id), isNull);
    expect((await restart()).words.map((w) => w.source), ['apple', 'pear']);

    await vm.restore(deleted!.vocabulary, deleted.index);

    final after = await restart();
    expect(after.vocabularies.map((v) => v.name), ['First', 'Food']);
    expect(wordsIn(after, food.id), ['apple', 'pear']);
  });

  test('a deleted word leaves collections and comes back with Undo', () async {
    final vm = await start();
    final food = await create(vm, 'Food');
    await vm.addWords(food.id, ['a', 'p']);

    final dictionary = DictionaryViewModel(useCases);
    await dictionary.load();
    final apple = dictionary.wordById('a')!;
    await dictionary.deleteById('a');
    expect(wordsIn(await restart(), food.id), ['pear']);

    await dictionary.restoreWord(apple);
    expect(wordsIn(await restart(), food.id), ['apple', 'pear']);
  });

  test('collections with the same name never mix their words', () async {
    final vm = await start();
    final first = await create(vm, 'Travel');
    final second = await create(vm, 'Travel');

    await vm.setMembership(first.id, 'a', member: true);
    await vm.updateDetails(second.copyWith(name: 'Travel 2'));

    final after = await restart();
    expect(first.id, isNot(second.id));
    expect(wordsIn(after, first.id), ['apple']);
    expect(wordsIn(after, second.id), isEmpty);
    expect(after.byId(first.id)!.name, 'Travel');
  });

  test('editing details never drops members added meanwhile', () async {
    final vm = await start();
    final travel = await create(vm, 'Travel');
    final stale = vm.byId(travel.id)!; // has no members yet

    await vm.setMembership(travel.id, 'a', member: true);
    await vm.updateDetails(stale.copyWith(name: 'Trips'));

    final after = await restart();
    expect(after.byId(travel.id)!.name, 'Trips');
    expect(wordsIn(after, travel.id), ['apple']);
  });

  test('overlapping membership changes are all kept', () async {
    final vm = await start(withStorage: _SlowStorage());
    final travel = await create(vm, 'Travel');
    final repo = VocabularyRepositoryImpl(storage);

    await Future.wait([
      repo.setMembership(travel.id, 'a', true),
      repo.setMembership(travel.id, 'p', true),
    ]);

    expect(wordsIn(await restart(), travel.id), ['apple', 'pear']);
  });

  test(
    'collections from older versions get stable ids and keep details',
    () async {
      final legacy = JsonStorageService(
        rawVocabularies: [
          {'name': 'Travel', 'description': 'Trips', 'icon': 'icon3.png'},
          {'name': 'Travel', 'description': '', 'icon': ''},
        ],
      );
      storage = legacy;

      final first = await restart();
      final second = await restart();

      final ids = first.vocabularies.map((v) => v.id).toList();
      expect(ids.toSet(), hasLength(2));
      expect(ids.every((id) => id.isNotEmpty), isTrue);
      expect(second.vocabularies.map((v) => v.id), ids, reason: 'stable');
      expect(first.vocabularies[0].description, 'Trips');
      expect(first.vocabularies[0].iconPath, 'icon3.png');
      expect(
        first.vocabularies[1].iconPath,
        VocabularyRepositoryImpl.defaultIcon,
      );
      expect(first.vocabularies.every((v) => v.wordIds.isEmpty), isTrue);
    },
  );

  test('a failed membership change is rolled back', () async {
    final backend = MemoryBackend();
    final vm = await start(
      withStorage: SafeJsonStorage(
        backend,
        wordsKey: 'dictionary.json',
        vocabsKey: 'vocabularies.json',
      ),
    );
    final travel = await create(vm, 'Travel');
    backend.failWrite = (key) => key == 'vocabularies.json';

    await expectLater(
      vm.setMembership(travel.id, 'a', member: true),
      throwsA(isA<StorageWriteException>()),
    );
    expect(vm.byId(travel.id)!.wordIds, isEmpty);
  });

  test('a damaged member list is reported, not silently dropped', () async {
    final backend = MemoryBackend({
      'vocabularies.json': jsonEncode([
        {'id': 'v', 'name': 'Travel', 'wordIds': 'apple'},
      ]),
      'dictionary.json': jsonEncode([
        WordRecord(
          id: 'a',
          eng: 'apple',
          rus: 'яблоко',
          addedAt: DateTime.utc(2025),
        ).toMap(),
      ]),
    });
    storage = SafeJsonStorage(
      backend,
      wordsKey: 'dictionary.json',
      vocabsKey: 'vocabularies.json',
    );

    final vm = await restart();

    expect(vm.loadError, isA<StorageCorruptedException>());
  });
}
