import '../entities/vocabulary.dart';
import '../exceptions/storage_exceptions.dart';

/// Collections and their members. Storage failures surface as
/// [StorageException]s and leave the stored data unchanged.
abstract class VocabularyRepository {
  /// All collections in display order.
  Future<List<Vocabulary>> getAll();

  /// Stores a new collection (with its members) at [index], appended if null.
  Future<void> create(Vocabulary vocabulary, {int? index});

  /// Changes name, description and icon. Members are kept as stored, so an
  /// edit never undoes a membership change made meanwhile. Missing ids are
  /// ignored.
  Future<void> updateDetails(Vocabulary vocabulary);

  /// Removes a collection and its links; the words themselves stay.
  Future<void> remove(String id);

  /// Replaces every stored collection (restore from a backup).
  Future<void> replaceAll(List<Vocabulary> vocabularies);

  /// Adds or removes one word, atomically. Idempotent.
  Future<void> setMembership(String vocabularyId, String wordId, bool member);
}
