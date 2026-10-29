import '../services/translator.dart';

/// EN → RU translation of a word or phrase.
class TranslateWord {
  final Translator translator;
  TranslateWord(this.translator);

  /// False in local mode.
  bool get isAvailable => translator.isAvailable;

  Future<String> call(String text) => translator.translateToRu(text);
}
