import '../../domain/entities/word_entity.dart';
import '../../domain/repositories/word_repository.dart';
import '../../services/storage/storage_interface.dart' as legacy;
import '../../models/word.dart' as legacy_model;

class WordRepositoryImpl implements WordRepository {
  final legacy.StorageService storage;
  WordRepositoryImpl(this.storage);

  @override
  Future<void> add(WordEntity word) async {
    final list = await storage.loadWords();
    final newList = List<legacy_model.Word>.from(list)
      ..add(
        legacy_model.Word(
          id: word.id,
          eng: word.source,
          rus: word.target,
          desc: word.note,
        ),
      );
    await storage.saveWords(newList);
  }

  @override
  Future<List<WordEntity>> getAll() async {
    final words = await storage.loadWords();
    return words
        .map(
          (w) =>
              WordEntity(id: w.id, source: w.eng, target: w.rus, note: w.desc),
        )
        .toList(growable: false);
  }

  @override
  Future<void> remove(String id) async {
    final list = await storage.loadWords();
    final newList = list.where((w) => w.id != id).toList();
    await storage.saveWords(newList);
  }
}
