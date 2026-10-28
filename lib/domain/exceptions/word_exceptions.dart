/// Thrown when updating or reading a word id that is not stored.
class WordNotFoundException implements Exception {
  final String id;
  const WordNotFoundException(this.id);

  @override
  String toString() => 'WordNotFoundException: no word with id "$id"';
}

/// Thrown when creating a word whose id is already stored.
class WordAlreadyExistsException implements Exception {
  final String id;
  const WordAlreadyExistsException(this.id);

  @override
  String toString() => 'WordAlreadyExistsException: id "$id" already exists';
}
