import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../core/di/service_locator.dart';
import '../../domain/usecases/add_word.dart';
import '../../domain/usecases/get_all_words.dart';
import '../../domain/usecases/remove_word.dart';
import '../../services/gpt_service.dart';
import '../../services/translate_service.dart';
import '../../models/word.dart' as legacy_model;

class DictionaryViewModel extends ChangeNotifier {
  final GetAllWords _getAll;
  final AddWord _addWord;
  final RemoveWord _removeWord;
  final GptService _gpt;
  final TranslateService _translate;

  DictionaryViewModel()
      : _getAll = sl(),
        _addWord = sl(),
        _removeWord = sl(),
        _gpt = sl(),
        _translate = sl();

  List<legacy_model.Word> words = [];
  List<legacy_model.Word> filtered = [];
  String query = '';
  final Set<String> removing = {};
  bool selectionMode = false;
  final Set<String> selected = {};
  Timer? _debounce;

  Future<void> load({List<legacy_model.Word> seed = const []}) async {
    final list = await _getAll();
    if (list.isEmpty && seed.isNotEmpty) {
      words = List.from(seed);
    } else {
      words = list
          .map((e) => legacy_model.Word(
                id: e.id,
                eng: e.source,
                rus: e.target,
                desc: e.note,
                addedAt: DateTime.now(),
              ))
          .toList();
    }
    _applyFilter();
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    final item = filtered.removeAt(oldIndex);
    filtered.insert(newIndex, item);
    words = List<legacy_model.Word>.from(filtered);
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
          .where((w) =>
              w.eng.toLowerCase().contains(query) ||
              w.rus.toLowerCase().contains(query))
          .toList();
    }
  }

  Future<String> autoTranslate(String eng) async {
    _debounce?.cancel();
    return _translate.translateToRu(eng);
  }

  String _normalizeEng(String s) {
    String out = s.trim().toLowerCase();
    const Map<String, String> repl = {
      'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a', 'ā': 'a',
      'ç': 'c',
      'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e', 'ē': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i', 'ī': 'i',
      'ñ': 'n',
      'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'ō': 'o',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u', 'ū': 'u',
      'ý': 'y', 'ÿ': 'y',
      'æ': 'ae', 'œ': 'oe',
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
      if (_normalizeEng(w.eng) == nEng) return true;
      // Optionally also block if exact same pair already exists
      if (_normalizeEng(w.eng) == nEng && _normalizeRus(w.rus) == nRus) return true;
      return false;
    });
  }

  Future<bool> addWord({required String eng, required String rus}) async {
    if (_existsInCurrentVocab(eng, rus)) {
      return false;
    }
    final id = const Uuid().v4();
    String? desc;
    try {
      desc = await _gpt.explainWord(eng);
    } catch (_) {}
    words.add(legacy_model.Word(
      id: id,
      eng: eng,
      rus: rus,
      desc: desc,
      addedAt: DateTime.now(),
    ));
    _applyFilter();
    notifyListeners();
    await _addWord(AddWordParams(id: id, source: eng, target: rus, note: desc));
    return true;
  }

  Future<bool> editWord(int index, {required String eng, required String rus}) async {
    final original = words[index];
    if (_existsInCurrentVocab(eng, rus, exceptId: original.id)) {
      return false;
    }
    String? desc = original.desc;
    final changed = eng != original.eng || rus != original.rus;
    if (changed) {
      try {
        desc = await _gpt.explainWord(eng);
      } catch (_) {}
    }
    words[index] = original.copyWith(eng: eng, rus: rus, desc: desc);
    _applyFilter();
    notifyListeners();
    // Persist via add use-case by same id (repository replaces/append)
    await _addWord(AddWordParams(id: original.id, source: eng, target: rus, note: desc));
    return true;
  }

  Future<void> deleteById(String id) async {
    final idx = words.indexWhere((w) => w.id == id);
    if (idx < 0) return;
    removing.add(id);
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 200));
    removing.remove(id);
    words.removeAt(idx);
    _applyFilter();
    notifyListeners();
    await _removeWord(id);
  }

  String currentDescription(int index) => words[index].desc ?? 'Waiting for response...';

  Future<String> regenerateDescription(int index) async {
    final eng = words[index].eng;
    final text = await _gpt.explainWord(eng);
    words[index] = words[index].copyWith(desc: text);
    notifyListeners();
    await _addWord(AddWordParams(
      id: words[index].id,
      source: words[index].eng,
      target: words[index].rus,
      note: text,
    ));
    return text;
  }
}
