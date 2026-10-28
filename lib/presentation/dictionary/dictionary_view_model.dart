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

  /// Normalized English words whose add is in flight (awaiting AI/storage).
  final Set<String> _pendingAdds = {};

  /// Latest AI request per word id. A response is applied only if it belongs
  /// to the latest request, so an older, slower response cannot overwrite a
  /// newer one.
  final Map<String, int> _shortRequests = {};
  final Map<String, int> _longRequests = {};
  int _requestCounter = 0;

  bool _disposed = false;

  /// Safe after [dispose]: pending operations still persist, but stop
  /// notifying a widget tree that is gone.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  WordEntity? wordById(String id) {
    for (final w in words) {
      if (w.id == id) return w;
    }
    return null;
  }

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
    _notify();
  }

  void reorder(int oldIndex, int newIndex) {
    final item = filtered.removeAt(oldIndex);
    filtered.insert(newIndex, item);
    words = List<WordEntity>.from(filtered);
    _notify();
  }

  void toggleSelectionMode(bool enabled) {
    selectionMode = enabled;
    if (!enabled) selected.clear();
    _notify();
  }

  void toggleSelect(String id) {
    if (!selectionMode) return;
    if (selected.contains(id)) {
      selected.remove(id);
    } else {
      selected.add(id);
    }
    _notify();
  }

  void clearSelection() {
    selected.clear();
    _notify();
  }

  int get selectedCount => selected.length;

  bool get areAllSelected =>
      selected.length == filtered.length && filtered.isNotEmpty;

  void selectAll() {
    selected
      ..clear()
      ..addAll(filtered.map((e) => e.id));
    _notify();
  }

  Future<void> deleteSelected() async {
    if (selected.isEmpty) return;
    // Copy to avoid mutation during iteration
    final ids = List<String>.from(selected);
    for (final id in ids) {
      await deleteById(id);
    }
    selected.clear();
    _notify();
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
    _notify();
  }

  void onQueryChanged(String q) {
    query = q.trim().toLowerCase();
    _applyFilter();
    _notify();
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

  /// The English word is the key: the same normalized English may exist only
  /// once, counting words that are still being added.
  bool _existsInCurrentVocab(String eng, {String? exceptId}) {
    final key = _normalizeEng(eng);
    return _pendingAdds.contains(key) || _hasSource(key, exceptId: exceptId);
  }

  bool _hasSource(String key, {String? exceptId}) =>
      words.any((w) => w.id != exceptId && _normalizeEng(w.source) == key);

  int _startRequest(Map<String, int> requests, String id) =>
      requests[id] = ++_requestCounter;

  Future<String?> _tryExplainShort(String eng) async {
    try {
      return (await _gpt.explainWordShort(eng)).replaceAll('*', '');
    } catch (_) {
      return null;
    }
  }

  /// Replaces the in-memory copy of [word] and persists it. A word that was
  /// deleted (or is being deleted) is never brought back.
  Future<void> _save(WordEntity word) async {
    if (removing.contains(word.id)) return;
    final i = words.indexWhere((w) => w.id == word.id);
    if (i < 0) return;
    words[i] = word;
    _applyFilter();
    _notify();
    try {
      await _updateWord(word);
    } on WordNotFoundException {
      // Deleted from storage meanwhile; the delete wins.
    }
  }

  Future<bool> addWord({required String eng, required String rus}) async {
    if (_existsInCurrentVocab(eng)) return false;
    // Reserve the word before the first await so a second add of the same
    // word (double submit) is rejected instead of creating a duplicate.
    final key = _normalizeEng(eng);
    _pendingAdds.add(key);
    try {
      final desc = await _tryExplainShort(eng);
      // Re-check at commit: an Undo may have restored the same word.
      if (_hasSource(key)) return false;
      final word = await _addWord(
        AddWordParams(source: eng, target: rus, shortExplanation: desc),
      );
      words.add(word);
      _applyFilter();
      _notify();
      return true;
    } finally {
      _pendingAdds.remove(key);
    }
  }

  /// Saves the edited English word and translation. Returns false if the word
  /// would duplicate another one or was deleted while the edit was running.
  Future<bool> editWord(
    String id, {
    required String eng,
    required String rus,
  }) async {
    final original = wordById(id);
    if (original == null || _existsInCurrentVocab(eng, exceptId: id)) {
      return false;
    }
    // Explanations describe the English word. When it changes they are stale:
    // drop both and try to generate a fresh short one. A translation-only
    // edit keeps them.
    final sourceChanged = _normalizeEng(eng) != _normalizeEng(original.source);
    String? newShort;
    int? shortRequest;
    if (sourceChanged) {
      shortRequest = _startRequest(_shortRequests, id);
      _startRequest(_longRequests, id); // cancels an in-flight long request
      newShort = await _tryExplainShort(eng);
    }

    // Apply to the current version of the word, not the one we started with.
    final current = wordById(id);
    if (current == null || removing.contains(id)) return false;
    if (_hasSource(_normalizeEng(eng), exceptId: id)) return false;
    var updated = current.copyWith(source: eng, target: rus);
    if (sourceChanged) {
      updated = updated.copyWith(
        // If a newer request for this word started meanwhile, it will fill
        // the explanation in; ours is outdated.
        shortExplanation: _shortRequests[id] == shortRequest ? newShort : null,
        longExplanation: null,
      );
    }
    await _save(updated);
    return true;
  }

  Future<void> deleteById(String id) async {
    // Idempotent: a second delete of the same id (double tap, bulk delete
    // racing a single delete) does nothing.
    if (removing.contains(id) || wordById(id) == null) return;
    removing.add(id);
    _notify();
    await Future.delayed(const Duration(milliseconds: 200));
    removing.remove(id);
    words.removeWhere((w) => w.id == id);
    selected.remove(id);
    _applyFilter();
    _notify();
    await _removeWord(id);
  }

  /// Puts a deleted word back with all of its fields (Undo).
  Future<void> restoreWord(WordEntity w) async {
    if (wordById(w.id) != null) return;
    words.add(w);
    _applyFilter();
    _notify();
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

  /// Generates a new short explanation. Returns null if the result was
  /// discarded because the word changed, was deleted or a newer request
  /// started. Provider errors are rethrown for the UI to show.
  Future<String?> regenerateShortExplanation(String id) async {
    final word = wordById(id);
    if (word == null) return null;
    final request = _startRequest(_shortRequests, id);
    final text = (await _gpt.explainWordShort(word.source)).replaceAll('*', '');
    final applied = await _applyGenerated(
      id,
      requested: word.source,
      isLatest: () => _shortRequests[id] == request,
      apply: (w) => w.copyWith(shortExplanation: text),
    );
    return applied ? text : null;
  }

  /// Same as [regenerateShortExplanation] for the detailed explanation.
  Future<String?> generateLongExplanation(String id) async {
    final word = wordById(id);
    if (word == null) return null;
    final request = _startRequest(_longRequests, id);
    final text = (await _gpt.explainWordLong(word.source)).replaceAll('*', '');
    final applied = await _applyGenerated(
      id,
      requested: word.source,
      isLatest: () => _longRequests[id] == request,
      apply: (w) => w.copyWith(longExplanation: text),
    );
    return applied ? text : null;
  }

  Future<bool> _applyGenerated(
    String id, {
    required String requested,
    required bool Function() isLatest,
    required WordEntity Function(WordEntity current) apply,
  }) async {
    final current = wordById(id);
    if (current == null || removing.contains(id) || !isLatest()) return false;
    // The text explains [requested]; don't attach it to a renamed word.
    // editWord already invalidates requests when the English word changes,
    // so this is a backstop for any future path that renames a word.
    if (_normalizeEng(current.source) != _normalizeEng(requested)) {
      return false;
    }
    await _save(apply(current));
    return true;
  }
}

enum SortMode { alphaAsc, alphaDesc, dateAdded }
