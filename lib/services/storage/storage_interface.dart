import '../../models/word.dart';

abstract class StorageService {
  Future<List<Word>> loadWords();
  Future<void> saveWords(List<Word> words);
}
