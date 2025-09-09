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

  Future<void> addWord({required String eng, required String rus}) async {
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
  }

  Future<void> editWord(int index, {required String eng, required String rus}) async {
    final original = words[index];
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
