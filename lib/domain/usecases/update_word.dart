import '../entities/word_entity.dart';
import '../repositories/word_repository.dart';

/// Saves changes to an existing word. Its creation date is preserved.
class UpdateWord {
  final WordRepository repository;
  UpdateWord(this.repository);

  Future<void> call(WordEntity word) => repository.update(word);
}
