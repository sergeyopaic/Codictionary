import '../../domain/entities/vocabulary.dart';
import '../../domain/repositories/vocabulary_repository.dart';
import '../storage/storage_service.dart';

/// Maps vocabularies to the stored `{name, description, icon}` records.
class VocabularyRepositoryImpl implements VocabularyRepository {
  final StorageService storage;
  VocabularyRepositoryImpl(this.storage);

  static const defaultIcon = 'assets/media/icons/new_dictionary/1.png';

  @override
  Future<List<Vocabulary>> getAll() async => [
    for (final m in await storage.loadVocabularies())
      Vocabulary(
        name: (m['name'] ?? '').isEmpty ? 'Untitled' : m['name']!,
        description: m['description'] ?? '',
        iconPath: (m['icon'] ?? '').isEmpty ? defaultIcon : m['icon']!,
      ),
  ];

  @override
  Future<void> saveAll(List<Vocabulary> vocabularies) =>
      storage.saveVocabularies([
        for (final v in vocabularies)
          {'name': v.name, 'description': v.description, 'icon': v.iconPath},
      ]);
}
