import 'package:codictionary/presentation/app_scope.dart';
import 'package:codictionary/domain/services/word_explainer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codictionary/domain/entities/word_entity.dart';
import 'package:codictionary/presentation/dictionary/dictionary_view_model.dart';

import 'fakes/json_storage_service.dart';
import 'helpers/test_dependencies.dart';

class _FakeGpt implements WordExplainer {
  _FakeGpt();
  bool fail = false;

  @override
  bool get isAvailable => true;

  @override
  Future<String> explainShort(String word) async {
    if (fail) throw Exception('offline');
    return 'desc:$word';
  }

  @override
  Future<String> explainLong(String word) async {
    if (fail) throw Exception('offline');
    return 'long:$word';
  }
}

void main() {
  late AppUseCases useCases;
  late JsonStorageService storage;
  late _FakeGpt gpt;

  setUp(() async {
    storage = JsonStorageService();
    gpt = _FakeGpt();
    useCases = testUseCases(storage: storage, explainer: gpt);
  });

  /// A fresh view model over the same storage, i.e. an app restart.
  Future<DictionaryViewModel> restart() async {
    final vm = DictionaryViewModel(useCases);
    await vm.load();
    return vm;
  }

  WordEntity byEng(DictionaryViewModel vm, String eng) =>
      vm.words.firstWhere((w) => w.source == eng);

  test('DictionaryViewModel basic flow: load, add, edit, delete', () async {
    final vm = DictionaryViewModel(useCases);
    final seed = [
      WordEntity(
        id: '1',
        source: 'apple',
        target: 'apple_ru',
        shortExplanation: 'seed',
        createdAt: DateTime.now(),
      ),
    ];

    await seedWords(storage, seed);
    await vm.load();
    expect(vm.words.length, 1);
    expect(vm.words.first.source, 'apple');

    // Add
    expect(await vm.addWord(eng: 'cat', rus: 'cat_ru'), isTrue);
    await vm.whenIdle();
    expect(vm.words.length, 2);
    final added = vm.words.firstWhere((w) => w.source == 'cat');
    expect(added.shortExplanation, 'desc:cat');

    // Edit
    final idx = vm.words.indexWhere((w) => w.source == 'cat');
    expect(
      await vm.editWord(vm.words[idx].id, eng: 'dog', rus: 'dog_ru'),
      isTrue,
    );
    await vm.whenIdle();

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
    await vm.whenIdle();
    final createdAt = byEng(vm, 'resilient').createdAt;

    await vm.generateLongExplanation(vm.words[0].id);

    final reloaded = byEng(await restart(), 'resilient');
    expect(reloaded.shortExplanation, 'desc:resilient');
    expect(reloaded.longExplanation, 'long:resilient');
    expect(reloaded.createdAt, createdAt);
  });

  test('editing only the translation keeps both explanations', () async {
    final vm = await restart();
    await vm.addWord(eng: 'resilient', rus: 'стойкий');
    await vm.whenIdle();
    await vm.generateLongExplanation(vm.words[0].id);
    gpt.fail = true; // nothing may be regenerated

    await vm.editWord(vm.words[0].id, eng: 'resilient', rus: 'устойчивый');

    final reloaded = byEng(await restart(), 'resilient');
    expect(reloaded.target, 'устойчивый');
    expect(reloaded.shortExplanation, 'desc:resilient');
    expect(reloaded.longExplanation, 'long:resilient');
  });

  test('changing the English word invalidates old explanations', () async {
    final vm = await restart();
    await vm.addWord(eng: 'resilient', rus: 'стойкий');
    await vm.whenIdle();
    await vm.generateLongExplanation(vm.words[0].id);

    await vm.editWord(vm.words[0].id, eng: 'robust', rus: 'надёжный');
    await vm.whenIdle();

    final reloaded = byEng(await restart(), 'robust');
    expect(reloaded.shortExplanation, 'desc:robust');
    expect(reloaded.longExplanation, isNull);
  });

  test('when regeneration fails, stale explanations are not kept', () async {
    final vm = await restart();
    await vm.addWord(eng: 'resilient', rus: 'стойкий');
    await vm.whenIdle();
    await vm.generateLongExplanation(vm.words[0].id);
    gpt.fail = true;

    await vm.editWord(vm.words[0].id, eng: 'robust', rus: 'надёжный');
    await vm.whenIdle();

    final reloaded = byEng(await restart(), 'robust');
    expect(reloaded.shortExplanation, isNull);
    expect(reloaded.longExplanation, isNull);
  });

  test('undo restores every field of a deleted word', () async {
    final vm = await restart();
    await vm.addWord(eng: 'resilient', rus: 'стойкий');
    await vm.whenIdle();
    await vm.generateLongExplanation(vm.words[0].id);
    final before = byEng(vm, 'resilient');

    await vm.deleteById(before.id);
    await vm.restoreWord(before);

    expect(byEng(await restart(), 'resilient'), before);
  });

  test('regenerated explanation reaches the grid (filtered list)', () async {
    final vm = DictionaryViewModel(useCases);
    await seedWords(storage, [
      WordEntity(
        id: '1',
        source: 'apple',
        target: 'apple_ru',
        shortExplanation: 'old',
        createdAt: DateTime.now(),
      ),
    ]);
    await vm.load();

    await vm.regenerateShortExplanation('1');

    expect(vm.words.first.shortExplanation, 'desc:apple');
    expect(vm.filtered.first.shortExplanation, 'desc:apple');
  });
}
