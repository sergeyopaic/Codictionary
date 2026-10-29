import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../domain/exceptions/storage_exceptions.dart';
import '../../domain/services/backup_files.dart';

/// Backups as files in `<documents>/codictionary_backups`.
class FolderBackupFiles implements BackupFiles {
  FolderBackupFiles(this._directory);

  final Future<Directory> Function() _directory;

  Future<Directory> _folder() async {
    final base = await _directory();
    return Directory(
      '${base.path}${Platform.pathSeparator}codictionary_backups',
    );
  }

  @override
  Future<String> save(String fileName, String contents) async {
    try {
      final folder = await _folder();
      await folder.create(recursive: true);
      final path = '${folder.path}${Platform.pathSeparator}$fileName';
      // Same atomic write as the main storage: never a half-written backup.
      final tmp = File('$path.tmp');
      await tmp.writeAsString(contents, flush: true);
      await tmp.rename(path);
      return path;
    } on FileSystemException catch (e) {
      throw StorageWriteException(
        'Could not save the backup file (disk full or access denied).',
        cause: e,
      );
    }
  }

  @override
  Future<List<BackupFile>> list() async {
    try {
      final folder = await _folder();
      if (!await folder.exists()) return const [];
      final files = <BackupFile>[];
      await for (final e in folder.list()) {
        if (e is! File || !e.path.endsWith('.json')) continue;
        files.add(
          BackupFile(
            name: e.uri.pathSegments.last,
            location: e.path,
            modified: await e.lastModified(),
          ),
        );
      }
      // Newest first. Timestamps can be equal (coarse file times), so fall
      // back to the name, which contains the time for our own backups.
      files.sort((a, b) {
        final byTime = b.modified.compareTo(a.modified);
        return byTime != 0 ? byTime : b.name.compareTo(a.name);
      });
      return files;
    } on FileSystemException catch (e) {
      throw StorageUnavailableException(
        'Could not list backup files.',
        cause: e,
      );
    }
  }

  @override
  Future<String> read(BackupFile file) async {
    try {
      return await File(file.location).readAsString();
    } on FileSystemException catch (e) {
      throw StorageUnavailableException(
        'Could not read the backup file.',
        cause: e,
      );
    }
  }

  @override
  bool get canPick => false;

  @override
  Future<String?> pick() async => null;
}

BackupFiles createBackupFiles() =>
    FolderBackupFiles(getApplicationDocumentsDirectory);
