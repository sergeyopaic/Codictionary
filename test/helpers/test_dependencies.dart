import 'dart:async';

import 'package:codictionary/composition/app_dependencies.dart';
import 'package:codictionary/data/repositories/word_repository_impl.dart';
import 'package:codictionary/data/storage/storage_service.dart';
import 'package:codictionary/domain/entities/word_entity.dart';
import 'package:codictionary/domain/services/translator.dart';
import 'package:codictionary/domain/services/word_explainer.dart';
import 'package:codictionary/presentation/app_scope.dart';

/// The app's real wiring ([buildUseCases]) over [storage], with fakes for
/// the external AI and translation services. No global state: every call
/// returns an independent object graph.
AppUseCases testUseCases({
  required StorageService storage,
  WordExplainer? explainer,
  Translator? translator,
}) => buildUseCases(
  storage: storage,
  explainer: explainer ?? const NoExplainer(),
  translator: translator ?? FakeTranslate(),
);

/// Stores [words] through the real repository, as if a user had added them
/// in an earlier session.
Future<void> seedWords(StorageService storage, List<WordEntity> words) async {
  final repo = WordRepositoryImpl(storage);
  for (final w in words) {
    await repo.create(w);
  }
}

/// Local mode: no AI configured.
class NoExplainer implements WordExplainer {
  const NoExplainer();

  @override
  bool get isAvailable => false;

  @override
  Future<String> explainShort(String word) => throw StateError('not set up');

  @override
  Future<String> explainLong(String word) => throw StateError('not set up');
}

/// Local mode translator: not configured.
class FakeTranslate implements Translator {
  @override
  bool get isAvailable => false;

  @override
  Future<String> translateToRu(String eng) async => 'ru:$eng';
}

/// Explainer whose responses the test releases explicitly, in any order.
class ControlledGpt implements WordExplainer {
  final List<({String kind, String word, Completer<String> completer})> calls =
      [];

  @override
  bool get isAvailable => true;

  Future<String> _call(String kind, String word) {
    final completer = Completer<String>();
    calls.add((kind: kind, word: word, completer: completer));
    return completer.future;
  }

  @override
  Future<String> explainShort(String word) => _call('short', word);

  @override
  Future<String> explainLong(String word) => _call('long', word);

  /// Answers call [i] with "kind:word#i".
  void answer(int i) {
    final c = calls[i];
    c.completer.complete('${c.kind}:${c.word}#$i');
  }
}

/// Translation fake whose answers the test releases explicitly.
class ControlledTranslate implements Translator {
  final List<({String text, Completer<String> completer})> calls = [];

  @override
  bool get isAvailable => true;

  @override
  Future<String> translateToRu(String eng) {
    final completer = Completer<String>();
    calls.add((text: eng, completer: completer));
    return completer.future;
  }
}
