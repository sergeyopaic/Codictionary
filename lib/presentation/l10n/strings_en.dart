import 'package:flutter/widgets.dart';

import '../../domain/exceptions/backup_exceptions.dart';
import '../../domain/exceptions/service_exceptions.dart';
import '../../domain/exceptions/storage_exceptions.dart';
import 'app_strings.dart';

class EnStrings extends AppStrings {
  const EnStrings();

  @override
  Locale get locale => const Locale('en');

  String _n(int n, String one, String many) => n == 1 ? '1 $one' : '$n $many';

  // Common
  @override
  String get cancel => 'Cancel';
  @override
  String get delete => 'Delete';
  @override
  String get undo => 'Undo';
  @override
  String get tryAgain => 'Try again';
  @override
  String get done => 'Done';
  @override
  String get save => 'Save';
  @override
  String get create => 'Create';
  @override
  String get edit => 'Edit';
  @override
  String get close => 'Close';
  @override
  String get clear => 'Clear';
  @override
  String get options => 'Options';
  @override
  String get moreOptions => 'More options';
  @override
  String get untitled => 'Untitled';
  @override
  String notSaved(String reason) => 'Not saved: $reason';
  @override
  String wordCount(int n) => _n(n, 'word', 'words');
  @override
  String vocabularyCount(int n) => _n(n, 'vocabulary', 'vocabularies');
  @override
  String collectionCount(int n) => _n(n, 'collection', 'collections');
  @override
  String snapshotCount(int words, int vocabularies) =>
      '${wordCount(words)} and ${vocabularyCount(vocabularies)}';

  // Shell
  @override
  String get navDictionary => 'Dictionary';
  @override
  String get navVocabularies => 'Vocabularies';
  @override
  String get navBackup => 'Backup';
  @override
  String get library => 'LIBRARY';
  @override
  String get tipTitle => 'Tip';
  @override
  String tipBody(String addShortcut) =>
      'Long-press a card to drag it. Press $addShortcut to add a word.';
  @override
  String get themeLight => 'Light';
  @override
  String get themeSystem => 'System';
  @override
  String get themeDark => 'Dark';
  @override
  String get themeFollowsSystem => 'Theme: follows the system';
  @override
  String get themeIsLight => 'Theme: light';
  @override
  String get themeIsDark => 'Theme: dark';

  // Dictionary
  @override
  String get wordUpdated => 'Word updated.';
  @override
  String wordDeleted(String word) => '"$word" deleted.';
  @override
  String wordsDeleted(int n) => '${wordCount(n)} deleted.';
  @override
  String get addWord => 'Add word';
  @override
  String addWordTooltip(String shortcut) => 'Add word ($shortcut)';
  @override
  String searchHintLong(String shortcut) =>
      'Search words or translations  ($shortcut)';
  @override
  String get searchHintShort => 'Search words';
  @override
  String get sortAZ => 'A–Z';
  @override
  String get sortZA => 'Z–A';
  @override
  String get sortRecent => 'Recent';
  @override
  String get sortAZTooltip => 'Sort A to Z';
  @override
  String get sortZATooltip => 'Sort Z to A';
  @override
  String get sortRecentTooltip => 'Newest first';
  @override
  String get sortMenuAZ => 'A to Z';
  @override
  String get sortMenuZA => 'Z to A';
  @override
  String get sortTooltip => 'Sort';
  @override
  String get selectWords => 'Select words';
  @override
  String get doneSelecting => 'Done selecting';
  @override
  String get emptyTitle => 'Your dictionary is empty';
  @override
  String emptyMessage({required bool translation, required bool ai}) =>
      switch ((translation, ai)) {
        (true, true) =>
          "Add your first word — Cody will translate it and explain how it's "
              'used. Or start with a few examples.',
        (true, false) =>
          'Add your first word — Cody will translate it. Or start with a few '
              'examples.',
        (false, true) =>
          'Add your first word with its translation — Cody will explain how '
              "it's used. Or start with a few examples.",
        (false, false) =>
          'Add your first word with its translation, or start with a few '
              'examples.',
      };
  @override
  String get addFirstWord => 'Add your first word';
  @override
  String get addExamples => 'Add example words';
  @override
  String get noMatchesTitle => 'No matches';
  @override
  String noMatchesMessage(String query) =>
      'Nothing found for "$query". Try another spelling or add it as a new '
      'word.';
  @override
  String addQuery(String query) => 'Add "$query"';
  @override
  String get reorderBlockedSearch => 'Clear the search to reorder words.';
  @override
  String get reorderBlockedSort => 'Turn off sorting to reorder words.';

