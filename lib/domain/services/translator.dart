/// Translates English text into Russian.
abstract interface class Translator {
  /// False in local mode: translations are typed by the user.
  bool get isAvailable;

  /// Throws a `ServiceException` on failure.
  Future<String> translateToRu(String text);
}
