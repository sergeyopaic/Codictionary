import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/data/backup/backup_files_io.dart';
import 'package:codictionary/data/backup/json_backup_codec.dart';
import 'package:codictionary/data/repositories/vocabulary_repository_impl.dart';
import 'package:codictionary/data/repositories/word_repository_impl.dart';
import 'package:codictionary/data/storage/safe_json_storage.dart';
import 'package:codictionary/data/storage/storage_service.dart';
import 'package:codictionary/domain/entities/vocabulary.dart';
import 'package:codictionary/domain/entities/word_entity.dart';
import 'package:codictionary/domain/exceptions/backup_exceptions.dart';
import 'package:codictionary/domain/exceptions/storage_exceptions.dart';
import 'package:codictionary/domain/usecases/backup.dart';
import 'package:codictionary/presentation/app_scope.dart';

import '../fakes/json_storage_service.dart';
import '../fakes/memory_backend.dart';
import '../helpers/test_dependencies.dart';

final _words = [
  WordEntity(
    id: 'p',
    source: 'pear',
    target: 'груша',
    shortExplanation: 'Фрукт.',
    longExplanation: 'Сочный фрукт.\nПример: a ripe pear.',
    createdAt: DateTime.utc(2025, 3, 1, 10, 30, 15, 123),
  ),
  WordEntity(
    id: 'a',
    source: 'apple',
    target: 'яблоко',
    createdAt: DateTime.utc(2024, 12, 31),
  ),
];

final _vocabularies = [
  const Vocabulary(
    id: 'v1',
    name: 'Fruit',
    description: 'Tasty',
    iconPath: 'icons/3.png',
    wordIds: ['a', 'p'],
  ),
  const Vocabulary(id: 'v2', name: 'Empty', description: '', iconPath: 'i.png'),
];

Future<void> _seed(StorageService storage) async {
  final words = WordRepositoryImpl(storage);
  for (final w in _words) {
    await words.create(w);
  }
  final vocabularies = VocabularyRepositoryImpl(storage);
  for (final v in _vocabularies) {
    await vocabularies.create(v);
  }
}

Matcher _invalid(String messagePart) => throwsA(
  isA<BackupFormatException>().having(
    (e) => e.message,
    'message',
    contains(messagePart),
  ),
);

