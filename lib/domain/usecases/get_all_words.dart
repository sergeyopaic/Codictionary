import '../entities/word_entity.dart';
import '../repositories/word_repository.dart';

class GetAllWords {
  final WordRepository repository;
  GetAllWords(this.repository);

  Future<List<WordEntity>> call() => repository.getAll();
}

