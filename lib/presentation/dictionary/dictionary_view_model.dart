import 'package:flutter/foundation.dart';

import '../../core/di/service_locator.dart';
import '../../domain/entities/word_entity.dart';
import '../../domain/exceptions/word_exceptions.dart';
import '../../domain/usecases/add_word.dart';
import '../../domain/usecases/get_all_words.dart';
import '../../domain/usecases/remove_word.dart';
import '../../domain/usecases/restore_word.dart';
import '../../domain/usecases/update_word.dart';
import '../../services/gpt_service.dart';
import '../../services/translate_service.dart';

class DictionaryViewModel extends ChangeNotifier {
  final GetAllWords _getAll;
  final AddWord _addWord;
  final UpdateWord _updateWord;
  final RestoreWord _restoreWord;
  final RemoveWord _removeWord;
  final GptService _gpt;
  final TranslateService _translate;

  DictionaryViewModel()
    : _getAll = sl(),
      _addWord = sl(),
      _updateWord = sl(),
      _restoreWord = sl(),
      _removeWord = sl(),
      _gpt = sl(),
      _translate = sl();

  List<WordEntity> words = [];
  List<WordEntity> filtered = [];
  String query = '';
  final Set<String> removing = {};
  bool selectionMode = false;
  final Set<String> selected = {};
  SortMode currentSort = SortMode.alphaAsc;

  Future<void> load({List<WordEntity> seed = const []}) async {
    final list = await _getAll();
    if (list.isEmpty && seed.isNotEmpty) {
      // Seed defaults with their own ids and dates.
      for (final w in seed) {
        await _restoreWord(w);
      }
      words = List.of(seed);
    } else {
      words = List.of(list);
    }
    _applyFilter();
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    final item = filtered.removeAt(oldIndex);
    filtered.insert(newIndex, item);
    words = List<WordEntity>.from(filtered);
    notifyListeners();
  }

  void toggleSelectionMode(bool enabled) {
    selectionMode = enabled;
    if (!enabled) selected.clear();
    notifyListeners();
  }

  void toggleSelect(String id) {
    if (!selectionMode) return;
    if (selected.contains(id)) {
      selected.remove(id);
    } else {
      selected.add(id);
    }
    notifyListeners();
  }

  void clearSelection() {
    selected.clear();
    notifyListeners();
  }

  int get selectedCount => selected.length;

  bool get areAllSelected =>
      selected.length == filtered.length && filtered.isNotEmpty;

  void selectAll() {
    selected
      ..clear()
      ..addAll(filtered.map((e) => e.id));
    notifyListeners();
  }

  Future<void> deleteSelected() async {
    if (selected.isEmpty) return;
    // Copy to avoid mutation during iteration
    final ids = List<String>.from(selected);
    for (final id in ids) {
      await deleteById(id);
    }
    selected.clear();
    notifyListeners();
  }

  void setSort(SortMode mode) {
    currentSort = mode;
    int cmpAlpha(WordEntity a, WordEntity b) {
      final na = _normalizeEng(a.source);
      final nb = _normalizeEng(b.source);
      return na.compareTo(nb);
    }

    switch (mode) {
      case SortMode.alphaAsc:
        words.sort(cmpAlpha);
        break;
      case SortMode.alphaDesc:
        words.sort((a, b) => -cmpAlpha(a, b));
        break;
      case SortMode.dateAdded:
        words.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
    }
    _applyFilter();
    notifyListeners();
  }

  void onQueryChanged(String q) {
    query = q.trim().toLowerCase();
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (query.isEmpty) {
      filtered = List.from(words);
    } else {
      filtered = words
          .where(
            (w) =>
                w.source.toLowerCase().contains(query) ||
                w.target.toLowerCase().contains(query),
          )
          .toList();
    }
  }

