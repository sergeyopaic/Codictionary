import 'dart:html' as html;
import 'dart:convert';

import '../../models/word.dart';
import 'storage_interface.dart';

class WebStorageService implements StorageService {
  static const _key = 'codictionary_dictionary';

  @override
  Future<List<Word>> loadWords() async {
    try {
      final raw = html.window.localStorage[_key];
      if (raw == null || raw.trim().isEmpty) return [];
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      return list.map(Word.fromMap).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> saveWords(List<Word> words) async {
    try {
      final jsonList = words.map((w) => w.toMap()).toList();
      html.window.localStorage[_key] = jsonEncode(jsonList);
    } catch (_) {
      // Ignore to avoid breaking UX.
    }
  }
}

StorageService createStorageService() => WebStorageService();
