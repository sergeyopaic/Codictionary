import 'dart:convert';

import '../../domain/exceptions/storage_exceptions.dart';
import '../models/vocabulary_record.dart';
import '../models/word_record.dart';
import 'storage_backend.dart';
import 'storage_service.dart';

/// [StorageService] that never loses data silently:
///
/// * a missing document reads as empty; damaged or unreadable data throws
///   instead of being treated as empty (and later overwritten);
/// * every write is atomic and first keeps the previous good version as
///   `<key>.bak`;
/// * recovery keeps the damaged data as `<key>.corrupt-<timestamp>`.
class SafeJsonStorage implements StorageService {
  SafeJsonStorage(
    this.backend, {
    required this.wordsKey,
    required this.vocabsKey,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final StorageBackend backend;
  final String wordsKey;
  final String vocabsKey;
  final DateTime Function() _clock;

  static String backupKey(String key) => '$key.bak';

  // ---------------------------------------------------------------------------
  // Words

  @override
  Future<List<WordRecord>> loadWords() async {
    final raw = await _loadValid(wordsKey, _parseWords);
    if (raw == null) return [];
    final words = _parseWords(raw);
    if (_needsDateBackfill(raw)) {
      // Persist the dates assigned to legacy entries so they stay stable.
      // Best effort: loading succeeded even if this write does not.
      try {
        await saveWords(words);
      } on StorageWriteException {
        // The next successful write stores them.
      }
    }
    return words;
  }

  @override
  Future<void> saveWords(List<WordRecord> words) => _save(
    wordsKey,
    jsonEncode(words.map((w) => w.toMap()).toList()),
    _parseWords,
  );

  @override
  Future<void> recoverWords(StorageRecovery action) =>
      _recover(wordsKey, action, _parseWords);

  static List<WordRecord> _parseWords(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('Expected a list');
    return [
      for (final e in decoded)
        if (e is Map<String, dynamic>)
          WordRecord.fromMap(e)
        else
          throw const FormatException('Expected an object'),
    ];
  }

  static bool _needsDateBackfill(String raw) =>
      (jsonDecode(raw) as List).any((e) {
        final addedAt = (e as Map)['addedAt'];
        return addedAt is! String || addedAt.isEmpty;
      });

  // ---------------------------------------------------------------------------
  // Vocabularies

  @override
  Future<List<VocabularyRecord>> loadVocabularies() async {
    final raw = await _loadValid(vocabsKey, _parseVocabs);
    return raw == null ? [] : _parseVocabs(raw);
  }

  @override
  Future<void> saveVocabularies(List<VocabularyRecord> vocabs) => _save(
    vocabsKey,
    jsonEncode([for (final v in vocabs) v.toMap()]),
    _parseVocabs,
  );

  static List<VocabularyRecord> _parseVocabs(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! List) throw const FormatException('Expected a list');
    return [
      for (final e in decoded)
        if (e is Map)
          VocabularyRecord.fromMap(e)
        else
          throw const FormatException('Expected an object'),
    ];
  }

  // ---------------------------------------------------------------------------
  // Shared document logic

  static bool _isValid(String? raw, Object? Function(String) parse) {
    if (raw == null) return false;
    try {
      parse(raw);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Returns the valid raw document, or null if it was never saved.
  Future<String?> _loadValid(String key, Object? Function(String) parse) async {
    final raw = await backend.read(key);
    if (raw == null) {
      // Our writes never delete the document, so a missing document next to
      // a backup means something went wrong; don't present it as empty.
      if (_isValid(await backend.read(backupKey(key)), parse)) {
        throw StorageCorruptedException(
          'Your saved data is missing, but a backup copy exists.',
          hasBackup: true,
          location: backend.describe(key),
        );
      }
      return null;
    }
    try {
      parse(raw);
      return raw;
    } catch (e) {
      throw StorageCorruptedException(
        'Your saved data is damaged and could not be read.',
        hasBackup: _isValid(await backend.read(backupKey(key)), parse),
        location: backend.describe(key),
        cause: e,
      );
    }
  }

  Future<void> _save(
    String key,
    String json,
    Object? Function(String) parse,
  ) async {
    final String? current;
    try {
      current = await backend.read(key);
    } on StorageUnavailableException catch (e) {
      throw StorageWriteException(e.message, cause: e.cause);
    }
    if (current != null && !_isValid(current, parse)) {
      // Never overwrite damaged data: it may still be recoverable. The user
      // has to pick a recovery action first.
      throw StorageCorruptedException(
        'Your saved data is damaged; it was not overwritten.',
        hasBackup: _isValid(await backend.read(backupKey(key)), parse),
        location: backend.describe(key),
      );
    }
    // Keep the previous version as the backup.
    if (current != null && current != json) {
      await backend.write(backupKey(key), current);
    }
    await backend.write(key, json);
  }

  Future<void> _recover(
    String key,
    StorageRecovery action,
    Object? Function(String) parse,
  ) async {
    final String replacement;
    switch (action) {
      case StorageRecovery.restoreBackup:
        final backup = await backend.read(backupKey(key));
        if (!_isValid(backup, parse)) {
          throw StorageCorruptedException(
            'There is no usable backup to restore.',
            hasBackup: false,
            location: backend.describe(backupKey(key)),
          );
        }
        replacement = backup!;
      case StorageRecovery.startEmpty:
        replacement = '[]';
    }
    // Keep the damaged data aside before replacing it.
    final damaged = await backend.read(key);
    if (damaged != null) {
      await backend.write('$key.corrupt-${_timestamp()}', damaged);
    }
    await backend.write(key, replacement);
  }

  String _timestamp() {
    final t = _clock().toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.year}${two(t.month)}${two(t.day)}T'
        '${two(t.hour)}${two(t.minute)}${two(t.second)}Z';
  }
}
