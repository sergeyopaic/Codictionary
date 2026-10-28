import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/data/repositories/word_repository_impl.dart';
import 'package:codictionary/domain/entities/word_entity.dart';
import 'package:codictionary/models/word.dart';
import 'package:codictionary/presentation/dictionary/dictionary_view_model.dart';

import '../fakes/json_storage_service.dart';
import '../helpers/test_dependencies.dart';

/// Storage whose reads and writes take a little time, so concurrent
/// read–modify–write cycles really interleave.
class _SlowStorage extends JsonStorageService {
  static const _delay = Duration(milliseconds: 5);

  @override
  Future<List<Word>> loadWords() async {
    await Future<void>.delayed(_delay);
    return super.loadWords();
  }

  @override
  Future<void> saveWords(List<Word> words) async {
    await Future<void>.delayed(_delay);
    return super.saveWords(words);
  }
}

WordEntity _word(String id, String source) => WordEntity(
  id: id,
  source: source,
  target: 'ru:$source',
  createdAt: DateTime.utc(2025, 1, int.parse(id)),
);

void main() {
  late JsonStorageService storage;
  late ControlledGpt gpt;
  late DictionaryViewModel vm;

  /// apple (id 1) and zebra (id 2), stored in that order.
  Future<void> setUpVm({JsonStorageService? withStorage}) async {
    storage = withStorage ?? JsonStorageService();
    gpt = ControlledGpt();
    await registerTestDependencies(storage: storage, gpt: gpt);
    vm = DictionaryViewModel();
    await seedWords(storage, [_word('1', 'apple'), _word('2', 'zebra')]);
    await vm.load();
  }

  Future<List<WordEntity>> stored() => WordRepositoryImpl(storage).getAll();

  WordEntity storedById(List<WordEntity> all, String id) =>
      all.firstWhere((w) => w.id == id);

  test(
    'explanation lands on its word even if the list was re-sorted',
    () async {
      await setUpVm();
      final pending = vm.regenerateShortExplanation('1'); // apple

      vm.setSort(SortMode.alphaDesc); // zebra moves to index 0
      gpt.answer(0);
      await pending;

      final all = await stored();
      expect(storedById(all, '1').shortExplanation, 'short:apple#0');
      expect(storedById(all, '2').shortExplanation, isNull);
      expect(vm.wordById('2')!.shortExplanation, isNull);
    },
  );

  test('a late explanation does not bring back a deleted word', () async {
    await setUpVm();
    final pending = vm.regenerateShortExplanation('1');

    await vm.deleteById('1');
    gpt.answer(0);
    expect(await pending, isNull);

    expect(vm.wordById('1'), isNull);
    expect((await stored()).map((w) => w.id), ['2']);
  });

  test('a late explanation is not attached to a renamed word', () async {
    await setUpVm();
    final regenerate = vm.regenerateShortExplanation('1'); // for "apple"
    final edit = vm.editWord('1', eng: 'pear', rus: 'груша'); // asks for "pear"

    gpt.answer(1); // pear
    expect(await edit, isTrue);
    gpt.answer(0); // apple, arrives last
    expect(await regenerate, isNull);

    final pear = storedById(await stored(), '1');
    expect(pear.source, 'pear');
    expect(pear.shortExplanation, 'short:pear#1');
  });

  test('an older, slower response does not overwrite a newer one', () async {
    await setUpVm();
    final first = vm.regenerateShortExplanation('1');
    final second = vm.regenerateShortExplanation('1');

    gpt.answer(1);
    await second;
    gpt.answer(0);
    expect(await first, isNull);

    expect(storedById(await stored(), '1').shortExplanation, 'short:apple#1');
  });

  test('adding the same word twice at once stores it only once', () async {
    await setUpVm();
    final a = vm.addWord(eng: 'cat', rus: 'кошка');
    final b = vm.addWord(eng: 'Cat ', rus: 'кот');

    expect(gpt.calls, hasLength(1), reason: 'the second add is rejected');
    gpt.answer(0);

    expect(await Future.wait([a, b]), [true, false]);
    final cats = (await stored()).where((w) => w.source.trim() == 'cat');
    expect(cats, hasLength(1));
    expect(vm.words.where((w) => w.source == 'cat'), hasLength(1));
  });

  test('a repeated delete does not remove a neighbouring word', () async {
    await setUpVm();

    await Future.wait([vm.deleteById('1'), vm.deleteById('1')]);
    await vm.deleteById('1');

    expect(vm.words.map((w) => w.id), ['2']);
    expect((await stored()).map((w) => w.id), ['2']);
  });

  test('two overlapping writes are both kept', () async {
    await setUpVm(withStorage: _SlowStorage());
    final repo = WordRepositoryImpl(storage);
    final all = await repo.getAll();

    await Future.wait([
      repo.update(storedById(all, '1').copyWith(target: 'яблоко')),
      repo.update(storedById(all, '2').copyWith(target: 'зебра')),
    ]);

    final after = await repo.getAll();
    expect(storedById(after, '1').target, 'яблоко');
    expect(storedById(after, '2').target, 'зебра');
  });

  test('closing the screen during generation does not crash', () async {
    await setUpVm();
    final pending = vm.regenerateShortExplanation('1');

    vm.dispose();
    gpt.answer(0);

    // Would throw "used after being disposed" if it still notified.
    await expectLater(pending, completion('short:apple#0'));
    expect(storedById(await stored(), '1').shortExplanation, 'short:apple#0');
  });
}
