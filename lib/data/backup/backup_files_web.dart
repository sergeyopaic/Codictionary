// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;

import '../../domain/exceptions/storage_exceptions.dart';
import '../../domain/services/backup_files.dart';

/// Browser: saving downloads a file, restoring opens a file chooser.
class BrowserBackupFiles implements BackupFiles {
  @override
  Future<String> save(String fileName, String contents) async {
    try {
      final blob = html.Blob([contents], 'application/json');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..download = fileName
        ..click();
      html.Url.revokeObjectUrl(url);
      return 'Downloads ($fileName)';
    } catch (e) {
      throw StorageWriteException(
        'The browser did not allow the download.',
        cause: e,
      );
    }
  }

  @override
  Future<List<BackupFile>> list() async => const [];

  @override
  Future<String> read(BackupFile file) =>
      throw UnsupportedError('No backup folder in the browser');

  @override
  bool get canPick => true;

  @override
  Future<String?> pick() {
    final done = Completer<String?>();
    final input = html.FileUploadInputElement()
      ..accept = '.json,application/json';
    input.onChange.listen((_) {
      final file = input.files?.isNotEmpty == true ? input.files!.first : null;
      if (file == null) {
        done.complete(null);
        return;
      }
      final reader = html.FileReader();
      reader.onLoad.listen((_) => done.complete(reader.result as String?));
      reader.onError.listen(
        (_) => done.completeError(
          const StorageUnavailableException('Could not read the file.'),
        ),
      );
      reader.readAsText(file);
    });
    input.click();
    // If the chooser is cancelled the browser sends no event; the future then
    // simply never completes, which the UI tolerates.
    return done.future;
  }
}

BackupFiles createBackupFiles() => BrowserBackupFiles();
