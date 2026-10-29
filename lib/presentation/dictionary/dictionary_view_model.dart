import 'package:flutter/foundation.dart';

import '../../domain/entities/word_entity.dart';
import '../../domain/exceptions/storage_exceptions.dart';
import '../../domain/exceptions/word_exceptions.dart';
import '../../domain/usecases/add_word.dart';
import '../../domain/usecases/explain_word.dart';
import '../../domain/usecases/get_all_words.dart';
import '../../domain/usecases/recover_words.dart';
import '../../domain/usecases/remove_word.dart';
import '../../domain/usecases/reorder_words.dart';
import '../../domain/usecases/restore_word.dart';
import '../../domain/usecases/translate_word.dart';
import '../../domain/usecases/update_word.dart';
import '../app_scope.dart';
import 'example_words.dart';

/// Dictionary screen state. Depends only on domain use cases, passed in by
/// the caller (see [AppScope]); no global service locator.
class DictionaryViewModel extends ChangeNotifier {
  final GetAllWords _getAll;
  final AddWord _addWord;
  final UpdateWord _updateWord;
  final RestoreWord _restoreWord;
  final RemoveWord _removeWord;
  final RecoverWords _recoverWords;
  final ReorderWords _reorderWords;
  final ExplainWord _explain;
  final TranslateWord _translate;

  DictionaryViewModel(AppUseCases useCases)
    : _getAll = useCases.getAllWords,
      _addWord = useCases.addWord,
      _updateWord = useCases.updateWord,
      _restoreWord = useCases.restoreWord,
      _removeWord = useCases.removeWord,
      _recoverWords = useCases.recoverWords,
      _reorderWords = useCases.reorderWords,
      _explain = useCases.explainWord,
      _translate = useCases.translateWord;

  /// All words in the user's manual order, as stored. Sorting and search
  /// never change this list; only [reorder] does.
  List<WordEntity> words = [];

  /// What the grid shows: [words] filtered by [query] and sorted by
  /// [sortMode].
  List<WordEntity> filtered = [];
  String query = '';
  final Set<String> removing = {};
  bool selectionMode = false;
  final Set<String> selected = {};

  /// Temporary sort for display; null shows the manual order.
  SortMode? sortMode;

  /// Where deleted words were in the manual order, so Undo puts them back
  /// in place. `seq` orders deletions for multi-word Undo.
  final Map<String, ({int index, int seq})> _deletedAt = {};
  int _deleteSeq = 0;

  /// Set when stored words could not be loaded. While set, the dictionary
  /// is not usable and nothing is written, so damaged data stays as is.
  StorageException? loadError;

  /// Normalized English words whose add is in flight (awaiting AI/storage).
  final Set<String> _pendingAdds = {};

  /// Latest AI request per word id. A response is applied only if it belongs
  /// to the latest request, so an older, slower response cannot overwrite a
  /// newer one.
  final Map<ExplanationKind, Map<String, int>> _requests = {
    for (final k in ExplanationKind.values) k: {},
  };
  int _requestCounter = 0;

  /// Generations in progress (id -> request) and the last failure per word.
  final Map<ExplanationKind, Map<String, int>> _running = {
    for (final k in ExplanationKind.values) k: {},
  };
  final Map<ExplanationKind, Map<String, Object>> _failures = {
    for (final k in ExplanationKind.values) k: {},
  };

  /// Background work started by this view model, for [whenIdle].
  final Set<Future<void>> _inFlight = {};

  /// False in local mode: no API key, so no explanations are requested.
  bool get aiAvailable => _explain.isAvailable;

  /// False in local mode: translations are typed by the user.
  bool get translationAvailable => _translate.isAvailable;

  bool isGenerating(String id, ExplanationKind kind) =>
      _running[kind]!.containsKey(id);

  /// Why the last generation for this word failed (a [ServiceException] or
  /// [StorageException]); null if it did not fail or was retried.
  Object? generationError(String id, ExplanationKind kind) =>
      _failures[kind]![id];

  /// Completes when all background generations have finished.
  Future<void> whenIdle() async {
    while (_inFlight.isNotEmpty) {
      await Future.wait(List.of(_inFlight));
    }
  }

  Future<T> _track<T>(Future<T> work) {
    final done = work.then<void>((_) {}, onError: (_) {});
    _inFlight.add(done);
    done.whenComplete(() => _inFlight.remove(done));
    return work;
  }

  /// Marks every in-flight generation for [id] as outdated.
  void _invalidateGenerations(String id) {
    for (final kind in ExplanationKind.values) {
      _startRequest(_requests[kind]!, id);
      _running[kind]!.remove(id);
      _failures[kind]!.remove(id);
    }
  }

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

