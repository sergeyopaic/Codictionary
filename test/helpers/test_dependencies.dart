import 'dart:async';

import 'package:codictionary/core/di/service_locator.dart';
import 'package:codictionary/data/repositories/word_repository_impl.dart';
import 'package:codictionary/domain/repositories/word_repository.dart';
import 'package:codictionary/domain/usecases/add_word.dart';
import 'package:codictionary/domain/usecases/get_all_words.dart';
import 'package:codictionary/domain/usecases/recover_words.dart';
import 'package:codictionary/domain/usecases/remove_word.dart';
import 'package:codictionary/domain/usecases/restore_word.dart';
import 'package:codictionary/domain/usecases/update_word.dart';
import 'package:codictionary/services/gpt_service.dart';
import 'package:codictionary/services/storage/storage_interface.dart';
import 'package:codictionary/services/translate_service.dart';

/// Registers the real repository and use cases over [storage], plus fakes for
/// the external AI and translation services.
Future<void> registerTestDependencies({
  required StorageService storage,
  required GptService gpt,
  TranslateService? translate,
}) async {
  await sl.reset();
  sl
    ..registerLazySingleton<WordRepository>(() => WordRepositoryImpl(storage))
    ..registerFactory<GetAllWords>(() => GetAllWords(sl()))
    ..registerFactory<AddWord>(() => AddWord(sl()))
    ..registerFactory<UpdateWord>(() => UpdateWord(sl()))
    ..registerFactory<RestoreWord>(() => RestoreWord(sl()))
    ..registerFactory<RecoverWords>(() => RecoverWords(sl()))
    ..registerFactory<RemoveWord>(() => RemoveWord(sl()))
    ..registerLazySingleton<GptService>(() => gpt)
    ..registerLazySingleton<TranslateService>(
      () => translate ?? FakeTranslate(),
    );
}

class FakeTranslate extends TranslateService {
  FakeTranslate() : super('');
  @override
  Future<String> translateToRu(String eng) async => 'ru:$eng';
}

/// GPT fake whose responses the test releases explicitly, in any order.
class ControlledGpt extends GptService {
  ControlledGpt() : super('');

  final List<({String kind, String word, Completer<String> completer})> calls =
      [];

  Future<String> _call(String kind, String word) {
    final completer = Completer<String>();
    calls.add((kind: kind, word: word, completer: completer));
    return completer.future;
  }

  @override
  Future<String> explainWordShort(String word) => _call('short', word);

  @override
  Future<String> explainWordLong(String word) => _call('long', word);

  /// Answers call [i] with "kind:word#i".
  void answer(int i) {
    final c = calls[i];
    c.completer.complete('${c.kind}:${c.word}#$i');
  }
}
