/// The text is not a valid Codictionary backup. [message] says why and is
/// safe to show; nothing has been changed when this is thrown.
class BackupFormatException implements Exception {
  const BackupFormatException(this.message);

  final String message;

  @override
  String toString() => 'BackupFormatException: $message';
}
