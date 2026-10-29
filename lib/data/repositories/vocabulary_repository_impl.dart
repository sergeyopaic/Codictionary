import 'package:uuid/uuid.dart';

import '../../domain/entities/vocabulary.dart';
import '../../domain/exceptions/storage_exceptions.dart';
import '../../domain/repositories/vocabulary_repository.dart';
import '../models/vocabulary_record.dart';
import '../storage/storage_service.dart';

/// Collections stored as [VocabularyRecord]s.
///
/// Like the word repository, every operation is a read–modify–write of the
/// whole list, so operations run strictly one after another.
class VocabularyRepositoryImpl implements VocabularyRepository {
  final StorageService storage;
  VocabularyRepositoryImpl(this.storage);

  static const defaultIcon = 'assets/media/icons/new_dictionary/1.png';

  Future<void> _tail = Future.value();

  Future<T> _serialized<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<List<Vocabulary>> getAll() => _serialized(() async {
    final records = await _loadNormalized();
    return records.map(_toEntity).toList(growable: false);
  });

  @override
  Future<void> create(Vocabulary vocabulary, {int? index}) =>
      _serialized(() async {
        final records = await _loadNormalized();
        if (records.any((r) => r.id == vocabulary.id)) return;
        records.insert(
          (index ?? records.length).clamp(0, records.length),
          _toRecord(vocabulary),
        );
        await storage.saveVocabularies(records);
      });

  @override
  Future<void> updateDetails(Vocabulary vocabulary) => _serialized(() async {
    final records = await _loadNormalized();
    final i = records.indexWhere((r) => r.id == vocabulary.id);
    if (i < 0) return;
    // Keep the stored members: only the details are the caller's.
    records[i] = _toRecord(vocabulary.copyWith(wordIds: records[i].wordIds));
    await storage.saveVocabularies(records);
  });

  @override
  Future<void> remove(String id) => _serialized(() async {
    final records = await _loadNormalized();
    final remaining = records.where((r) => r.id != id).toList();
    if (remaining.length == records.length) return;
    await storage.saveVocabularies(remaining);
  });

  @override
  Future<void> replaceAll(List<Vocabulary> vocabularies) => _serialized(
    () =>
        storage.saveVocabularies([for (final v in vocabularies) _toRecord(v)]),
  );

  @override
  Future<void> setMembership(String vocabularyId, String wordId, bool member) =>
      _serialized(() async {
        final records = await _loadNormalized();
        final i = records.indexWhere((r) => r.id == vocabularyId);
        if (i < 0) return;
        final ids = records[i].wordIds;
        if (ids.contains(wordId) == member) return;
        final updated = member
            ? [...ids, wordId]
            : ids.where((id) => id != wordId).toList();
        records[i] = VocabularyRecord(
          id: records[i].id,
          name: records[i].name,
          description: records[i].description,
          icon: records[i].icon,
          wordIds: updated,
        );
        await storage.saveVocabularies(records);
      });

  /// Gives collections from older versions (no id) a stable id and removes
  /// duplicate ids, persisting the repair once. Without ids, two collections
  /// with the same name could not be told apart.
  Future<List<VocabularyRecord>> _loadNormalized() async {
    final records = List.of(await storage.loadVocabularies());
    final seen = <String>{};
    var changed = false;
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      if (r.id.isEmpty || seen.contains(r.id)) {
        records[i] = VocabularyRecord(
          id: const Uuid().v4(),
          name: r.name,
          description: r.description,
          icon: r.icon,
          wordIds: r.wordIds,
        );
        changed = true;
      }
      seen.add(records[i].id);
    }
    if (changed) {
      try {
        await storage.saveVocabularies(records);
      } on StorageWriteException {
        // Reading still works; the next successful write stores the ids.
      }
    }
    return records;
  }

  static Vocabulary _toEntity(VocabularyRecord r) => Vocabulary(
    id: r.id,
    name: r.name.isEmpty ? 'Untitled' : r.name,
    description: r.description,
    iconPath: r.icon.isEmpty ? defaultIcon : r.icon,
    wordIds: List.unmodifiable(r.wordIds),
  );

  static VocabularyRecord _toRecord(Vocabulary v) => VocabularyRecord(
    id: v.id,
    name: v.name,
    description: v.description,
    icon: v.iconPath,
    wordIds: v.wordIds,
  );
}
