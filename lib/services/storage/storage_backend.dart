import '../../domain/exceptions/storage_exceptions.dart';

/// Raw key–value persistence for one platform (files, localStorage).
abstract class StorageBackend {
  /// The stored value, or null if [key] does not exist.
  /// Throws [StorageUnavailableException] if it cannot be read.
  Future<String?> read(String key);

  /// Replaces the value of [key] atomically: afterwards it holds either the
  /// old or the new value, never a partial one.
  /// Throws [StorageWriteException]; the old value is kept on failure.
  Future<void> write(String key, String value);

  /// Human-readable location of [key] for error messages.
  String describe(String key);
}
