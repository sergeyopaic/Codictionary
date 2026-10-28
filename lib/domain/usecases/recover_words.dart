import '../exceptions/storage_exceptions.dart';
import '../repositories/word_repository.dart';

/// Recovers a damaged dictionary by restoring the backup or starting empty.
/// The damaged data is always kept aside, never deleted.
class RecoverWords {
  final WordRepository repository;
  RecoverWords(this.repository);

  Future<void> call(StorageRecovery action) => repository.recover(action);
}
