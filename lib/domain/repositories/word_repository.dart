import '../entities/word_entity.dart';
import '../exceptions/storage_exceptions.dart';

/// Storage failures surface as [StorageException]s; a failed write leaves the
/// stored words unchanged.
abstract class WordRepository {
  /// All stored words, in stored order. Throws [StorageCorruptedException] or
  /// [StorageUnavailableException] instead of returning an empty list.
  Future<List<WordEntity>> getAll();

  /// Stores a new word. Throws [WordAlreadyExistsException] if its id exists.
  Future<void> create(WordEntity word);

  /// Replaces an existing word. The stored creation date is always kept.
  /// Throws [WordNotFoundException] if the id is not stored.
  Future<void> update(WordEntity word);

  /// Removes a word. Removing a missing id is a no-op.
  Future<void> remove(String id);

  /// Recovers damaged stored words; the damaged data is kept aside.
  Future<void> recover(StorageRecovery action);
}
