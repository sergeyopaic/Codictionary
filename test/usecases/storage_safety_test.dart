import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/domain/exceptions/storage_exceptions.dart';
import 'package:codictionary/models/word.dart';
import 'package:codictionary/services/storage/safe_json_storage.dart';
import 'package:codictionary/services/storage/storage_io.dart';

import '../fakes/memory_backend.dart';

const _key = 'dictionary.json';
const _bak = 'dictionary.json.bak';

Word _w(String id, String eng) =>
    Word(id: id, eng: eng, rus: 'ru', addedAt: DateTime.utc(2025));

String _json(List<Word> words) =>
    jsonEncode(words.map((w) => w.toMap()).toList());

SafeJsonStorage _storage(MemoryBackend backend) => SafeJsonStorage(
  backend,
  wordsKey: _key,
  vocabsKey: 'vocabularies.json',
  clock: () => DateTime.utc(2026, 10, 29, 12),
);

void main() {
  group('SafeJsonStorage', () {
    test('a missing dictionary is a first run and reads as empty', () async {
      expect(await _storage(MemoryBackend()).loadWords(), isEmpty);
    });

    test('damaged JSON throws and is never overwritten', () async {
      final backend = MemoryBackend({_key: '[{"id":"1","eng":"app'});
      final storage = _storage(backend);

      await expectLater(
        storage.loadWords(),
        throwsA(
          isA<StorageCorruptedException>().having(
            (e) => e.hasBackup,
            'hasBackup',
            false,
          ),
        ),
      );
      await expectLater(
        storage.saveWords([_w('2', 'new')]),
        throwsA(isA<StorageCorruptedException>()),
      );
      expect(backend.values[_key], '[{"id":"1","eng":"app');
    });

    test('empty file and wrongly typed entries count as damage', () async {
      for (final raw in ['', '   ', '{}', '[1, 2]', '[{"eng": 5}]']) {
        await expectLater(
          _storage(MemoryBackend({_key: raw})).loadWords(),
          throwsA(isA<StorageCorruptedException>()),
          reason: raw,
        );
      }
    });

    test('a read failure is reported, not treated as empty', () async {
      final backend = MemoryBackend({
        _key: _json([_w('1', 'apple')]),
      })..failReads = true;
      await expectLater(
        _storage(backend).loadWords(),
        throwsA(isA<StorageUnavailableException>()),
      );
    });

    test('a failed write throws and keeps the previous data', () async {
      final backend = MemoryBackend();
      final storage = _storage(backend);
      await storage.saveWords([_w('1', 'apple')]);
      final before = Map.of(backend.values);

      backend.failWrite = (key) => key == _key;
      await expectLater(
        storage.saveWords([_w('1', 'apple'), _w('2', 'pear')]),
        throwsA(isA<StorageWriteException>()),
      );

      expect(backend.values[_key], before[_key]);
      expect((await storage.loadWords()).map((w) => w.eng), ['apple']);
    });

    test('a full browser storage is reported as quota exceeded', () async {
      final backend =
          MemoryBackend({
              _key: _json([_w('1', 'apple')]),
            })
            ..failWrite = ((_) => true)
            ..quotaExceeded = true;

      await expectLater(
        _storage(backend).saveWords([_w('2', 'pear')]),
        throwsA(
          isA<StorageWriteException>().having(
            (e) => e.quotaExceeded,
            'quotaExceeded',
            true,
          ),
        ),
      );
      expect(backend.values[_key], _json([_w('1', 'apple')]));
    });

    test('damage with a backup can be restored; damage is kept', () async {
      final backend = MemoryBackend();
      final storage = _storage(backend);
      await storage.saveWords([_w('1', 'apple')]);
      await storage.saveWords([_w('1', 'apple'), _w('2', 'pear')]);
      expect(backend.values[_bak], _json([_w('1', 'apple')]));

      backend.values[_key] = 'garbage';
      await expectLater(
        storage.loadWords(),
        throwsA(
          isA<StorageCorruptedException>().having(
            (e) => e.hasBackup,
            'hasBackup',
            true,
          ),
        ),
      );

      await storage.recoverWords(StorageRecovery.restoreBackup);

      expect((await storage.loadWords()).map((w) => w.eng), ['apple']);
      expect(backend.values['$_key.corrupt-20261029T120000Z'], 'garbage');
    });

    test('starting empty keeps the damaged data aside', () async {
      final backend = MemoryBackend({_key: 'garbage'});
      final storage = _storage(backend);

      await storage.recoverWords(StorageRecovery.startEmpty);

      expect(await storage.loadWords(), isEmpty);
      expect(backend.values['$_key.corrupt-20261029T120000Z'], 'garbage');
    });

    test(
      'a missing dictionary next to a backup is not shown as empty',
      () async {
        final backend = MemoryBackend({
          _bak: _json([_w('1', 'apple')]),
        });
        final storage = _storage(backend);

        await expectLater(
          storage.loadWords(),
          throwsA(isA<StorageCorruptedException>()),
        );
        await storage.recoverWords(StorageRecovery.restoreBackup);
        expect((await storage.loadWords()).map((w) => w.eng), ['apple']);
      },
    );

    test(
      'restoring without a usable backup fails and changes nothing',
      () async {
        final backend = MemoryBackend({_key: 'garbage', _bak: 'also garbage'});
        await expectLater(
          _storage(backend).recoverWords(StorageRecovery.restoreBackup),
          throwsA(isA<StorageCorruptedException>()),
        );
        expect(backend.values[_key], 'garbage');
      },
    );
  });

  group('FileBackend on the real file system', () {
    late Directory dir;
    late SafeJsonStorage storage;
    File file(String name) => File('${dir.path}${Platform.pathSeparator}$name');

    setUp(() async {
      // Never the user's documents folder: a fresh temporary directory.
      dir = await Directory.systemTemp.createTemp('codictionary_test_');
      storage = SafeJsonStorage(
        FileBackend(() async => dir),
        wordsKey: _key,
        vocabsKey: 'vocabularies.json',
      );
    });

    tearDown(() => dir.delete(recursive: true));

    test('saves replace the file atomically and keep a backup', () async {
      await storage.saveWords([_w('1', 'apple')]);
      await storage.saveWords([_w('1', 'apple'), _w('2', 'pear')]);

      expect((await storage.loadWords()).map((w) => w.eng), ['apple', 'pear']);
      expect(await file(_bak).readAsString(), _json([_w('1', 'apple')]));
      expect(await file('$_key.tmp').exists(), isFalse);
    });

    test('an interrupted write leaves the previous file usable', () async {
      await storage.saveWords([_w('1', 'apple')]);
      // Crash after writing part of the temporary file, before the rename.
      await file('$_key.tmp').writeAsString('[{"id":"2","en');

      expect((await storage.loadWords()).map((w) => w.eng), ['apple']);
      await storage.saveWords([_w('1', 'apple'), _w('2', 'pear')]);
      expect((await storage.loadWords()).map((w) => w.eng), ['apple', 'pear']);
    });

    test('a failed write throws and leaves the file untouched', () async {
      await storage.saveWords([_w('1', 'apple')]);
      final before = await file(_key).readAsString();
      // Block the temporary file by putting a directory in its place.
      await Directory(file('$_key.tmp').path).create();

      await expectLater(
        storage.saveWords([_w('2', 'pear')]),
        throwsA(isA<StorageWriteException>()),
      );
      expect(await file(_key).readAsString(), before);
    });

    test('an unreadable dictionary is reported as unavailable', () async {
      await Directory(file(_key).path).create(); // not a regular file

      await expectLater(
        storage.loadWords(),
        throwsA(isA<StorageUnavailableException>()),
      );
    });

    test('invalid UTF-8 is treated as damage', () async {
      await file(_key).writeAsBytes([0x5b, 0xff, 0xfe, 0x5d]);

      await expectLater(
        storage.loadWords(),
        throwsA(isA<StorageCorruptedException>()),
      );
    });

    test('a file written by the previous app version still loads', () async {
      await file(_key).writeAsString(
        '[{"id":"1","eng":"apple","rus":"яблоко","desc":"Кратко"},'
        '{"id":"2","eng":"dog","rus":"собака","addedAt":"2024-01-01T00:00:00.000Z"}]',
      );

      final first = await storage.loadWords();
      final second = await storage.loadWords();

      expect(first.map((w) => w.desc), ['Кратко', null]);
      // The date assigned to the legacy entry was persisted, so it is stable.
      expect(second[0].addedAt.isAtSameMomentAs(first[0].addedAt), isTrue);
    });
  });
}
