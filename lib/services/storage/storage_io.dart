import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show MissingPluginException;
import 'package:path_provider/path_provider.dart';

import '../../domain/exceptions/storage_exceptions.dart';
import 'safe_json_storage.dart';
import 'storage_backend.dart';
import 'storage_interface.dart';

/// Stores each key as a file in a directory.
class FileBackend implements StorageBackend {
  FileBackend(this._directory);

  final Future<Directory> Function() _directory;
  String? _dirPath;

  Future<String> _path(String key) async {
    _dirPath ??= (await _directory()).path;
    return '$_dirPath${Platform.pathSeparator}$key';
  }

  @override
  String describe(String key) =>
      _dirPath == null ? key : '$_dirPath${Platform.pathSeparator}$key';

  @override
  Future<String?> read(String key) async {
    final String path;
    try {
      path = await _path(key);
      switch (await FileSystemEntity.type(path)) {
        case FileSystemEntityType.notFound:
          return null;
        case FileSystemEntityType.file:
          // Invalid UTF-8 is damage, not an access problem: decode leniently
          // and let the JSON parser reject it.
          return utf8.decode(
            await File(path).readAsBytes(),
            allowMalformed: true,
          );
        default:
          throw FileSystemException('Not a regular file', path);
      }
    } on FileSystemException catch (e) {
      throw StorageUnavailableException(
        'Could not read your saved data (access denied or disk error).',
        cause: e,
      );
    } on MissingPluginException catch (e) {
      throw StorageUnavailableException(
        'Local storage is not available on this device.',
        cause: e,
      );
    }
  }

  @override
  Future<void> write(String key, String value) async {
    File? tmp;
    try {
      final path = await _path(key);
      await Directory(File(path).parent.path).create(recursive: true);
      // Write a complete temporary file, then move it over the original.
      // The rename replaces the target in one step (also on Windows), so an
      // interrupted write leaves the old file intact.
      tmp = File('$path.tmp');
      await tmp.writeAsString(value, flush: true);
      await tmp.rename(path);
    } on FileSystemException catch (e) {
      try {
        if (tmp != null && await tmp.exists()) await tmp.delete();
      } catch (_) {}
      throw StorageWriteException(
        'Could not save your changes (disk full or access denied).',
        cause: e,
      );
    }
  }
}

StorageService createStorageService() => SafeJsonStorage(
  FileBackend(getApplicationDocumentsDirectory),
  wordsKey: 'dictionary.json',
  vocabsKey: 'vocabularies.json',
);
