import '../../domain/entities/word_entity.dart';

abstract class WordRepository {
  Future<List<WordEntity>> getAll();
  Future<void> add(WordEntity word);
  Future<void> remove(String id);
}
