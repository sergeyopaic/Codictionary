import 'package:flutter_test/flutter_test.dart';
import 'package:codictionary/core/di/service_locator.dart';
import 'package:codictionary/domain/repositories/word_repository.dart';
import 'package:codictionary/domain/entities/word_entity.dart';
import 'package:codictionary/domain/usecases/add_word.dart';
import 'package:codictionary/domain/usecases/get_all_words.dart';
import 'package:codictionary/domain/usecases/remove_word.dart';
import 'package:codictionary/presentation/dictionary/dictionary_view_model.dart';
import 'package:codictionary/models/word.dart' as legacy_model;
import 'package:codictionary/services/gpt_service.dart';
import 'package:codictionary/services/translate_service.dart';

class _FakeRepo implements WordRepository {
  final List<WordEntity> store = [];
  @override
  Future<void> add(WordEntity word) async {
    final idx = store.indexWhere((w) => w.id == word.id);
    if (idx == -1) {
      store.add(word);
    } else {
      store[idx] = word;
    }
  }

  @override
  Future<List<WordEntity>> getAll() async => List.unmodifiable(store);

  @override
  Future<void> remove(String id) async {
    store.removeWhere((w) => w.id == id);
  }
}

class _FakeGpt extends GptService {
  _FakeGpt() : super('');
  @override
  Future<String> explainWord(String word) async => 'desc:$word';
}

class _FakeTranslate extends TranslateService {
  _FakeTranslate() : super('');
  @override
  Future<String> translateToRu(String eng) async => 'ru:$eng';
}

void main() {
  setUp(() async {
    await sl.reset();
    final repo = _FakeRepo();
    sl
      ..registerLazySingleton<WordRepository>(() => repo)
      ..registerFactory<GetAllWords>(() => GetAllWords(sl()))
      ..registerFactory<AddWord>(() => AddWord(sl()))
      ..registerFactory<RemoveWord>(() => RemoveWord(sl()))
      ..registerLazySingleton<GptService>(() => _FakeGpt())
      ..registerLazySingleton<TranslateService>(() => _FakeTranslate());
  });

  test('DictionaryViewModel basic flow: load, add, edit, delete', () async {
    final vm = DictionaryViewModel();
    final seed = [
      legacy_model.Word(
        id: '1',
        eng: 'apple',
        rus: 'apple_ru',
        desc: 'seed',
        addedAt: DateTime.now(),
      ),
    ];

    await vm.load(seed: seed);
    expect(vm.words.length, 1);
    expect(vm.words.first.eng, 'apple');

    // Add
    expect(await vm.addWord(eng: 'cat', rus: 'cat_ru'), isTrue);
    expect(vm.words.length, 2);
    final added = vm.words.firstWhere((w) => w.eng == 'cat');
    expect(added.desc, 'desc:cat');

    // Edit
    final idx = vm.words.indexWhere((w) => w.eng == 'cat');
    expect(await vm.editWord(idx, eng: 'dog', rus: 'dog_ru'), isTrue);

    // Duplicate add (same eng) should be prevented
    expect(await vm.addWord(eng: 'dog', rus: 'dup_ru'), isFalse);
    // Diacritics and spacing duplicate checks
    expect(await vm.addWord(eng: 'Ápple', rus: 'apple_dup'), isFalse);
    expect(await vm.addWord(eng: 'dóg', rus: 'dog_dup'), isFalse);
    expect(vm.words[idx].eng, 'dog');
    expect(vm.words[idx].desc, 'desc:dog');

    // Delete
    final idToDelete = vm.words[idx].id;
    await vm.deleteById(idToDelete);
    expect(vm.words.any((w) => w.id == idToDelete), isFalse);

    // Now dog was removed; adding a spaced variant should succeed
    expect(await vm.addWord(eng: '  DoG  ', rus: 'dog_new'), isTrue);
  });
}