  // Banner
  @override
  String heroExplained(int n) => '$n explained by AI';
  @override
  String get heroAiOff => 'AI explanations off';
  @override
  String get heroStart => 'Start your dictionary';
  @override
  String get heroEyebrow => 'YOUR DICTIONARY';
  @override
  String get heroTitleEmpty => "Let's build your dictionary";
  @override
  String heroTitle(int n) => '${wordCount(n)} and counting';
  @override
  String get heroDirection => 'English → Russian';

  // Selection
  @override
  String get selectionDone => 'Done (Esc)';
  @override
  String selectedCount(int n) => '$n selected';
  @override
  String get selectAll => 'Select all';

  // Delete dialogs
  @override
  String get deleteWordTitle => 'Delete this word?';
  @override
  String deleteWordMessage(String word) =>
      '"$word" will be removed from your dictionary.';
  @override
  String deleteWordsTitle(int n) => 'Delete ${wordCount(n)}?';
  @override
  String get deleteWordsMessage =>
      'The selected words will be removed from your dictionary.';

  // Storage errors
  @override
  String get startEmptyTitle => 'Start with an empty dictionary?';
  @override
  String get startEmptyMessage =>
      'The damaged data is kept in a separate copy next to your dictionary, '
      'so nothing is deleted.';
  @override
  String get startEmpty => 'Start empty';
  @override
  String get cantOpenDictionary => "Can't open your dictionary";
  @override
  String wordsNotChanged(String reason) =>
      '$reason Your words were not changed.';
  @override
  String get dictionaryDamaged => 'Your dictionary file is damaged';
  @override
  String damagedWithBackup(String reason) =>
      '$reason You can restore the last good copy. The damaged data is kept '
      'aside, nothing is deleted.';
  @override
  String damagedNoBackup(String reason) =>
      '$reason No backup is available. The damaged data has not been changed.';
  @override
  String get restoreLastGood => 'Restore last good copy';
  @override
  String storageError(StorageException e) => e.message;

  // Card
  @override
  String get writingExplanation => 'Cody is writing an explanation…';
  @override
  String explanationFailed(String reason) =>
      'Explanation failed: $reason — open for details';
  @override
  String get noExplanation => 'No explanation';
  @override
  String get noExplanationTap => 'No explanation yet — tap to generate';

  // Sheet
  @override
  String get editWord => 'Edit word';
  @override
  String get quick => 'Quick';
  @override
  String get inDepth => 'In depth';
  @override
  String get quickExplanation => 'Quick explanation';
  @override
  String get inDepthExplanation => 'In-depth explanation';
  @override
  String get generateExplanation => 'Generate explanation';
  @override
  String get generateInDepth => 'Generate in-depth explanation';
  @override
  String get aiOffInSheet =>
      'AI explanations are off: no OpenAI key is set up. Your words are '
      'still saved.';
  @override
  String get noExplanationYet => 'No explanation yet.';
  @override
  String get codyExplains => 'Cody explains';
  @override
  String get copied => 'Copied';
  @override
  String get copy => 'Copy';
  @override
  String get regenerate => 'Regenerate';
  @override
  String get codyThinking => 'Cody is thinking…';

