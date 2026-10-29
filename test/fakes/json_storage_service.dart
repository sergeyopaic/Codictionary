import 'dart:convert';

import 'package:codictionary/domain/exceptions/storage_exceptions.dart';
import 'package:codictionary/data/models/word_record.dart';
import 'package:codictionary/data/storage/storage_service.dart';

/// In-memory storage that keeps data as a JSON string, exactly like the file
/// and localStorage implementations. Going through [WordRecord.toMap] /
/// [WordRecord.fromMap] on every call exercises the real persistence mapping.
class JsonStorageService implements StorageService {
  JsonStorageService({List<Map<String, dynamic>>? rawWords})
    : wordsJson = jsonEncode(rawWords ?? const []);

  String wordsJson;
  String vocabsJson = '[]';

  List<Map<String, dynamic>> get rawWords =>
      (jsonDecode(wordsJson) as List).cast<Map<String, dynamic>>();

  @override
  Future<List<WordRecord>> loadWords() async =>
      rawWords.map(WordRecord.fromMap).toList();

  @override
  Future<void> saveWords(List<WordRecord> words) async =>
      wordsJson = jsonEncode(words.map((w) => w.toMap()).toList());

  @override
  Future<void> recoverWords(StorageRecovery action) async =>
      throw UnsupportedError('JsonStorageService never reports damage');

  @override
  Future<List<Map<String, String>>> loadVocabularies() async =>
      (jsonDecode(vocabsJson) as List)
          .map((e) => Map<String, String>.from(e as Map))
          .toList();

  @override
  Future<void> saveVocabularies(List<Map<String, String>> vocabs) async =>
      vocabsJson = jsonEncode(vocabs);
}
