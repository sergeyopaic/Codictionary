import 'package:uuid/uuid.dart';

import '../entities/vocabulary.dart';
import '../repositories/vocabulary_repository.dart';

/// Creates an empty collection with a new stable id.
class CreateVocabulary {
  final VocabularyRepository repository;
  CreateVocabulary(this.repository);

  Future<Vocabulary> call({
    required String name,
    required String description,
    required String iconPath,
  }) async {
    final vocabulary = Vocabulary(
      id: const Uuid().v4(),
      name: name,
      description: description,
      iconPath: iconPath,
    );
    await repository.create(vocabulary);
    return vocabulary;
  }
}

/// Renames a collection or changes its description or icon.
class UpdateVocabulary {
  final VocabularyRepository repository;
  UpdateVocabulary(this.repository);

  Future<void> call(Vocabulary vocabulary) =>
      repository.updateDetails(vocabulary);
}

/// Deletes a collection and its links; words stay in the dictionary.
class DeleteVocabulary {
  final VocabularyRepository repository;
  DeleteVocabulary(this.repository);

  Future<void> call(String id) => repository.remove(id);
}

/// Undo for [DeleteVocabulary]: brings back the collection and its links.
class RestoreVocabulary {
  final VocabularyRepository repository;
  RestoreVocabulary(this.repository);

  Future<void> call(Vocabulary vocabulary, {int? index}) =>
      repository.create(vocabulary, index: index);
}

/// Adds a word to, or removes it from, a collection.
class SetWordInVocabulary {
  final VocabularyRepository repository;
  SetWordInVocabulary(this.repository);

  Future<void> call({
    required String vocabularyId,
    required String wordId,
    required bool member,
  }) => repository.setMembership(vocabularyId, wordId, member);
}
