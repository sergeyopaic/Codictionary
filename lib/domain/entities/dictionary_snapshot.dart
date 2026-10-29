import 'vocabulary.dart';
import 'word_entity.dart';

/// Everything a user has: words in their manual order and collections with
/// their members. This is what a backup contains.
class DictionarySnapshot {
  const DictionarySnapshot({
    required this.words,
    required this.vocabularies,
    required this.createdAt,
  });

  final List<WordEntity> words;
  final List<Vocabulary> vocabularies;

  /// When the snapshot was taken (the backup's date).
  final DateTime createdAt;
}
