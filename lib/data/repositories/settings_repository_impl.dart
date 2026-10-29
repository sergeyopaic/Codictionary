import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../storage/storage_service.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  SettingsRepositoryImpl(this.storage);
  final StorageService storage;

  @override
  Future<AppSettings> load() async {
    final values = await storage.loadSettings();
    final theme = ThemePreference.values
        .where((t) => t.name == values['theme'])
        .firstOrNull;
    return AppSettings(theme: theme ?? ThemePreference.system);
  }

  @override
  Future<void> save(AppSettings settings) =>
      storage.saveSettings({'theme': settings.theme.name});
}