  String _normalizeEng(String s) {
    String out = s.trim().toLowerCase();
    const Map<String, String> repl = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'ā': 'a',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ē': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ī': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'ō': 'o',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ū': 'u',
      'ý': 'y',
      'ÿ': 'y',
      'æ': 'ae',
      'œ': 'oe',
    };
    final buffer = StringBuffer();
    for (final ch in out.split('')) {
      buffer.write(repl[ch] ?? ch);
    }
    out = buffer.toString();
    // Replace any non a-z0-9 with spaces, then collapse spaces.
    out = out.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    return out;
  }

  String _normalizeRus(String s) {
    var out = s.trim().toLowerCase();
    // Collapse non-letters/digits to single spaces to avoid minor punctuation differences
    out = out.replaceAll(RegExp(r'[^\p{L}0-9]+', unicode: true), ' ').trim();
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    return out;
  }

  bool _existsInCurrentVocab(String eng, String rus, {String? exceptId}) {
    final nEng = _normalizeEng(eng);
    final nRus = _normalizeRus(rus);
    return words.any((w) {
      if (w.id == (exceptId ?? '')) return false;
      // Block if same English already exists in this vocabulary (primary key)
      if (_normalizeEng(w.source) == nEng) return true;
      // Optionally also block if exact same pair already exists
      if (_normalizeEng(w.source) == nEng && _normalizeRus(w.target) == nRus) {
        return true;
      }
      return false;
    });
  }

  Future<String?> _tryExplainShort(String eng) async {
    try {
      return (await _gpt.explainWordShort(eng)).replaceAll('*', '');
    } catch (_) {
      return null;
    }
  }

  /// Replaces the in-memory copy of [word] and persists it.
  Future<void> _save(WordEntity word) async {
    final i = words.indexWhere((w) => w.id == word.id);
    if (i < 0) return;
    words[i] = word;
    _applyFilter();
    notifyListeners();
    await _updateWord(word);
  }

  Future<bool> addWord({required String eng, required String rus}) async {
    if (_existsInCurrentVocab(eng, rus)) {
      return false;
    }
    final desc = await _tryExplainShort(eng);
    final word = await _addWord(
      AddWordParams(source: eng, target: rus, shortExplanation: desc),
    );
    words.add(word);
    _applyFilter();
    notifyListeners();
    return true;
  }

  Future<bool> editWord(
    int index, {
    required String eng,
    required String rus,
  }) async {
    final original = words[index];
    if (_existsInCurrentVocab(eng, rus, exceptId: original.id)) {
      return false;
    }
    var updated = original.copyWith(source: eng, target: rus);
    // Explanations describe the English word. When it changes they are stale:
    // drop both and try to generate a fresh short one. A translation-only
    // edit keeps them.
    if (_normalizeEng(eng) != _normalizeEng(original.source)) {
      updated = updated.copyWith(
        shortExplanation: await _tryExplainShort(eng),
        longExplanation: null,
      );
    }
    await _save(updated);
    return true;
  }

  Future<void> deleteById(String id) async {
    final idx = words.indexWhere((w) => w.id == id);
    if (idx < 0) return;
    removing.add(id);
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 200));
    removing.remove(id);
    words.removeWhere((w) => w.id == id);
    _applyFilter();
    notifyListeners();
    await _removeWord(id);
  }

  /// Puts a deleted word back with all of its fields (Undo).
  Future<void> restoreWord(WordEntity w) async {
    if (words.any((e) => e.id == w.id)) return;
    words.add(w);
    _applyFilter();
    notifyListeners();
    try {
      await _restoreWord(w);
    } on WordAlreadyExistsException {
      // Already stored (e.g. the delete never reached storage); nothing to do.
    }
  }

  Future<void> restoreWords(List<WordEntity> list) async {
    for (final w in list) {
      await restoreWord(w);
    }
  }

  Future<String> translateToRu(String eng) async {
    return _translate.translateToRu(eng);
  }

  Future<String> regenerateDescription(int index) async {
    final word = words[index];
    final text = (await _gpt.explainWordShort(word.source)).replaceAll('*', '');
    await _save(word.copyWith(shortExplanation: text));
    return text;
  }

  Future<String> generateOrRegenerateLong(int index) async {
    final word = words[index];
    final text = (await _gpt.explainWordLong(word.source)).replaceAll('*', '');
    await _save(word.copyWith(longExplanation: text));
    return text;
  }
}

enum SortMode { alphaAsc, alphaDesc, dateAdded }
