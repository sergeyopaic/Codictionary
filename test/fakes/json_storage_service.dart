import 'dart:convert';

import 'package:codictionary/models/word.dart';
import 'package:codictionary/services/storage/storage_interface.dart';

/// In-memory storage that keeps data as a JSON string, exactly like the file
/// and localStorage implementations. Going through [Word.toMap] /
/// [Word.fromMap] on every call exercises the real persistence mapping.
class JsonStorageService implements StorageService {
  JsonStorageService({List<Map<String, dynamic>>? rawWords})
    : wordsJson = jsonEncode(rawWords ?? const []);

  String wordsJson;
  String vocabsJson = '[]';

  List<Map<String, dynamic>> get rawWords =>
      (jsonDecode(wordsJson) as List).cast<Map<String, dynamic>>();

  @override
  Future<List<Word>> loadWords() async => rawWords.map(Word.fromMap).toList();

  @override
  Future<void> saveWords(List<Word> words) async =>
      wordsJson = jsonEncode(words.map((w) => w.toMap()).toList());

  @override
  Future<List<Map<String, String>>> loadVocabularies() async =>
      (jsonDecode(vocabsJson) as List)
          .map((e) => Map<String, String>.from(e as Map))
          .toList();

  @override
  Future<void> saveVocabularies(List<Map<String, String>> vocabs) async =>
      vocabsJson = jsonEncode(vocabs);
}
