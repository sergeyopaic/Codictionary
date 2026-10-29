import '../entities/app_settings.dart';

/// Preferences are not user data: unreadable settings fall back to defaults
/// instead of blocking the app.
abstract class SettingsRepository {
  Future<AppSettings> load();

  /// Throws a `StorageException` if saving fails.
  Future<void> save(AppSettings settings);
}
