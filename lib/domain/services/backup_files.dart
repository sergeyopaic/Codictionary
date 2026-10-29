/// A backup file the app knows about (desktop and mobile only).
class BackupFile {
  const BackupFile({
    required this.name,
    required this.location,
    required this.modified,
  });

  final String name;

  /// Full path, for display.
  final String location;
  final DateTime modified;
}

/// Where backup files are written and found. Platform specific: a folder on
/// desktop/mobile, downloads and a file chooser in the browser.
abstract interface class BackupFiles {
  /// Saves [contents] as [fileName]; returns where it went, for display.
  /// Throws a `StorageException` on failure.
  Future<String> save(String fileName, String contents);

  /// Backups found in the backup folder, newest first. Empty where the app
  /// cannot list files (web).
  Future<List<BackupFile>> list();

  Future<String> read(BackupFile file);

  /// Whether [pick] can open a file chooser on this platform.
  bool get canPick;

  /// Lets the user choose a file and returns its text, or null if cancelled.
  Future<String?> pick();
}