  /// Loads the stored words. Never adds anything: an empty dictionary (first
  /// run or after deleting every word) stays empty. Example words are only
  /// added by [addExampleWords].
  Future<void> load() async {
    try {
      words = List.of(await _getAll());
      loadError = null;
    } on StorageException catch (e) {
      words = [];
      loadError = e;
    }
    _applyFilter();
    _notify();
  }

  /// Applies a recovery action to damaged storage and reloads. Throws a
  /// [StorageException] if recovery itself fails.
  Future<void> recover(StorageRecovery action) async {
    await _recoverWords(action);
    await load();
  }

  /// Drag and drop is only meaningful on the full list in manual order:
  /// while searching or sorted, the shown list is not the manual order.
  bool get canReorder =>
      sortMode == null && query.isEmpty && !selectionMode && loadError == null;

  /// Why dragging is not available right now, for a hint in the UI.
  ReorderBlock? get reorderBlockedReason {
    if (query.isNotEmpty) return ReorderBlock.search;
    if (sortMode != null) return ReorderBlock.sort;
    return null;
  }

  /// Moves a word in the manual order and saves it. Ignored when
  /// [canReorder] is false. On a storage failure the move is undone and the
  /// [StorageException] rethrown.
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (!canReorder) return;
    if (oldIndex < 0 || oldIndex >= words.length) return;
    final previous = List.of(words);
    final item = words.removeAt(oldIndex);
    words.insert(newIndex.clamp(0, words.length), item);
    _applyFilter();
    _notify();
    try {
      await _reorderWords([for (final w in words) w.id]);
    } on StorageException {
      words = previous;
      _applyFilter();
      _notify();
      rethrow;
    }
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

  /// Deletes the selected words one by one. Stops at the first storage
  /// failure and rethrows it; words not yet deleted stay selected.
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

  /// Changes how the grid is sorted; null returns to the manual order.
  /// The manual order itself is not touched.
  void setSort(SortMode? mode) {
    sortMode = mode;
    _applyFilter();
    _notify();
  }

  void onQueryChanged(String q) {
    query = q.trim().toLowerCase();
    _applyFilter();
    _notify();
  }

  /// Rebuilds [filtered]. Runs after every change, so added, edited and
  /// restored words always appear where the current sort puts them.
  void _applyFilter() {
    final matching = query.isEmpty
        ? List.of(words)
        : words
              .where(
                (w) =>
                    w.source.toLowerCase().contains(query) ||
                    w.target.toLowerCase().contains(query),
              )
              .toList();
    final mode = sortMode;
    filtered = mode == null ? matching : _sorted(matching, mode);
  }

