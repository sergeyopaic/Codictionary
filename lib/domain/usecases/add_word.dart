import 'package:uuid/uuid.dart';
import '../../core/usecase.dart';
import '../entities/word_entity.dart';
import '../repositories/word_repository.dart';

/// Creates a new word with a fresh id and creation date.
class AddWord implements UseCase<WordEntity, AddWordParams> {
  final WordRepository repository;
  AddWord(this.repository);

  @override
  Future<WordEntity> call(AddWordParams params) async {
    final word = WordEntity(
      id: params.id ?? const Uuid().v4(),
      source: params.source,
      target: params.target,
      shortExplanation: params.shortExplanation,
      createdAt: (params.createdAt ?? DateTime.now()).toUtc(),
    );
    await repository.create(word);
    return word;
  }
}

class AddWordParams {
  final String? id;
  final String source;
  final String target;
  final String? shortExplanation;
  final DateTime? createdAt;

  const AddWordParams({
    this.id,
    required this.source,
    required this.target,
    this.shortExplanation,
    this.createdAt,
  });
}
