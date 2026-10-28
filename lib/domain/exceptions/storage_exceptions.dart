/// Failures of local storage. Messages are safe to show to the user; [cause]
/// is for diagnostics only.
sealed class StorageException implements Exception {
  const StorageException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      '$runtimeType: $message${cause == null ? '' : ' ($cause)'}';
}

/// Stored data could not be read at all: access denied, disk error, or
/// browser storage disabled. Nothing was changed.
class StorageUnavailableException extends StorageException {
  const StorageUnavailableException(super.message, {super.cause});
}

/// Stored data exists but is not valid. It is left untouched until the user
/// chooses a recovery action.
class StorageCorruptedException extends StorageException {
  const StorageCorruptedException(
    super.message, {
    required this.hasBackup,
    required this.location,
    super.cause,
  });

  /// Whether a last good copy is available to restore.
  final bool hasBackup;

  /// Where the damaged data lives (file path or browser storage key).
  final String location;
}

/// Writing failed. The previously stored data is unchanged.
class StorageWriteException extends StorageException {
  const StorageWriteException(
    super.message, {
    this.quotaExceeded = false,
    super.cause,
  });

  final bool quotaExceeded;
}

/// How to recover a damaged dictionary. Both keep the damaged data aside.
enum StorageRecovery {
  /// Replace the damaged data with the last good backup.
  restoreBackup,

  /// Start with an empty dictionary.
  startEmpty,
}
