import '../entities/word_entity.dart';
import '../repositories/word_repository.dart';

/// Puts back a previously removed word with all of its fields, including the
/// original id and creation date (used by Undo).
class RestoreWord {
  final WordRepository repository;
  RestoreWord(this.repository);

  Future<void> call(WordEntity word) => repository.create(word);
}
