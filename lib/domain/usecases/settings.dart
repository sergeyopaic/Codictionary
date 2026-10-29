import '../entities/app_settings.dart';
import '../repositories/settings_repository.dart';

class LoadSettings {
  LoadSettings(this.repository);
  final SettingsRepository repository;

  /// Never throws: defaults if the settings cannot be read.
  Future<AppSettings> call() async {
    try {
      return await repository.load();
    } catch (_) {
      return const AppSettings();
    }
  }
}

class SaveSettings {
  SaveSettings(this.repository);
  final SettingsRepository repository;

  Future<void> call(AppSettings settings) => repository.save(settings);
}
