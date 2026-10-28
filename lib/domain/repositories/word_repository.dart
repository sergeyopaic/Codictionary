import '../entities/word_entity.dart';
import '../exceptions/storage_exceptions.dart';

/// Storage failures surface as [StorageException]s; a failed write leaves the
/// stored words unchanged.
abstract class WordRepository {
  /// All stored words, in the user's manual order. Throws [StorageCorruptedException] or
  /// [StorageUnavailableException] instead of returning an empty list.
  Future<List<WordEntity>> getAll();

  /// Stores a new word at [index] in the manual order (appended if null).
  /// Throws [WordAlreadyExistsException] if its id exists.
  Future<void> create(WordEntity word, {int? index});

  /// Replaces an existing word. The stored creation date is always kept.
  /// Throws [WordNotFoundException] if the id is not stored.
  Future<void> update(WordEntity word);

  /// Removes a word. Removing a missing id is a no-op.
  Future<void> remove(String id);

  /// Saves a new manual order. Stored words missing from [orderedIds] keep
  /// their relative order after the listed ones; unknown ids are ignored.
  Future<void> reorder(List<String> orderedIds);

  /// Recovers damaged stored words; the damaged data is kept aside.
  Future<void> recover(StorageRecovery action);
}
