import '../../models/word.dart';

abstract class StorageService {
  Future<List<Word>> loadWords();
  Future<void> saveWords(List<Word> words);

  // Vocabulary storage (name, description, iconPath)
  Future<List<Map<String, String>>> loadVocabularies();
  Future<void> saveVocabularies(List<Map<String, String>> vocabs);
}
