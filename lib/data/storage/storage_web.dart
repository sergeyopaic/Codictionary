// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import '../../domain/exceptions/storage_exceptions.dart';
import 'safe_json_storage.dart';
import 'storage_backend.dart';
import 'storage_service.dart';

/// Stores each key in the browser's localStorage.
class LocalStorageBackend implements StorageBackend {
  html.Storage get _storage {
    try {
      return html.window.localStorage;
    } catch (e) {
      // Blocked site data or some private modes throw on access.
      throw StorageUnavailableException(
        'Browser storage is disabled for this site.',
        cause: e,
      );
    }
  }

  @override
  String describe(String key) => 'browser storage ($key)';

  @override
  Future<String?> read(String key) async {
    final storage = _storage;
    try {
      return storage[key];
    } catch (e) {
      throw StorageUnavailableException(
        'Could not read browser storage.',
        cause: e,
      );
    }
  }

  @override
  Future<void> write(String key, String value) async {
    final html.Storage storage;
    try {
      storage = _storage;
    } on StorageUnavailableException catch (e) {
      throw StorageWriteException(e.message, cause: e.cause);
    }
    try {
      // setItem either stores the whole value or throws, leaving the old one.
      storage[key] = value;
    } catch (e) {
      final quota =
          e is html.DomException &&
          (e.name == 'QuotaExceededError' ||
              e.name == 'NS_ERROR_DOM_QUOTA_REACHED');
      throw StorageWriteException(
        quota
            ? 'Browser storage is full. Free some space and try again.'
            : 'Could not save to browser storage.',
        quotaExceeded: quota,
        cause: e,
      );
    }
  }
}

StorageService createStorageService() => SafeJsonStorage(
  LocalStorageBackend(),
  wordsKey: 'codictionary_dictionary',
  vocabsKey: 'codictionary_vocabularies',
);
