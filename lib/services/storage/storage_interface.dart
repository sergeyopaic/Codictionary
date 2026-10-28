import '../../domain/exceptions/storage_exceptions.dart';
import '../../models/word.dart';

/// Local persistence. Missing data reads as empty; any other failure throws a
/// [StorageException] instead of pretending the data is empty.
abstract class StorageService {
  /// Throws [StorageCorruptedException] or [StorageUnavailableException].
  Future<List<Word>> loadWords();

  /// Throws [StorageWriteException]; stored data is unchanged on failure.
  /// Refuses to overwrite damaged data ([StorageCorruptedException]).
  Future<void> saveWords(List<Word> words);

  /// Recovers a damaged dictionary; the damaged data is kept aside.
  Future<void> recoverWords(StorageRecovery action);

  // Vocabulary storage (name, description, iconPath)
  Future<List<Map<String, String>>> loadVocabularies();
  Future<void> saveVocabularies(List<Map<String, String>> vocabs);
}
