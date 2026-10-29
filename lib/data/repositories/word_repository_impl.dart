import 'package:uuid/uuid.dart';

import '../../domain/entities/word_entity.dart';
import '../../domain/exceptions/storage_exceptions.dart';
import '../../domain/exceptions/word_exceptions.dart';
import '../../domain/repositories/word_repository.dart';
import '../storage/storage_service.dart' as legacy;
import '../models/word_record.dart' as record;

/// Every operation reads the whole list, changes it and writes it back. Two
/// such cycles running at once would lose one of the changes, so operations
/// run strictly one after another. The app registers a single instance in DI;
/// separate instances over the same storage are not coordinated.
class WordRepositoryImpl implements WordRepository {
  final legacy.StorageService storage;
  WordRepositoryImpl(this.storage);

  Future<void> _tail = Future.value();

  Future<T> _serialized<T>(Future<T> Function() op) {
    final result = _tail.then((_) => op());
    // A failed operation must not block the ones queued after it.
    _tail = result.then<void>((_) {}, onError: (_) {});
    return result;
  }

  @override
  Future<List<WordEntity>> getAll() => _serialized(() async {
    final records = await _loadNormalized();
    return records.map(_toEntity).toList(growable: false);
  });

  @override
  Future<void> create(WordEntity word, {int? index}) => _serialized(() async {
    final records = await _loadNormalized();
    if (records.any((r) => r.id == word.id)) {
      throw WordAlreadyExistsException(word.id);
    }
    records.insert(
      (index ?? records.length).clamp(0, records.length),
      _toRecord(word),
    );
    await storage.saveWords(records);
  });

  @override
  Future<void> reorder(List<String> orderedIds) => _serialized(() async {
    final records = await _loadNormalized();
    final byId = {for (final r in records) r.id: r};
    final listed = <String>{};
    final reordered = [
      for (final id in orderedIds)
        if (byId.containsKey(id) && listed.add(id)) byId[id]!,
      for (final r in records)
        if (!listed.contains(r.id)) r,
    ];
    await storage.saveWords(reordered);
  });

  @override
  Future<void> update(WordEntity word) => _serialized(() async {
    final records = await _loadNormalized();
    final i = records.indexWhere((r) => r.id == word.id);
    if (i < 0) throw WordNotFoundException(word.id);
    // The creation date belongs to the stored record, never to the caller.
    records[i] = _toRecord(word, createdAt: records[i].addedAt);
    await storage.saveWords(records);
  });

  @override
  Future<void> remove(String id) => _serialized(() async {
    final records = await _loadNormalized();
    final remaining = records.where((r) => r.id != id).toList();
    if (remaining.length == records.length) return;
    await storage.saveWords(remaining);
  });

  @override
  Future<void> replaceAll(List<WordEntity> words) => _serialized(
    () => storage.saveWords([for (final w in words) _toRecord(w)]),
  );

  @override
  Future<void> recover(StorageRecovery action) =>
      _serialized(() => storage.recoverWords(action));

  /// Loads stored records and repairs empty or duplicate ids. Without this,
  /// an empty id gets a new random id on every load and duplicates make
  /// updates and removals hit the wrong entry. Repairs are persisted once.
  Future<List<record.WordRecord>> _loadNormalized() async {
    final records = List.of(await storage.loadWords());
    final seen = <String>{};
    var changed = false;
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      if (r.id.isEmpty || seen.contains(r.id)) {
        records[i] = record.WordRecord(
          id: const Uuid().v4(),
          eng: r.eng,
          rus: r.rus,
          desc: r.desc,
          descLong: r.descLong,
          addedAt: r.addedAt,
        );
        changed = true;
      }
      seen.add(records[i].id);
    }
    if (changed) {
      try {
        await storage.saveWords(records);
      } on StorageWriteException {
        // Reading still works; the next successful write stores the ids.
      }
    }
    return records;
  }

  static WordEntity _toEntity(record.WordRecord r) => WordEntity(
    id: r.id,
    source: r.eng,
    target: r.rus,
    shortExplanation: r.desc,
    longExplanation: r.descLong,
    createdAt: r.addedAt,
  );

  static record.WordRecord _toRecord(WordEntity w, {DateTime? createdAt}) =>
      record.WordRecord(
        id: w.id,
        eng: w.source,
        rus: w.target,
        desc: w.shortExplanation,
        descLong: w.longExplanation,
        addedAt: createdAt ?? w.createdAt,
      );
}