  /// Stable sort: equal keys keep their manual order.
  List<WordEntity> _sorted(List<WordEntity> list, SortMode mode) {
    int compare(WordEntity a, WordEntity b) => switch (mode) {
      SortMode.alphaAsc => _normalizeEng(
        a.source,
      ).compareTo(_normalizeEng(b.source)),
      SortMode.alphaDesc => _normalizeEng(
        b.source,
      ).compareTo(_normalizeEng(a.source)),
      SortMode.dateAdded => b.createdAt.compareTo(a.createdAt),
    };
    final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
    indexed.sort((x, y) {
      final c = compare(x.$2, y.$2);
      return c != 0 ? c : x.$1.compareTo(y.$1);
    });
    return [for (final e in indexed) e.$2];
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

  /// Replaces the in-memory copy of [word] and persists it. A word that was
  /// deleted (or is being deleted) is never brought back. If storage fails
  /// the change is rolled back and the [StorageException] rethrown.
  Future<void> _save(WordEntity word) async {
    if (removing.contains(word.id)) return;
    final i = words.indexWhere((w) => w.id == word.id);
    if (i < 0) return;
    final previous = words[i];
    words[i] = word;
    _applyFilter();
    _notify();
    try {
      await _updateWord(word);
    } on WordNotFoundException {
      // Deleted from storage meanwhile; the delete wins.
    } on StorageException {
      // Undo only our own change; a later change to the word stays.
      final j = words.indexWhere((w) => identical(w, word));
      if (j >= 0) words[j] = previous;
      _applyFilter();
      _notify();
      rethrow;
    }
  }

  Future<bool> addWord({required String eng, required String rus}) async {
    if (_existsInCurrentVocab(eng)) return false;
    // Reserve the word before the first await so a second add of the same
    // word (double submit) is rejected instead of creating a duplicate.
    final key = _normalizeEng(eng);
    _pendingAdds.add(key);
    try {
      // Save right away; the explanation follows in the background, so an
      // unavailable AI service never blocks or loses the word.
      final word = await _addWord(AddWordParams(source: eng, target: rus));
      words.add(word);
      _applyFilter();
      _notify();
      if (aiAvailable) _track(_generate(word.id, ExplanationKind.short));
      return true;
    } finally {
      _pendingAdds.remove(key);
    }
  }

  /// Adds the built-in example words the user asked for, skipping any that
  /// are already in the dictionary. They come with explanations, so no AI
  /// request is made. Returns how many were added. Throws a
  /// [StorageException] if saving fails; words saved before that stay.
  Future<int> addExampleWords() async {
    var added = 0;
    for (final example in exampleWords) {
      if (_existsInCurrentVocab(example.source)) continue;
      final word = await _addWord(
        AddWordParams(
          source: example.source,
          target: example.target,
          shortExplanation: example.explanation,
        ),
      );
      words.add(word);
      added++;
      _applyFilter();
      _notify();
    }
    return added;
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
    if (removing.contains(id)) return false;
    // Explanations describe the English word. When it changes they are stale:
    // drop both, cancel generations for the old word, save, then generate a
    // fresh short one in the background. A translation-only edit keeps them.
    final sourceChanged = _normalizeEng(eng) != _normalizeEng(original.source);
    var updated = original.copyWith(source: eng, target: rus);
    if (sourceChanged) {
      updated = updated.copyWith(shortExplanation: null, longExplanation: null);
      _invalidateGenerations(id);
    }
    await _save(updated);
    if (sourceChanged && aiAvailable) {
      _track(_generate(id, ExplanationKind.short));
    }
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
    final index = words.indexWhere((w) => w.id == id);
    if (index < 0) return;
    final removed = words.removeAt(index);
    final wasSelected = selected.remove(id);
    _invalidateGenerations(id);
    _deletedAt[id] = (index: index, seq: ++_deleteSeq);
    _applyFilter();
    _notify();
    try {
      await _removeWord(id);
    } on StorageException {
      // Still stored: show it again where it was.
      _deletedAt.remove(id);
      words.insert(index.clamp(0, words.length), removed);
      if (wasSelected) selected.add(id);
      _applyFilter();
      _notify();
      rethrow;
    }
  }

  /// Puts a deleted word back with all of its fields (Undo), at its old
  /// place in the manual order. Words never deleted here go to the end.
  Future<void> restoreWord(WordEntity w) async {
    if (wordById(w.id) != null) return;
    final position = _deletedAt.remove(w.id);
    final index = (position?.index ?? words.length).clamp(0, words.length);
    words.insert(index, w);
    _applyFilter();
    _notify();
    try {
      await _restoreWord(w, index: index);
    } on WordAlreadyExistsException {
      // Already stored (e.g. the delete never reached storage); nothing to do.
    } on StorageException {
      words.removeWhere((e) => identical(e, w));
      if (position != null) _deletedAt[w.id] = position;
      _applyFilter();
      _notify();
      rethrow;
    }
  }

  /// Undo for several deleted words. Restoring the last deleted first
  /// rebuilds the exact previous order.
  Future<void> restoreWords(List<WordEntity> list) async {
    int seq(WordEntity w) => _deletedAt[w.id]?.seq ?? 0;
    final ordered = List.of(list)..sort((a, b) => seq(b).compareTo(seq(a)));
    for (final w in ordered) {
      await restoreWord(w);
    }
  }

  Future<String> translateToRu(String eng) async {
    return _translate(eng);
  }

  /// Generates a new short explanation. Returns the text, or null if it
  /// failed (see [generationError]) or was discarded because the word
  /// changed, was deleted or a newer request started. Never throws.
  Future<String?> regenerateShortExplanation(String id) =>
      _track(_generate(id, ExplanationKind.short));

  /// Same as [regenerateShortExplanation] for the detailed explanation.
  Future<String?> generateLongExplanation(String id) =>
      _track(_generate(id, ExplanationKind.long));

  Future<String?> _generate(String id, ExplanationKind kind) async {
    final word = wordById(id);
    if (word == null) return null;
    final requests = _requests[kind]!;
    final running = _running[kind]!;
    final request = _startRequest(requests, id);
    bool isLatest() => requests[id] == request;
    running[id] = request;
    _failures[kind]!.remove(id);
    _notify();
    final requested = word.source;
    try {
      final raw = kind == ExplanationKind.short
          ? await _explain.short(requested)
          : await _explain.long(requested);
      final text = raw.replaceAll('*', '');
      final applied = await _applyGenerated(
        id,
        requested: requested,
        isLatest: isLatest,
        apply: (w) => kind == ExplanationKind.short
            ? w.copyWith(shortExplanation: text)
            : w.copyWith(longExplanation: text),
      );
      return applied ? text : null;
    } catch (e) {
      // Only the latest request for an existing word reports its failure.
      if (isLatest() && wordById(id) != null) _failures[kind]![id] = e;
      return null;
    } finally {
      if (running[id] == request) running.remove(id);
      _notify();
    }
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

/// Why the manual order cannot be changed right now.
enum ReorderBlock { search, sort }

enum ExplanationKind { short, long }
