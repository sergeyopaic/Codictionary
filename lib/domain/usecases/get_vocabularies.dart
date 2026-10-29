import '../entities/vocabulary.dart';
import '../repositories/vocabulary_repository.dart';

class GetVocabularies {
  final VocabularyRepository repository;
  GetVocabularies(this.repository);

  Future<List<Vocabulary>> call() => repository.getAll();
}