  // Failures
  @override
  String failureShortReason(Object error) => switch (error) {
    StorageException() => 'not saved',
    ServiceException(:final failure) => switch (failure) {
      ServiceFailure.notConfigured => 'AI is off',
      ServiceFailure.network => 'offline',
      ServiceFailure.timeout => 'timed out',
      ServiceFailure.unauthorized => 'API key rejected',
      ServiceFailure.quotaExceeded => 'no AI credit',
      ServiceFailure.rateLimited => 'AI is busy',
      ServiceFailure.server => 'AI service error',
      ServiceFailure.incomplete => 'answer cut off',
      ServiceFailure.refused => 'AI declined',
      ServiceFailure.rejected ||
      ServiceFailure.invalidResponse => 'unexpected answer',
    },
    _ => 'something went wrong',
  };

  @override
  String failureMessage(Object error) => switch (error) {
    StorageException() =>
      'The explanation was generated but could not be saved. '
          '${storageError(error)}',
    ServiceException() => '${serviceError(error)} ${_advice(error.failure)}',
    _ => 'Something went wrong. Try again.',
  };

  String _advice(ServiceFailure f) => switch (f) {
    ServiceFailure.notConfigured =>
      'Add an OpenAI API key to turn on explanations.',
    ServiceFailure.network => 'Check your internet connection, then try again.',
    ServiceFailure.timeout ||
    ServiceFailure.rateLimited ||
    ServiceFailure.server ||
    ServiceFailure.incomplete => 'Try again in a moment.',
    ServiceFailure.unauthorized => 'Check the OpenAI API key in the .env file.',
    ServiceFailure.quotaExceeded =>
      'Add credit to the OpenAI account, then try again.',
    ServiceFailure.refused ||
    ServiceFailure.rejected ||
    ServiceFailure.invalidResponse =>
      'Try again; if it keeps failing, check the spelling of the word.',
  };

  @override
  String serviceError(ServiceException e) => e.message;

  // Editor
  @override
  String notTranslated(String reason) =>
      'Not translated: $reason Type a translation or save without one.';
  @override
  String get enterWordFirst => 'Enter a word first';
  @override
  String get wordExists => 'This word already exists in this vocabulary';
  @override
  String editorSubtitle({required bool translation, required bool ai}) =>
      switch ((translation, ai)) {
        (true, true) => 'Cody will translate and explain it for you.',
        (true, false) => 'Cody will translate it. AI explanations are off.',
        (false, true) => 'Type the translation; Cody will explain the word.',
        (false, false) => 'Local mode: type the translation yourself.',
      };
  @override
  String get addAWord => 'Add a word';
  @override
  String get english => 'English';
  @override
  String get englishHint => 'e.g. serendipity';
  @override
  String get russian => 'Russian';
  @override
  String get russianAutoHint => 'Filled in automatically';
  @override
  String get russianTypeHint => 'Type a translation';
  @override
  String get autoTranslate => 'Auto-translate';
  @override
  String get autoTranslateOn => 'Translate with DeepL as you type';
  @override
  String get autoTranslateUnavailable => 'DeepL is not set up in this app';
  @override
  String get translating => 'Translating…';
  @override
  String get saving => 'Saving…';
  @override
  String get saveWithoutTranslation => 'Save without translation';
  @override
  String get saveChanges => 'Save changes';

  // Toast
  @override
  String get wordAdded => 'Word added!';
  @override
  String get savedToDictionary => 'Saved to your dictionary';
  @override
  String wordInDictionary(String word) => '"$word" is in your dictionary';

  // Word menu
  @override
  String get explain => 'Explain';
  @override
  String get vocabulariesMenu => 'Vocabularies…';

