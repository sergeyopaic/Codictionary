import '../entities/dictionary_snapshot.dart';

/// Turns snapshots into a portable text format and back.
abstract interface class BackupCodec {
  String encode(DictionarySnapshot snapshot);

  /// Validates completely before returning. Throws `BackupFormatException`.
  DictionarySnapshot decode(String text);
}