void main() {
  late MemoryBackupFiles files;

  AppUseCases useCasesFor(StorageService storage) {
    files = MemoryBackupFiles();
    return testUseCases(storage: storage, backupFiles: files);
  }

  /// Backup text of an empty dictionary, made without touching [files].
  Future<String> emptyBackup() =>
      testUseCases(storage: JsonStorageService()).exportDictionary();

  test('export → restore on a clean install keeps every field', () async {
    final source = JsonStorageService();
    await _seed(source);
    final exported = await useCasesFor(source).exportDictionary();

    final clean = JsonStorageService();
    final target = useCasesFor(clean);
    await target.replaceDictionary(target.parseBackup(exported));

    expect(await WordRepositoryImpl(clean).getAll(), _words);
    final restored = await VocabularyRepositoryImpl(clean).getAll();
    expect(restored.map((v) => v.id), ['v1', 'v2']);
    expect(restored[0].name, 'Fruit');
    expect(restored[0].description, 'Tasty');
    expect(restored[0].iconPath, 'icons/3.png');
    expect(restored[0].wordIds, ['a', 'p']);
    expect(restored[1].wordIds, isEmpty);
  });

  test('the manual order of words is part of the backup', () async {
    final storage = JsonStorageService();
    await _seed(storage);
    await WordRepositoryImpl(storage).reorder(['a', 'p']);

    final snapshot = useCasesFor(
      storage,
    ).parseBackup(await useCasesFor(storage).exportDictionary());

    expect(snapshot.words.map((w) => w.source), ['apple', 'pear']);
  });

  test('members that were deleted are not exported', () async {
    final storage = JsonStorageService();
    await _seed(storage);
    await WordRepositoryImpl(storage).remove('p');

    final snapshot = await useCasesFor(storage).exportDictionary.snapshot();

    expect(snapshot.vocabularies.first.wordIds, ['a']);
  });

  group('invalid backups are rejected with a reason', () {
    const codec = JsonBackupCodec();
    Map<String, Object?> valid() => jsonDecode(
      codec.encode(
        (const JsonBackupCodec()).decode(
          jsonEncode({
            'format': 'codictionary-backup',
            'version': 1,
            'createdAt': '2026-10-29T12:00:00.000Z',
            'words': [
              {
                'id': 'a',
                'source': 'apple',
                'target': 'яблоко',
                'createdAt': '2025-01-01T00:00:00.000Z',
              },
            ],
            'vocabularies': [
              {
                'id': 'v',
                'name': 'Fruit',
                'description': '',
                'icon': '',
                'wordIds': ['a'],
              },
            ],
          }),
        ),
      ),
    );

    String edit(void Function(Map<String, dynamic> b) change) {
      final b = valid().cast<String, dynamic>();
      change(b);
      return jsonEncode(b);
    }

    Map<String, dynamic> firstWord(Map<String, dynamic> b) =>
        ((b['words'] as List).first as Map).cast<String, dynamic>();

    test('the valid fixture decodes', () {
      expect(codec.decode(jsonEncode(valid())).words.single.source, 'apple');
    });

    test('damaged JSON', () {
      expect(
        () => codec.decode('{"format": "codic'),
        _invalid('not valid JSON'),
      );
    });

    test('something else entirely', () {
      expect(() => codec.decode('[1, 2]'), _invalid('not a Codictionary'));
      expect(
        () => codec.decode(edit((b) => b['format'] = 'other')),
        _invalid('not a Codictionary'),
      );
    });

    test('a newer or missing version', () {
      expect(
        () => codec.decode(edit((b) => b['version'] = 2)),
        _invalid('newer version'),
      );
      expect(
        () => codec.decode(edit((b) => b.remove('version'))),
        _invalid('no valid version'),
      );
    });

    test('duplicate and unknown ids', () {
      expect(
        () => codec.decode(
          edit(
            (b) =>
                (b['words'] as List).add({...firstWord(b), 'source': 'other'}),
          ),
        ),
        _invalid('Duplicate word id'),
      );
      expect(
        () => codec.decode(
          edit((b) => (b['words'] as List).add({...firstWord(b), 'id': 'b'})),
        ),
        _invalid('appears twice'),
      );
      expect(
        () => codec.decode(
          edit(
            (b) => (b['vocabularies'] as List).add(
              ((b['vocabularies'] as List).first as Map),
            ),
          ),
        ),
        _invalid('Duplicate vocabulary id'),
      );
      expect(
        () => codec.decode(
          edit(
            (b) => ((b['vocabularies'] as List).first as Map)['wordIds'] = [
              'a',
              'ghost',
            ],
          ),
        ),
        _invalid('not in the backup'),
      );
      expect(
        () => codec.decode(
          edit(
            (b) => ((b['vocabularies'] as List).first as Map)['wordIds'] = [
              'a',
              'a',
            ],
          ),
        ),
        _invalid('lists a word twice'),
      );
    });

    test('wrong types and dates', () {
      expect(
        () => codec.decode(edit((b) => firstWord(b)['target'] = 5)),
        _invalid('"target" is missing'),
      );
      expect(
        () => codec.decode(edit((b) => firstWord(b)['createdAt'] = 'soon')),
        _invalid('not a date'),
      );
      expect(
        () => codec.decode(edit((b) => firstWord(b)['source'] = '  ')),
        _invalid('"source" is empty'),
      );
    });
  });

  test('a safety copy of the current data is saved before replacing', () async {
    final storage = JsonStorageService();
    await _seed(storage);
    final useCases = useCasesFor(storage);
    final backup = useCases.parseBackup(await emptyBackup());

    final location = await useCases.replaceDictionary(backup);

    expect(await WordRepositoryImpl(storage).getAll(), isEmpty);
    final safety = files.saved.entries.single;
    expect(safety.key, startsWith('codictionary-before-restore-'));
    expect(location, endsWith(safety.key));
    final previous = const JsonBackupCodec().decode(safety.value);
    expect(previous.words, _words);
  });

  test('if the safety copy cannot be saved, nothing is replaced', () async {
    final storage = JsonStorageService();
    await _seed(storage);
    final useCases = useCasesFor(storage);
    final backup = useCases.parseBackup(await emptyBackup());
    files.failSave = true;

    await expectLater(
      useCases.replaceDictionary(backup),
      throwsA(isA<StorageWriteException>()),
    );
    expect(await WordRepositoryImpl(storage).getAll(), _words);
  });

  test('a write error during restore puts the previous words back', () async {
    final backend = MemoryBackend();
    final storage = SafeJsonStorage(
      backend,
      wordsKey: 'dictionary.json',
      vocabsKey: 'vocabularies.json',
    );
    await _seed(storage);
    final useCases = useCasesFor(storage);
    final backup = useCases.parseBackup(await emptyBackup());
    backend.failWrite = (key) => key == 'vocabularies.json';

    await expectLater(
      useCases.replaceDictionary(backup),
      throwsA(isA<StorageWriteException>()),
    );
    expect(await WordRepositoryImpl(storage).getAll(), _words);
    expect(
      (await VocabularyRepositoryImpl(storage).getAll()).map((v) => v.id),
      ['v1', 'v2'],
    );
  });

  group('backup folder on the real file system', () {
    late Directory dir;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('codictionary_backup_');
    });
    tearDown(() => dir.delete(recursive: true));

    test('save, list newest first, read back', () async {
      final folder = FolderBackupFiles(() async => dir);

      final path = await folder.save('codictionary-backup-1.json', '{"a":1}');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await folder.save('codictionary-backup-2.json', '{"b":2}');

      final listed = await folder.list();
      expect(listed.map((f) => f.name), [
        'codictionary-backup-2.json',
        'codictionary-backup-1.json',
      ]);
      expect(await folder.read(listed.last), '{"a":1}');
      expect(path, endsWith('codictionary-backup-1.json'));
      expect(
        Directory(
          '${dir.path}/codictionary_backups',
        ).listSync().where((e) => e.path.endsWith('.tmp')),
        isEmpty,
      );
    });
  });

  test('file names are sortable by time', () {
    expect(
      backupFileName('backup', DateTime(2026, 10, 29, 9, 5, 3)),
      'codictionary-backup-20261029-090503.json',
    );
  });
}
