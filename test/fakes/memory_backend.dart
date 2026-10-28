import 'package:codictionary/domain/exceptions/storage_exceptions.dart';
import 'package:codictionary/services/storage/storage_backend.dart';

/// In-memory [StorageBackend] with switchable failures.
class MemoryBackend implements StorageBackend {
  MemoryBackend([Map<String, String>? values]) : values = {...?values};

  final Map<String, String> values;

  /// When true every read fails as if access was denied.
  bool failReads = false;

  /// Keys whose writes fail; `quotaExceeded` mimics a full browser storage.
  bool Function(String key) failWrite = _never;
  bool quotaExceeded = false;

  static bool _never(String _) => false;

  @override
  Future<String?> read(String key) async {
    if (failReads) throw const StorageUnavailableException('read denied');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite(key)) {
      throw StorageWriteException('write failed', quotaExceeded: quotaExceeded);
    }
    values[key] = value;
  }

  @override
  String describe(String key) => 'memory:$key';
}
