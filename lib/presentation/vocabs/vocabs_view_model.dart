import 'package:flutter/foundation.dart';

import '../../domain/entities/vocabulary.dart';
import '../../domain/entities/word_entity.dart';
import '../../domain/exceptions/storage_exceptions.dart';
import '../../domain/usecases/get_all_words.dart';
import '../../domain/usecases/get_vocabularies.dart';
import '../../domain/usecases/manage_vocabularies.dart';
import '../app_scope.dart';

/// State of the collections screens: the collections and the dictionary
/// words they refer to.
///
/// Changes are applied optimistically; if saving fails they are rolled back
/// and the [StorageException] is rethrown for the UI to report.
class VocabsViewModel extends ChangeNotifier {
  VocabsViewModel(AppUseCases useCases)
    : _getVocabularies = useCases.getVocabularies,
      _getAllWords = useCases.getAllWords,
      _create = useCases.createVocabulary,
      _update = useCases.updateVocabulary,
      _delete = useCases.deleteVocabulary,
      _restore = useCases.restoreVocabulary,
      _setWord = useCases.setWordInVocabulary;

  final GetVocabularies _getVocabularies;
  final GetAllWords _getAllWords;
  final CreateVocabulary _create;
  final UpdateVocabulary _update;
  final DeleteVocabulary _delete;
  final RestoreVocabulary _restore;
  final SetWordInVocabulary _setWord;

  List<Vocabulary> vocabularies = [];

  /// Every dictionary word, in the dictionary's manual order.
  List<WordEntity> words = [];
  Map<String, WordEntity> _wordsById = {};

  bool loaded = false;

  /// Set when collections or words could not be read. Editing is then
  /// disabled so nothing replaces the stored data.
  StorageException? loadError;

  bool _disposed = false;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// (Re)reads collections and words. Called when the screen becomes
  /// visible, so changes made in the dictionary show up.
  Future<void> load() async {
    try {
      final loadedVocabularies = await _getVocabularies();
      final loadedWords = await _getAllWords();
      vocabularies = List.of(loadedVocabularies);
      words = List.of(loadedWords);
      _wordsById = {for (final w in words) w.id: w};
      loadError = null;
    } on StorageException catch (e) {
      loadError = e;
    }
    loaded = true;
    _notify();
  }

  Vocabulary? byId(String id) {
    for (final v in vocabularies) {
      if (v.id == id) return v;
    }
    return null;
  }

  /// Members of [vocabulary] that still exist, in the order they were added.
  /// Ids of deleted words are skipped (and come back if the word is
  /// restored).
  List<WordEntity> wordsOf(Vocabulary vocabulary) => [
    for (final id in vocabulary.wordIds)
      if (_wordsById[id] case final word?) word,
  ];

  Future<Vocabulary> create({
    required String name,
    required String description,
    required String iconPath,
  }) async {
    final created = await _create(
      name: name,
      description: description,
      iconPath: iconPath,
    );
    vocabularies.add(created);
    _notify();
    return created;
  }

  Future<void> updateDetails(Vocabulary updated) async {
    final i = vocabularies.indexWhere((v) => v.id == updated.id);
    if (i < 0) return;
    final previous = vocabularies[i];
    vocabularies[i] = updated.copyWith(wordIds: previous.wordIds);
    _notify();
    try {
      await _update(updated);
    } on StorageException {
      final j = vocabularies.indexWhere((v) => v.id == updated.id);
      if (j >= 0) vocabularies[j] = previous;
      _notify();
      rethrow;
    }
  }

  /// Deletes a collection; returns what Undo needs.
  Future<({Vocabulary vocabulary, int index})?> delete(String id) async {
    final index = vocabularies.indexWhere((v) => v.id == id);
    if (index < 0) return null;
    final removed = vocabularies.removeAt(index);
    _notify();
    try {
      await _delete(id);
    } on StorageException {
      vocabularies.insert(index.clamp(0, vocabularies.length), removed);
      _notify();
      rethrow;
    }
    return (vocabulary: removed, index: index);
  }

  /// Undo for [delete]: the collection comes back with all its links.
  Future<void> restore(Vocabulary vocabulary, int index) async {
    if (byId(vocabulary.id) != null) return;
    final at = index.clamp(0, vocabularies.length);
    vocabularies.insert(at, vocabulary);
    _notify();
    try {
      await _restore(vocabulary, index: at);
    } on StorageException {
      vocabularies.removeWhere((v) => identical(v, vocabulary));
      _notify();
      rethrow;
    }
  }

  Future<void> setMembership(
    String vocabularyId,
    String wordId, {
    required bool member,
  }) async {
    final i = vocabularies.indexWhere((v) => v.id == vocabularyId);
    if (i < 0) return;
    final previous = vocabularies[i];
    if (previous.contains(wordId) == member) return;
    final updated = previous.copyWith(
      wordIds: member
          ? [...previous.wordIds, wordId]
          : previous.wordIds.where((id) => id != wordId).toList(),
    );
    vocabularies[i] = updated;
    _notify();
    try {
      await _setWord(
        vocabularyId: vocabularyId,
        wordId: wordId,
        member: member,
      );
    } on StorageException {
      final j = vocabularies.indexWhere((v) => v.id == vocabularyId);
      if (j >= 0 && identical(vocabularies[j], updated)) {
        vocabularies[j] = previous; // nothing else changed: exact rollback
      } else if (j >= 0) {
        final current = vocabularies[j];
        vocabularies[j] = current.copyWith(
          wordIds: member
              ? current.wordIds.where((id) => id != wordId).toList()
              : [...current.wordIds, wordId],
        );
      }
      _notify();
      rethrow;
    }
  }

  /// Adds several words; stops at the first failure and rethrows it.
  Future<void> addWords(String vocabularyId, Iterable<String> wordIds) async {
    for (final id in wordIds) {
      await setMembership(vocabularyId, id, member: true);
    }
  }
}
