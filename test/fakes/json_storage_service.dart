import 'dart:convert';

import 'package:codictionary/domain/exceptions/storage_exceptions.dart';
import 'package:codictionary/data/models/vocabulary_record.dart';
import 'package:codictionary/data/models/word_record.dart';
import 'package:codictionary/data/storage/storage_service.dart';

/// In-memory storage that keeps data as a JSON string, exactly like the file
/// and localStorage implementations. Going through [WordRecord.toMap] /
/// [WordRecord.fromMap] on every call exercises the real persistence mapping.
class JsonStorageService implements StorageService {
  JsonStorageService({
    List<Map<String, dynamic>>? rawWords,
    List<Map<String, dynamic>>? rawVocabularies,
  }) : wordsJson = jsonEncode(rawWords ?? const []),
       vocabsJson = jsonEncode(rawVocabularies ?? const []);

  String wordsJson;
  String vocabsJson;

  List<Map<String, dynamic>> get rawVocabularies =>
      (jsonDecode(vocabsJson) as List).cast<Map<String, dynamic>>();

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

  Map<String, String> settings = {};

  @override
  Future<Map<String, String>> loadSettings() async => Map.of(settings);

  @override
  Future<void> saveSettings(Map<String, String> values) async =>
      settings = Map.of(values);

  @override
  Future<List<VocabularyRecord>> loadVocabularies() async => [
    for (final e in jsonDecode(vocabsJson) as List)
      VocabularyRecord.fromMap(e as Map),
  ];

  @override
  Future<void> saveVocabularies(List<VocabularyRecord> vocabs) async =>
      vocabsJson = jsonEncode([for (final v in vocabs) v.toMap()]);
}
