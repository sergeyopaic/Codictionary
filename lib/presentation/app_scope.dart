import 'package:flutter/widgets.dart';

import '../domain/usecases/add_word.dart';
import '../domain/usecases/backup.dart';
import '../domain/usecases/explain_word.dart';
import '../domain/usecases/get_all_words.dart';
import '../domain/usecases/get_vocabularies.dart';
import '../domain/usecases/manage_vocabularies.dart';
import '../domain/usecases/recover_words.dart';
import '../domain/usecases/remove_word.dart';
import '../domain/usecases/reorder_words.dart';
import '../domain/usecases/restore_word.dart';
import '../domain/usecases/settings.dart';
import '../domain/usecases/translate_word.dart';
import '../domain/usecases/update_word.dart';

/// Everything the UI may call: domain use cases only. Built once by
/// `lib/composition` (production) or by tests (with fakes).
class AppUseCases {
  const AppUseCases({
    required this.getAllWords,
    required this.addWord,
    required this.updateWord,
    required this.restoreWord,
    required this.removeWord,
    required this.reorderWords,
    required this.recoverWords,
    required this.explainWord,
    required this.translateWord,
    required this.getVocabularies,
    required this.createVocabulary,
    required this.updateVocabulary,
    required this.deleteVocabulary,
    required this.restoreVocabulary,
    required this.setWordInVocabulary,
    required this.exportDictionary,
    required this.parseBackup,
    required this.replaceDictionary,
    required this.saveBackupFile,
    required this.backupFiles,
    required this.loadSettings,
    required this.saveSettings,
  });

  final GetAllWords getAllWords;
  final AddWord addWord;
  final UpdateWord updateWord;
  final RestoreWord restoreWord;
  final RemoveWord removeWord;
  final ReorderWords reorderWords;
  final RecoverWords recoverWords;
  final ExplainWord explainWord;
  final TranslateWord translateWord;
  final GetVocabularies getVocabularies;
  final CreateVocabulary createVocabulary;
  final UpdateVocabulary updateVocabulary;
  final DeleteVocabulary deleteVocabulary;
  final RestoreVocabulary restoreVocabulary;
  final SetWordInVocabulary setWordInVocabulary;
  final ExportDictionary exportDictionary;
  final ParseBackup parseBackup;
  final ReplaceDictionary replaceDictionary;
  final SaveBackupFile saveBackupFile;
  final BackupFileAccess backupFiles;
  final LoadSettings loadSettings;
  final SaveSettings saveSettings;
}

/// Provides [AppUseCases] to the widget tree. Immutable: rebuilding the app
/// never re-registers or replaces dependencies.
class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.useCases, required super.child});

  final AppUseCases useCases;

  /// Reads without subscribing; safe in `initState`.
  static AppUseCases read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope above this widget');
    return scope!.useCases;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      !identical(useCases, oldWidget.useCases);
}
