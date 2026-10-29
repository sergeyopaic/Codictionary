import '../services/word_explainer.dart';

/// Short and detailed AI explanations of an English word.
class ExplainWord {
  final WordExplainer explainer;
  ExplainWord(this.explainer);

  /// False in local mode.
  bool get isAvailable => explainer.isAvailable;

  Future<String> short(String word) => explainer.explainShort(word);

  Future<String> long(String word) => explainer.explainLong(word);
}
