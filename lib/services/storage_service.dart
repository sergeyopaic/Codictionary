import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/word.dart';

class StorageService {
  Future<File> _getDictFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/dictionary.json');
  }

  Future<List<Word>> loadWords() async {
    final file = await _getDictFile();
    if (!await file.exists()) return [];
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return [];
    final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    return list.map(Word.fromMap).toList();
  }

  Future<void> saveWords(List<Word> words) async {
    final file = await _getDictFile();
    final jsonList = words.map((w) => w.toMap()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }
}
