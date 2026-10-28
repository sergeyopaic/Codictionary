import 'package:flutter_test/flutter_test.dart';

import 'package:codictionary/data/repositories/word_repository_impl.dart';
import 'package:codictionary/domain/entities/word_entity.dart';
import 'package:codictionary/domain/exceptions/word_exceptions.dart';

import '../fakes/json_storage_service.dart';

void main() {
  final created = DateTime.utc(2025, 3, 14, 9, 30);

  WordEntity sample() => WordEntity(
    id: 'w1',
    source: 'resilient',
    target: 'стойкий',
    shortExplanation: 'Кратко',
    longExplanation: 'Подробно',
    createdAt: created,
  );

  test('all fields survive a restart', () async {
    final storage = JsonStorageService();
    await WordRepositoryImpl(storage).create(sample());

    // A new repository over the same storage simulates an app restart.
    final loaded = await WordRepositoryImpl(storage).getAll();

    expect(loaded, [sample()]);
  });

  test('update keeps the stored creation date and other fields', () async {
    final storage = JsonStorageService();
    final repo = WordRepositoryImpl(storage);
    await repo.create(sample());

    // Even if a caller passes a different date, the stored one wins.
    final edited = WordEntity(
      id: 'w1',
      source: 'resilient',
      target: 'устойчивый',
      shortExplanation: 'Кратко',
      longExplanation: 'Подробно',
      createdAt: DateTime.utc(2030),
    );
    await repo.update(edited);

    final loaded = (await WordRepositoryImpl(storage).getAll()).single;
    expect(loaded.target, 'устойчивый');
    expect(loaded.shortExplanation, 'Кратко');
    expect(loaded.longExplanation, 'Подробно');
    expect(loaded.createdAt, created);
  });

  test('create and update are separate operations', () async {
    final repo = WordRepositoryImpl(JsonStorageService());

    await expectLater(
      repo.update(sample()),
      throwsA(isA<WordNotFoundException>()),
    );
    await repo.create(sample());
    await expectLater(
      repo.create(sample()),
      throwsA(isA<WordAlreadyExistsException>()),
    );
    await repo.remove('missing');
    expect(await repo.getAll(), hasLength(1));
  });

  test('clearing an explanation is persisted', () async {
    final storage = JsonStorageService();
    final repo = WordRepositoryImpl(storage);
    await repo.create(sample());

    await repo.update(
      sample().copyWith(shortExplanation: null, longExplanation: null),
    );

    final loaded = (await WordRepositoryImpl(storage).getAll()).single;
    expect(loaded.shortExplanation, isNull);
    expect(loaded.longExplanation, isNull);
  });

  group('legacy records', () {
    test('desc, descShort and descLong are read correctly', () async {
      final storage = JsonStorageService(
        rawWords: [
          {
            'id': 'a',
            'eng': 'apple',
            'rus': 'яблоко',
            'desc': 'only legacy desc',
            'addedAt': '2024-01-02T03:04:05.000Z',
          },
          {
            'id': 'b',
            'eng': 'dog',
            'rus': 'собака',
            'desc': 'old',
            'descShort': 'new short',
            'descLong': 'long text',
            'addedAt': '2024-01-02T03:04:05.000Z',
          },
        ],
      );

      final words = await WordRepositoryImpl(storage).getAll();

      expect(words[0].shortExplanation, 'only legacy desc');
      expect(words[0].longExplanation, isNull);
      expect(words[0].createdAt, DateTime.utc(2024, 1, 2, 3, 4, 5));
      expect(words[1].shortExplanation, 'new short');
      expect(words[1].longExplanation, 'long text');
    });

    test(
      'missing and duplicate ids are repaired once and stay stable',
      () async {
        final storage = JsonStorageService(
          rawWords: [
            {'eng': 'apple', 'rus': 'яблоко'},
            {
              'id': 'x',
              'eng': 'dog',
              'rus': 'собака',
              'addedAt': '2024-01-01T00:00:00.000Z',
            },
            {
              'id': 'x',
              'eng': 'cat',
              'rus': 'кошка',
              'addedAt': '2024-01-01T00:00:00.000Z',
            },
          ],
        );

        final first = await WordRepositoryImpl(storage).getAll();
        final second = await WordRepositoryImpl(storage).getAll();

        final ids = first.map((w) => w.id).toList();
        expect(ids.toSet(), hasLength(3));
        expect(ids.every((id) => id.isNotEmpty), isTrue);
        expect(
          second,
          first,
          reason: 'ids and dates must not change on reload',
        );

        // The repaired record can be updated and removed by its id.
        final repo = WordRepositoryImpl(storage);
        await repo.update(first[0].copyWith(target: 'яблочко'));
        await repo.remove(first[2].id);
        final after = await repo.getAll();
        expect(after.map((w) => w.source), ['apple', 'dog']);
        expect(after[0].target, 'яблочко');
      },
    );
  });
}