  // Vocabularies
  @override
  String get editVocabulary => 'Edit vocabulary';
  @override
  String get newVocabulary => 'New vocabulary';
  @override
  String get vocabDialogSubtitle =>
      'Group related words into a themed collection.';
  @override
  String get name => 'Name';
  @override
  String get nameHint => 'e.g. Travel phrases';
  @override
  String get nameRequired => 'Please enter a name';
  @override
  String get descriptionOptional => 'Description (optional)';
  @override
  String get icon => 'Icon';
  @override
  String get deleteVocabTitle => 'Delete vocabulary?';
  @override
  String deleteVocabMessage(String name, int wordsStaying) => wordsStaying == 0
      ? '"$name" will be removed.'
      : '"$name" will be removed. Its ${wordCount(wordsStaying)} '
            '${wordsStaying == 1 ? 'stays' : 'stay'} in your dictionary.';
  @override
  String vocabDeleted(String name) => '"$name" deleted.';
  @override
  String get vocabsSubtitleEmpty => 'Organize words into themed collections';
  @override
  String get cantOpenVocabs => "Can't open your vocabularies";
  @override
  String nothingChanged(String reason) => '$reason Nothing was changed.';
  @override
  String get noVocabsTitle => 'No vocabularies yet';
  @override
  String get noVocabsMessage =>
      'Create collections like "Travel" or "Work" to keep related words '
      'together.';
  @override
  String get createVocab => 'Create a vocabulary';
  @override
  String get noDescription => 'No description';
  @override
  String removedFromVocab(String word) =>
      '"$word" removed from the collection.';
  @override
  String get vocabGoneTitle => 'This vocabulary no longer exists';
  @override
  String get vocabGoneMessage => 'It was deleted.';
  @override
  String get noWordsHereTitle => 'No words here yet';
  @override
  String get noWordsHereMessage =>
      'Add words from your dictionary. A word can be in several vocabularies.';
  @override
  String get addWords => 'Add words';
  @override
  String get removeFromVocab => 'Remove from vocabulary';
  @override
  String chooseWhere(String word) => 'Choose where "$word" belongs.';
  @override
  String get noVocabsCreateOne =>
      'No vocabularies yet. Create one on the Vocabularies tab.';
  @override
  String get pickerDictionaryEmpty =>
      'Your dictionary is empty. Add words in the Dictionary first.';
  @override
  String get pickerAllAdded =>
      'Every dictionary word is already in this vocabulary.';
  @override
  String pickerNoMatch(String query) => 'No words match "$query".';
  @override
  String addNWords(int n) => n <= 1 ? 'Add word' : 'Add $n words';

  // Backup
  @override
  String backupSaved(String location) => 'Backup saved: $location';
  @override
  String notCopied(String reason) => 'Not copied: $reason';
  @override
  String get backupCopied =>
      'Backup copied. Paste it somewhere safe, or into Codictionary on '
      'another device.';
  @override
  String get clipboardEmpty => 'The clipboard is empty. Copy a backup first.';
  @override
  String couldNotRead(String name, String reason) =>
      'Could not read $name: $reason';
  @override
  String invalidBackup(String reason) =>
      'This is not a valid backup: $reason Nothing was changed.';
  @override
  String get currentUnreadable =>
      'Your current data cannot be read, so it cannot be backed up before '
      'restoring. Use the recovery options on the Dictionary tab first.';
  @override
  String get replaceTitle => 'Replace your dictionary?';
  @override
  String replaceMessage(String date, String backup, String current) =>
      'Backup from $date: $backup.\nIt replaces your current $current. A '
      'safety copy of the current data is saved first.';
  @override
  String get replace => 'Replace';
  @override
  String restored(String count, String location) =>
      'Restored $count. Safety copy: $location';
  @override
  String notRestored(String reason) => 'Not restored: $reason';
  @override
  String get backupTitle => 'Backup';
  @override
  String get backupSubtitle => 'Save your words or move them to another device';
  @override
  String get backUpTitle => 'Back up your dictionary';
  @override
  String backUpText(String count) =>
      '$count, with explanations, dates and your own order.';
  @override
  String get readingData => 'Reading your data…';
  @override
  String get saveBackupFile => 'Save backup file';
  @override
  String get copyToClipboard => 'Copy to clipboard';
  @override
  String get restoreTitle => 'Restore from a backup';
  @override
  String get restoreText =>
      'Restoring replaces your current dictionary and vocabularies. A safety '
      'copy of the current data is saved first.';
  @override
  String get pasteFromClipboard => 'Paste from clipboard';
  @override
  String get openFile => 'Open file…';
  @override
  String get backupsOnDevice => 'Backups on this device';
  @override
  String get restore => 'Restore';
  @override
  String backupProblem(BackupFormatException e) => e.message;
}
