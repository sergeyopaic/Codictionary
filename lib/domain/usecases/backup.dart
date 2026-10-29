import '../entities/dictionary_snapshot.dart';
import '../repositories/vocabulary_repository.dart';
import '../repositories/word_repository.dart';
import '../services/backup_codec.dart';
import '../services/backup_files.dart';

/// Takes a snapshot of the current dictionary and collections.
///
/// Collection members that no longer exist (deleted words) are left out, so
/// a backup only refers to words it contains.
class ExportDictionary {
  ExportDictionary(this.words, this.vocabularies, this.codec, {this.clock});

  final WordRepository words;
  final VocabularyRepository vocabularies;
  final BackupCodec codec;
  final DateTime Function()? clock;

  Future<DictionarySnapshot> snapshot() async {
    final allWords = await words.getAll();
    final ids = {for (final w in allWords) w.id};
    final allVocabularies = await vocabularies.getAll();
    return DictionarySnapshot(
      words: allWords,
      vocabularies: [
        for (final v in allVocabularies)
          v.copyWith(wordIds: v.wordIds.where(ids.contains).toList()),
      ],
      createdAt: (clock ?? DateTime.now)().toUtc(),
    );
  }

  /// The snapshot as backup text.
  Future<String> call() async => codec.encode(await snapshot());
}

/// Reads and fully validates backup text. Throws `BackupFormatException`;
/// nothing is changed.
class ParseBackup {
  ParseBackup(this.codec);

  final BackupCodec codec;

  DictionarySnapshot call(String text) => codec.decode(text);
}

/// Replaces the whole dictionary and all collections with a backup.
///
/// First saves a safety copy of the current data (aborting if that fails),
/// then writes words and collections. If writing the collections fails, the
/// previous words are written back, so words and collections stay
/// consistent. Returns where the safety copy was saved.
class ReplaceDictionary {
  ReplaceDictionary(
    this.words,
    this.vocabularies,
    this.export,
    this.files, {
    this.clock,
  });

  final WordRepository words;
  final VocabularyRepository vocabularies;
  final ExportDictionary export;
  final BackupFiles files;
  final DateTime Function()? clock;

  Future<String> call(DictionarySnapshot backup) async {
    final current = await export.snapshot();
    final safetyCopy = await files.save(
      backupFileName('before-restore', (clock ?? DateTime.now)()),
      export.codec.encode(current),
    );
    await words.replaceAll(backup.words);
    try {
      await vocabularies.replaceAll(backup.vocabularies);
    } catch (_) {
      try {
        await words.replaceAll(current.words);
        await vocabularies.replaceAll(current.vocabularies);
      } catch (_) {
        // The safety copy still holds the previous data.
      }
      rethrow;
    }
    return safetyCopy;
  }
}

/// Saves a backup file of the current data; returns where it went.
class SaveBackupFile {
  SaveBackupFile(this.export, this.files, {this.clock});

  final ExportDictionary export;
  final BackupFiles files;
  final DateTime Function()? clock;

  Future<String> call() async => files.save(
    backupFileName('backup', (clock ?? DateTime.now)()),
    await export(),
  );
}

/// Backup files known on this device, plus reading and picking them.
class BackupFileAccess {
  BackupFileAccess(this.files);

  final BackupFiles files;

  Future<List<BackupFile>> list() => files.list();
  Future<String> read(BackupFile file) => files.read(file);
  bool get canPick => files.canPick;
  Future<String?> pick() => files.pick();
}

/// `codictionary-<kind>-20261029-120000.json` (local time, sortable).
String backupFileName(String kind, DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  final t = time.toLocal();
  return 'codictionary-$kind-${t.year}${two(t.month)}${two(t.day)}-'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}.json';
}
