// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
// ignore: undefined_identifier
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
        // Persist backfilled timestamps
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
      final jsonList = words.map((w) => w.toMap()).toList();
      html.window.localStorage[_key] = jsonEncode(jsonList);
    } catch (_) {
      // Ignore to avoid breaking UX.
    }
  }
}

StorageService createStorageService() => WebStorageService();
