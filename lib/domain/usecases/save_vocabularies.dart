import '../entities/vocabulary.dart';
import '../repositories/vocabulary_repository.dart';

class SaveVocabularies {
  final VocabularyRepository repository;
  SaveVocabularies(this.repository);

  Future<void> call(List<Vocabulary> vocabularies) =>
      repository.saveAll(vocabularies);
}
