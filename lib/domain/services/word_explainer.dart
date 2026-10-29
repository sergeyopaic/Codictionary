/// Writes explanations of English words (implemented by an AI client).
abstract interface class WordExplainer {
  /// False in local mode: nothing is configured, so nothing is requested.
  bool get isAvailable;

  /// A short explanation. Throws a `ServiceException` on failure; never
  /// returns diagnostic text.
  Future<String> explainShort(String word);

  /// A detailed explanation. Same contract as [explainShort].
  Future<String> explainLong(String word);
}
