import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../../models/word.dart';
import 'storage_interface.dart';

class FileStorageService implements StorageService {
  Future<File> _getDictFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/dictionary.json');
  }

  @override
  Future<List<Word>> loadWords() async {
    try {
      final file = await _getDictFile();
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return [];
      final decoded = (jsonDecode(raw) as List);
      final list = decoded.cast<Map<String, dynamic>>();
      final needsSave = decoded.any(
        (e) =>
            e is Map &&
            (e['addedAt'] == null ||
                (e['addedAt'] as String?)?.isEmpty == true),
      );
      final words = list.map(Word.fromMap).toList();
      if (needsSave) {
        // Backfill timestamps for pre-existing entries
        await saveWords(words);
      }
      return words;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveWords(List<Word> words) async {
    try {
      final file = await _getDictFile();
      final jsonList = words.map((w) => w.toMap()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (_) {
      // Ignore on failure to avoid crashing.
    }
  }
}

StorageService createStorageService() => FileStorageService();
