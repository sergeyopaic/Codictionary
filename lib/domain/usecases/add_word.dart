import 'package:uuid/uuid.dart';
import '../../core/usecase.dart';
import '../entities/word_entity.dart';
import '../repositories/word_repository.dart';

class AddWord implements UseCase<void, AddWordParams> {
  final WordRepository repository;
  AddWord(this.repository);

  @override
  Future<void> call(AddWordParams params) async {
    final id = params.id ?? const Uuid().v4();
    await repository.add(
      WordEntity(
        id: id,
        source: params.source,
        target: params.target,
        note: params.note,
      ),
    );
  }
}

class AddWordParams {
  final String? id;
  final String source;
  final String target;
  final String? note;

  const AddWordParams({
    this.id,
    required this.source,
    required this.target,
    this.note,
  });
}
