import '../repositories/word_repository.dart';

/// Saves the user's manual order of words (by id).
class ReorderWords {
  final WordRepository repository;
  ReorderWords(this.repository);

  Future<void> call(List<String> orderedIds) => repository.reorder(orderedIds);
}
