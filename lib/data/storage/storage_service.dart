import '../../domain/exceptions/storage_exceptions.dart';
import '../models/vocabulary_record.dart';
import '../models/word_record.dart';

/// Local persistence. Missing data reads as empty; any other failure throws a
/// [StorageException] instead of pretending the data is empty.
abstract class StorageService {
  /// Throws [StorageCorruptedException] or [StorageUnavailableException].
  Future<List<WordRecord>> loadWords();

  /// Throws [StorageWriteException]; stored data is unchanged on failure.
  /// Refuses to overwrite damaged data ([StorageCorruptedException]).
  Future<void> saveWords(List<WordRecord> words);

  /// Recovers a damaged dictionary; the damaged data is kept aside.
  Future<void> recoverWords(StorageRecovery action);

  /// Preferences. Missing or unreadable settings read as empty; saving
  /// replaces them (they are not worth protecting like words).
  Future<Map<String, String>> loadSettings();
  Future<void> saveSettings(Map<String, String> settings);

  /// Collections. Same failure contract as words.
  Future<List<VocabularyRecord>> loadVocabularies();
  Future<void> saveVocabularies(List<VocabularyRecord> vocabs);
}
