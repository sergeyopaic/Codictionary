import '../repositories/word_repository.dart';

class RemoveWord {
  final WordRepository repository;
  RemoveWord(this.repository);

  Future<void> call(String id) => repository.remove(id);
}
