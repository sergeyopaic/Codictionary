import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/data/repositories/word_repository_impl.dart';
import 'package:codictionary/domain/entities/word_entity.dart';
import 'package:codictionary/domain/exceptions/service_exceptions.dart';
import 'package:codictionary/presentation/dictionary/dictionary_view_model.dart';
import 'package:codictionary/services/gpt_service.dart';

import '../fakes/json_storage_service.dart';
import '../helpers/test_dependencies.dart';

/// GPT fake answering from a script: a String is returned, a
/// [ServiceException] is thrown.
class _ScriptedGpt extends GptService {
  _ScriptedGpt(this.script, {this.configured = true}) : super('');

  final List<Object> script;
  final bool configured;
  int calls = 0;

  @override
  bool get isConfigured => configured;

  @override
  Future<String> explainWordShort(String word) async {
    final next = script[calls++];
    if (next is ServiceException) throw next;
    return next as String;
  }
}

const _offline = ServiceException('OpenAI', ServiceFailure.network);
const _noCredit = ServiceException('OpenAI', ServiceFailure.quotaExceeded);

void main() {
  late JsonStorageService storage;

  Future<DictionaryViewModel> start(dynamic gpt) async {
    storage = JsonStorageService();
    await registerTestDependencies(storage: storage, gpt: gpt);
    final vm = DictionaryViewModel();
    await vm.load();
    return vm;
  }

  Future<List<WordEntity>> stored() => WordRepositoryImpl(storage).getAll();

  test('the word is saved at once while the AI is still thinking', () async {
    final gpt = ControlledGpt();
    final vm = await start(gpt);

    expect(await vm.addWord(eng: 'cat', rus: 'кошка'), isTrue);

    final id = vm.words.single.id;
    expect((await stored()).single.source, 'cat');
    expect(vm.isGenerating(id, ExplanationKind.short), isTrue);

    gpt.answer(0);
    await vm.whenIdle();
    expect(vm.isGenerating(id, ExplanationKind.short), isFalse);
    expect((await stored()).single.shortExplanation, 'short:cat#0');
  });

  test('offline: the word is kept and the failure is visible', () async {
    final vm = await start(_ScriptedGpt([_offline]));

    expect(await vm.addWord(eng: 'cat', rus: 'кошка'), isTrue);
    await vm.whenIdle();

    final id = vm.words.single.id;
    expect(
      vm.generationError(id, ExplanationKind.short),
      isA<ServiceException>().having(
        (e) => e.failure,
        'failure',
        ServiceFailure.network,
      ),
    );
    final saved = (await stored()).single;
    expect(saved.source, 'cat');
    expect(saved.shortExplanation, isNull, reason: 'no diagnostic text saved');
  });

  test('retrying after the balance is restored adds no duplicate', () async {
    final vm = await start(_ScriptedGpt([_noCredit, 'Кошка — животное.']));
    await vm.addWord(eng: 'cat', rus: 'кошка');
    await vm.whenIdle();
    final id = vm.words.single.id;
    expect(vm.generationError(id, ExplanationKind.short), _noCredit);

    await vm.regenerateShortExplanation(id);

    expect(vm.generationError(id, ExplanationKind.short), isNull);
    final all = await stored();
    expect(all, hasLength(1));
    expect(all.single.shortExplanation, 'Кошка — животное.');
  });

  test('local mode: no AI request and no error', () async {
    final gpt = _ScriptedGpt([], configured: false);
    final vm = await start(gpt);

    expect(vm.aiAvailable, isFalse);
    expect(await vm.addWord(eng: 'cat', rus: 'кошка'), isTrue);
    await vm.whenIdle();

    final id = vm.words.single.id;
    expect(gpt.calls, 0);
    expect(vm.isGenerating(id, ExplanationKind.short), isFalse);
    expect(vm.generationError(id, ExplanationKind.short), isNull);
  });

  test('renaming during generation shows only the new request', () async {
    final gpt = ControlledGpt();
    final vm = await start(gpt);
    await vm.addWord(eng: 'cat', rus: 'кошка'); // #0 for "cat"
    final id = vm.words.single.id;

    await vm.editWord(id, eng: 'dog', rus: 'собака'); // #1 for "dog"
    gpt.answer(0); // "cat" is outdated
    await Future<void>.delayed(Duration.zero);

    expect(vm.isGenerating(id, ExplanationKind.short), isTrue);
    expect(vm.wordById(id)!.shortExplanation, isNull);
    gpt.answer(1);
    await vm.whenIdle();
    expect(vm.wordById(id)!.shortExplanation, 'short:dog#1');
  });
}
