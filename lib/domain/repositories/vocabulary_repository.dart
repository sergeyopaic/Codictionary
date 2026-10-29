import '../entities/vocabulary.dart';
import '../exceptions/storage_exceptions.dart';

/// Storage failures surface as [StorageException]s.
abstract class VocabularyRepository {
  Future<List<Vocabulary>> getAll();

  /// Replaces the stored list; unchanged on failure.
  Future<void> saveAll(List<Vocabulary> vocabularies);
}
