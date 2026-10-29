import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../../domain/exceptions/backup_exceptions.dart';
import '../../domain/exceptions/service_exceptions.dart';
import '../../domain/exceptions/storage_exceptions.dart';
import 'strings_en.dart';
import 'strings_ru.dart';

/// Every text the UI shows, per interface language. The interface language
/// follows the system (Russian or English, English otherwise); it is
/// independent of the EN → RU translation direction.
///
/// Abstract members make a missing translation a compile error.
abstract class AppStrings {
  const AppStrings();

  /// The Material locale that matches this interface language.
  Locale get locale;

  static AppStrings forLocale(Locale locale) =>
      locale.languageCode == 'ru' ? const RuStrings() : const EnStrings();

  /// Keyboard shortcut label: ⌘N on Apple platforms, Ctrl+N elsewhere.
  String shortcut(String key) => isApple ? '⌘$key' : 'Ctrl+$key';

  static bool get isApple =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;

  // Common ------------------------------------------------------------------
  String get cancel;
  String get delete;
  String get undo;
  String get tryAgain;
  String get done;
  String get save;
  String get create;
  String get edit;
  String get close;
  String get clear;
  String get options;
  String get moreOptions;
  String get untitled;
  String notSaved(String reason);
  String wordCount(int n);
  String vocabularyCount(int n);
  String collectionCount(int n);
  String snapshotCount(int words, int vocabularies);

  // Shell -------------------------------------------------------------------
  String get navDictionary;
  String get navVocabularies;
  String get navBackup;
  String get library;
  String get tipTitle;
  String tipBody(String addShortcut);
  String get themeLight;
  String get themeSystem;
  String get themeDark;
  String get themeFollowsSystem;
  String get themeIsLight;
  String get themeIsDark;

  // Dictionary --------------------------------------------------------------
  String get wordUpdated;
  String wordDeleted(String word);
  String wordsDeleted(int n);
  String get addWord;
  String addWordTooltip(String shortcut);
  String searchHintLong(String shortcut);
  String get searchHintShort;
  String get sortAZ;
  String get sortZA;
  String get sortRecent;
  String get sortAZTooltip;
  String get sortZATooltip;
  String get sortRecentTooltip;
  String get sortMenuAZ;
  String get sortMenuZA;
  String get sortTooltip;
  String get selectWords;
  String get doneSelecting;
  String get emptyTitle;
  String emptyMessage({required bool translation, required bool ai});
  String get addFirstWord;
  String get addExamples;
  String get noMatchesTitle;
  String noMatchesMessage(String query);
  String addQuery(String query);
  String get reorderBlockedSearch;
  String get reorderBlockedSort;

  // Banner ------------------------------------------------------------------
  String heroExplained(int n);
  String get heroAiOff;
  String get heroStart;
  String get heroEyebrow;
  String get heroTitleEmpty;
  String heroTitle(int n);
  String get heroDirection;

  // Selection ---------------------------------------------------------------
  String get selectionDone;
  String selectedCount(int n);
  String get selectAll;

  // Delete dialogs ----------------------------------------------------------
  String get deleteWordTitle;
  String deleteWordMessage(String word);
  String deleteWordsTitle(int n);
  String get deleteWordsMessage;

  // Storage errors ----------------------------------------------------------
  String get startEmptyTitle;
  String get startEmptyMessage;
  String get startEmpty;
  String get cantOpenDictionary;
  String wordsNotChanged(String reason);
  String get dictionaryDamaged;
  String damagedWithBackup(String reason);
  String damagedNoBackup(String reason);
  String get restoreLastGood;
  String storageError(StorageException e);

  // Card --------------------------------------------------------------------
  String get writingExplanation;
  String explanationFailed(String reason);
  String get noExplanation;
  String get noExplanationTap;

  // Explanation sheet -------------------------------------------------------
  String get editWord;
  String get quick;
  String get inDepth;
  String get quickExplanation;
  String get inDepthExplanation;
  String get generateExplanation;
  String get generateInDepth;
  String get aiOffInSheet;
  String get noExplanationYet;
  String get codyExplains;
  String get copied;
  String get copy;
  String get regenerate;
  String get codyThinking;

  // AI and translation failures ---------------------------------------------
  String failureShortReason(Object error);
  String failureMessage(Object error);
  String serviceError(ServiceException e);

  // Editor ------------------------------------------------------------------
  String notTranslated(String reason);
  String get enterWordFirst;
  String get wordExists;
  String editorSubtitle({required bool translation, required bool ai});
  String get addAWord;
  String get english;
  String get englishHint;
  String get russian;
  String get russianAutoHint;
  String get russianTypeHint;
  String get autoTranslate;
  String get autoTranslateOn;
  String get autoTranslateUnavailable;
  String get translating;
  String get saving;
  String get saveWithoutTranslation;
  String get saveChanges;

  // Toast -------------------------------------------------------------------
  String get wordAdded;
  String get savedToDictionary;
  String wordInDictionary(String word);

  // Word menu ---------------------------------------------------------------
  String get explain;
  String get vocabulariesMenu;

  // Vocabularies ------------------------------------------------------------
  String get editVocabulary;
  String get newVocabulary;
  String get vocabDialogSubtitle;
  String get name;
  String get nameHint;
  String get nameRequired;
  String get descriptionOptional;
  String get icon;
  String get deleteVocabTitle;
  String deleteVocabMessage(String name, int wordsStaying);
  String vocabDeleted(String name);
  String get vocabsSubtitleEmpty;
  String get cantOpenVocabs;
  String nothingChanged(String reason);
  String get noVocabsTitle;
  String get noVocabsMessage;
  String get createVocab;
  String get noDescription;
  String removedFromVocab(String word);
  String get vocabGoneTitle;
  String get vocabGoneMessage;
  String get noWordsHereTitle;
  String get noWordsHereMessage;
  String get addWords;
  String get removeFromVocab;
  String chooseWhere(String word);
  String get noVocabsCreateOne;
  String get pickerDictionaryEmpty;
  String get pickerAllAdded;
  String pickerNoMatch(String query);
  String addNWords(int n);

  // Backup ------------------------------------------------------------------
  String backupSaved(String location);
  String notCopied(String reason);
  String get backupCopied;
  String get clipboardEmpty;
  String couldNotRead(String name, String reason);
  String invalidBackup(String reason);
  String get currentUnreadable;
  String get replaceTitle;
  String replaceMessage(String date, String backup, String current);
  String get replace;
  String restored(String count, String location);
  String notRestored(String reason);
  String get backupTitle;
  String get backupSubtitle;
  String get backUpTitle;
  String backUpText(String count);
  String get readingData;
  String get saveBackupFile;
  String get copyToClipboard;
  String get restoreTitle;
  String get restoreText;
  String get pasteFromClipboard;
  String get openFile;
  String get backupsOnDevice;
  String get restore;
  String backupProblem(BackupFormatException e);
}

/// Russian plural: 1 слово, 2 слова, 5 слов, 11 слов, 21 слово.
String ruPlural(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}

/// Provides [AppStrings] for the interface language.
class StringsScope extends InheritedWidget {
  const StringsScope({super.key, required this.strings, required super.child});

  final AppStrings strings;

  static AppStrings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StringsScope>()?.strings ??
      const EnStrings();

  @override
  bool updateShouldNotify(StringsScope oldWidget) =>
      oldWidget.strings.runtimeType != strings.runtimeType;
}

extension StringsContext on BuildContext {
  AppStrings get s => StringsScope.of(this);
}
