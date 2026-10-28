import 'package:flutter_test/flutter_test.dart';
import 'package:codictionary/core/di/service_locator.dart';
import 'package:codictionary/data/repositories/word_repository_impl.dart';
import 'package:codictionary/domain/entities/word_entity.dart';
import 'package:codictionary/domain/repositories/word_repository.dart';
import 'package:codictionary/domain/usecases/add_word.dart';
import 'package:codictionary/domain/usecases/get_all_words.dart';
import 'package:codictionary/domain/usecases/remove_word.dart';
import 'package:codictionary/domain/usecases/restore_word.dart';
import 'package:codictionary/domain/usecases/update_word.dart';
import 'package:codictionary/presentation/dictionary/dictionary_view_model.dart';
import 'package:codictionary/services/gpt_service.dart';
import 'package:codictionary/services/translate_service.dart';

import 'fakes/json_storage_service.dart';

class _FakeGpt extends GptService {
  _FakeGpt() : super('');
  bool fail = false;

  @override
  Future<String> explainWordShort(String word) async {
    if (fail) throw Exception('offline');
    return 'desc:$word';
  }

  @override
  Future<String> explainWordLong(String word) async {
    if (fail) throw Exception('offline');
    return 'long:$word';
  }
}

class _FakeTranslate extends TranslateService {
  _FakeTranslate() : super('');
  @override
  Future<String> translateToRu(String eng) async => 'ru:$eng';
}

void main() {
  late JsonStorageService storage;
  late _FakeGpt gpt;

  setUp(() async {
    await sl.reset();
    storage = JsonStorageService();
    gpt = _FakeGpt();
    sl
      ..registerLazySingleton<WordRepository>(() => WordRepositoryImpl(storage))
      ..registerFactory<GetAllWords>(() => GetAllWords(sl()))
      ..registerFactory<AddWord>(() => AddWord(sl()))
      ..registerFactory<UpdateWord>(() => UpdateWord(sl()))
      ..registerFactory<RestoreWord>(() => RestoreWord(sl()))
      ..registerFactory<RemoveWord>(() => RemoveWord(sl()))
      ..registerLazySingleton<GptService>(() => gpt)
      ..registerLazySingleton<TranslateService>(() => _FakeTranslate());
  });

  /// A fresh view model over the same storage, i.e. an app restart.
  Future<DictionaryViewModel> restart() async {
    final vm = DictionaryViewModel();
    await vm.load();
    return vm;
  }

  WordEntity byEng(DictionaryViewModel vm, String eng) =>
      vm.words.firstWhere((w) => w.source == eng);

  test('DictionaryViewModel basic flow: load, add, edit, delete', () async {
    final vm = DictionaryViewModel();
    final seed = [
      WordEntity(
        id: '1',
        source: 'apple',
        target: 'apple_ru',
        shortExplanation: 'seed',
        createdAt: DateTime.now(),
      ),
    ];

    await vm.load(seed: seed);
    expect(vm.words.length, 1);
    expect(vm.words.first.source, 'apple');

    // Add
    expect(await vm.addWord(eng: 'cat', rus: 'cat_ru'), isTrue);
    expect(vm.words.length, 2);
    final added = vm.words.firstWhere((w) => w.source == 'cat');
    expect(added.shortExplanation, 'desc:cat');

    // Edit
    final idx = vm.words.indexWhere((w) => w.source == 'cat');
    expect(await vm.editWord(idx, eng: 'dog', rus: 'dog_ru'), isTrue);

    // Duplicate add (same eng) should be prevented
    expect(await vm.addWord(eng: 'dog', rus: 'dup_ru'), isFalse);
    // Diacritics and spacing duplicate checks
    expect(await vm.addWord(eng: 'Ápple', rus: 'apple_dup'), isFalse);
    expect(await vm.addWord(eng: 'dóg', rus: 'dog_dup'), isFalse);
    expect(vm.words[idx].source, 'dog');
    expect(vm.words[idx].shortExplanation, 'desc:dog');

    // Delete
    final idToDelete = vm.words[idx].id;
    await vm.deleteById(idToDelete);
    expect(vm.words.any((w) => w.id == idToDelete), isFalse);

    // Now dog was removed; adding a spaced variant should succeed
    expect(await vm.addWord(eng: '  DoG  ', rus: 'dog_new'), isTrue);
  });

  test('long explanation and creation date survive a restart', () async {
    final vm = await restart();
    await vm.addWord(eng: 'resilient', rus: 'стойкий');
    final createdAt = byEng(vm, 'resilient').createdAt;

    await vm.generateOrRegenerateLong(0);

    final reloaded = byEng(await restart(), 'resilient');
    expect(reloaded.shortExplanation, 'desc:resilient');
    expect(reloaded.longExplanation, 'long:resilient');
    expect(reloaded.createdAt, createdAt);
  });

  test('editing only the translation keeps both explanations', () async {
    final vm = await restart();
    await vm.addWord(eng: 'resilient', rus: 'стойкий');
    await vm.generateOrRegenerateLong(0);
    gpt.fail = true; // nothing may be regenerated

    await vm.editWord(0, eng: 'resilient', rus: 'устойчивый');

    final reloaded = byEng(await restart(), 'resilient');
    expect(reloaded.target, 'устойчивый');
    expect(reloaded.shortExplanation, 'desc:resilient');
    expect(reloaded.longExplanation, 'long:resilient');
  });

  test('changing the English word invalidates old explanations', () async {
    final vm = await restart();
    await vm.addWord(eng: 'resilient', rus: 'стойкий');
    await vm.generateOrRegenerateLong(0);

    await vm.editWord(0, eng: 'robust', rus: 'надёжный');

    final reloaded = byEng(await restart(), 'robust');
    expect(reloaded.shortExplanation, 'desc:robust');
    expect(reloaded.longExplanation, isNull);
  });

  test('when regeneration fails, stale explanations are not kept', () async {
    final vm = await restart();
    await vm.addWord(eng: 'resilient', rus: 'стойкий');
    await vm.generateOrRegenerateLong(0);
    gpt.fail = true;

    await vm.editWord(0, eng: 'robust', rus: 'надёжный');

    final reloaded = byEng(await restart(), 'robust');
    expect(reloaded.shortExplanation, isNull);
    expect(reloaded.longExplanation, isNull);
  });

  test('undo restores every field of a deleted word', () async {
    final vm = await restart();
    await vm.addWord(eng: 'resilient', rus: 'стойкий');
    await vm.generateOrRegenerateLong(0);
    final before = byEng(vm, 'resilient');

    await vm.deleteById(before.id);
    await vm.restoreWord(before);

    expect(byEng(await restart(), 'resilient'), before);
  });

  test('regenerated explanation reaches the grid (filtered list)', () async {
    final vm = DictionaryViewModel();
    await vm.load(
      seed: [
        WordEntity(
          id: '1',
          source: 'apple',
          target: 'apple_ru',
          shortExplanation: 'old',
          createdAt: DateTime.now(),
        ),
      ],
    );

    await vm.regenerateDescription(0);

    expect(vm.words.first.shortExplanation, 'desc:apple');
    expect(vm.filtered.first.shortExplanation, 'desc:apple');
  });
}
