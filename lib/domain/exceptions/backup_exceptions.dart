/// What is wrong with a backup, so the UI can explain it in any language.
enum BackupProblem {
  notJson,
  notBackup,
  noVersion,
  newerVersion,
  missingList,
  notObject,
  missingField,
  emptyField,
  notText,
  notDate,
  duplicateWordId,
  duplicateWord,
  duplicateVocabularyId,
  membersNotList,
  memberTwice,
  unknownMember,
}

/// The text is not a valid Codictionary backup; nothing has been changed
/// when this is thrown.
///
/// [problem] plus the details describe the issue; [message] is an English
/// rendering for logs and tests. The UI words it in the user's language.
class BackupFormatException implements Exception {
  const BackupFormatException(
    this.problem, {
    this.item,
    this.index,
    this.field,
    this.value,
  });

  final BackupProblem problem;

  /// `word`, `vocabulary` or `backup` (the whole file).
  final String? item;

  /// 1-based position of the item in the backup.
  final int? index;
  final String? field;

  /// The offending id, word or version.
  final String? value;

  String get _where => item == 'backup' ? 'the backup' : '$item $index';

  String get message => switch (problem) {
    BackupProblem.notJson =>
      'The text is not valid JSON. Copy the whole backup and try again.',
    BackupProblem.notBackup => 'This is not a Codictionary backup.',
    BackupProblem.noVersion => 'The backup has no valid version.',
    BackupProblem.newerVersion =>
      'This backup was made by a newer version of Codictionary '
          '(format $value). Update the app to restore it.',
    BackupProblem.missingList => '"$field" is missing.',
    BackupProblem.notObject => '$_where is not an object.',
    BackupProblem.missingField => '$_where: "$field" is missing.',
    BackupProblem.emptyField => '$_where: "$field" is empty.',
    BackupProblem.notText => '$_where: "$field" must be text.',
    BackupProblem.notDate => '$_where: "$field" is not a date.',
    BackupProblem.duplicateWordId => 'Duplicate word id "$value".',
    BackupProblem.duplicateWord => '"$value" appears twice.',
    BackupProblem.duplicateVocabularyId => 'Duplicate vocabulary id "$value".',
    BackupProblem.membersNotList => '$_where: "wordIds" must be a list of ids.',
    BackupProblem.memberTwice => '$_where lists a word twice.',
    BackupProblem.unknownMember =>
      '$_where refers to a word that is not in the backup ("$value").',
  };

  @override
  String toString() => 'BackupFormatException: $message';
}
