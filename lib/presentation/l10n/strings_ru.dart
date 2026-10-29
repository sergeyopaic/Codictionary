import 'package:flutter/widgets.dart';

import '../../domain/exceptions/backup_exceptions.dart';
import '../../domain/exceptions/service_exceptions.dart';
import '../../domain/exceptions/storage_exceptions.dart';
import 'app_strings.dart';

/// Russian interface. "Vocabularies" are called «коллекции» so they are not
/// confused with «словарь» (all words).
class RuStrings extends AppStrings {
  const RuStrings();

  @override
  Locale get locale => const Locale('ru');

  String _words(int n) => '$n ${ruPlural(n, 'слово', 'слова', 'слов')}';
  String _collections(int n) =>
      '$n ${ruPlural(n, 'коллекция', 'коллекции', 'коллекций')}';

  // Common
  @override
  String get cancel => 'Отмена';
  @override
  String get delete => 'Удалить';
  @override
  String get undo => 'Вернуть';
  @override
  String get tryAgain => 'Повторить';
  @override
  String get done => 'Готово';
  @override
  String get save => 'Сохранить';
  @override
  String get create => 'Создать';
  @override
  String get edit => 'Изменить';
  @override
  String get close => 'Закрыть';
  @override
  String get clear => 'Очистить';
  @override
  String get options => 'Действия';
  @override
  String get moreOptions => 'Ещё действия';
  @override
  String get untitled => 'Без названия';
  @override
  String notSaved(String reason) => 'Не сохранено: $reason';
  @override
  String wordCount(int n) => _words(n);
  @override
  String vocabularyCount(int n) => _collections(n);
  @override
  String collectionCount(int n) => _collections(n);
  @override
  String snapshotCount(int words, int vocabularies) =>
      '${_words(words)} и ${_collections(vocabularies)}';

  // Shell
  @override
  String get navDictionary => 'Словарь';
  @override
  String get navVocabularies => 'Коллекции';
  @override
  String get navBackup => 'Копии';
  @override
  String get library => 'БИБЛИОТЕКА';
  @override
  String get tipTitle => 'Совет';
  @override
  String tipBody(String addShortcut) =>
      'Удерживайте карточку, чтобы перетащить её. $addShortcut — добавить '
      'слово.';
  @override
  String get themeLight => 'Светлая';
  @override
  String get themeSystem => 'Как в системе';
  @override
  String get themeDark => 'Тёмная';
  @override
  String get themeFollowsSystem => 'Тема: как в системе';
  @override
  String get themeIsLight => 'Тема: светлая';
  @override
  String get themeIsDark => 'Тема: тёмная';

  // Dictionary
  @override
  String get wordUpdated => 'Слово изменено.';
  @override
  String wordDeleted(String word) => '«$word» удалено.';
  @override
  String wordsDeleted(int n) => 'Удалено: ${_words(n)}.';
  @override
  String get addWord => 'Добавить слово';
  @override
  String addWordTooltip(String shortcut) => 'Добавить слово ($shortcut)';
  @override
  String searchHintLong(String shortcut) =>
      'Поиск по словам и переводам  ($shortcut)';
  @override
  String get searchHintShort => 'Поиск слов';
  @override
  String get sortAZ => 'A–Z';
  @override
  String get sortZA => 'Z–A';
  @override
  String get sortRecent => 'Новые';
  @override
  String get sortAZTooltip => 'По алфавиту, A → Z';
  @override
  String get sortZATooltip => 'По алфавиту, Z → A';
  @override
  String get sortRecentTooltip => 'Сначала новые';
  @override
  String get sortMenuAZ => 'От A до Z';
  @override
  String get sortMenuZA => 'От Z до A';
  @override
  String get sortTooltip => 'Сортировка';
  @override
  String get selectWords => 'Выбрать слова';
  @override
  String get doneSelecting => 'Закончить выбор';
  @override
  String get emptyTitle => 'Словарь пока пуст';
  @override
  String emptyMessage({required bool translation, required bool ai}) =>
      switch ((translation, ai)) {
        (true, true) =>
          'Добавьте первое слово — Cody переведёт его и объяснит, как оно '
              'употребляется. Или начните с примеров.',
        (true, false) =>
          'Добавьте первое слово — Cody переведёт его. Или начните с '
              'примеров.',
        (false, true) =>
          'Добавьте первое слово с переводом — Cody объяснит, как оно '
              'употребляется. Или начните с примеров.',
        (false, false) =>
          'Добавьте первое слово с переводом или начните с примеров.',
      };
  @override
  String get addFirstWord => 'Добавить первое слово';
  @override
  String get addExamples => 'Добавить примеры';
  @override
  String get noMatchesTitle => 'Ничего не найдено';
  @override
  String noMatchesMessage(String query) =>
      'По запросу «$query» ничего нет. Проверьте написание или добавьте '
      'его как новое слово.';
  @override
  String addQuery(String query) => 'Добавить «$query»';
  @override
  String get reorderBlockedSearch =>
      'Очистите поиск, чтобы менять порядок слов.';
  @override
  String get reorderBlockedSort =>
      'Выключите сортировку, чтобы менять порядок слов.';

  // Banner
  @override
  String heroExplained(int n) => 'объяснено AI: $n';
  @override
  String get heroAiOff => 'AI-объяснения выключены';
  @override
  String get heroStart => 'Начните свой словарь';
  @override
  String get heroEyebrow => 'ВАШ СЛОВАРЬ';
  @override
  String get heroTitleEmpty => 'Соберём ваш словарь';
  @override
  String heroTitle(int n) => '${_words(n)} и дальше больше';
  @override
  String get heroDirection => 'Английский → русский';

  // Selection
  @override
  String get selectionDone => 'Готово (Esc)';
  @override
  String selectedCount(int n) => 'Выбрано: $n';
  @override
  String get selectAll => 'Выбрать все';

  // Delete dialogs
  @override
  String get deleteWordTitle => 'Удалить это слово?';
  @override
  String deleteWordMessage(String word) => '«$word» будет удалено из словаря.';
  @override
  String deleteWordsTitle(int n) => 'Удалить ${_words(n)}?';
  @override
  String get deleteWordsMessage => 'Выбранные слова будут удалены из словаря.';

  // Storage errors
  @override
  String get startEmptyTitle => 'Начать с пустого словаря?';
  @override
  String get startEmptyMessage =>
      'Повреждённые данные останутся отдельной копией рядом со словарём — '
      'ничего не удаляется.';
  @override
  String get startEmpty => 'Начать с пустого';
  @override
  String get cantOpenDictionary => 'Не удаётся открыть словарь';
  @override
  String wordsNotChanged(String reason) => '$reason Ваши слова не изменены.';
  @override
  String get dictionaryDamaged => 'Файл словаря повреждён';
  @override
  String damagedWithBackup(String reason) =>
      '$reason Можно вернуть последнюю исправную копию. Повреждённые данные '
      'сохранятся отдельно, ничего не удаляется.';
  @override
  String damagedNoBackup(String reason) =>
      '$reason Резервной копии нет. Повреждённые данные не изменены.';
  @override
  String get restoreLastGood => 'Вернуть исправную копию';
  @override
  String storageError(StorageException e) => switch (e) {
    StorageUnavailableException() =>
      'Не удалось прочитать сохранённые данные (нет доступа или ошибка '
          'диска).',
    StorageCorruptedException(:final hasBackup) =>
      hasBackup
          ? 'Сохранённые данные повреждены или пропали, но есть резервная '
                'копия.'
          : 'Сохранённые данные повреждены и не читаются.',
    StorageWriteException(:final quotaExceeded) =>
      quotaExceeded
          ? 'Хранилище переполнено. Освободите место и попробуйте снова.'
          : 'Не удалось сохранить изменения (диск заполнен или нет '
                'доступа).',
  };

  // Card
  @override
  String get writingExplanation => 'Cody пишет объяснение…';
  @override
  String explanationFailed(String reason) =>
      'Объяснение не получено: $reason — откройте, чтобы узнать подробности';
  @override
  String get noExplanation => 'Без объяснения';
  @override
  String get noExplanationTap => 'Объяснения пока нет — нажмите, чтобы создать';

  // Sheet
  @override
  String get editWord => 'Изменить слово';
  @override
  String get quick => 'Кратко';
  @override
  String get inDepth => 'Подробно';
  @override
  String get quickExplanation => 'Краткое объяснение';
  @override
  String get inDepthExplanation => 'Подробное объяснение';
  @override
  String get generateExplanation => 'Создать объяснение';
  @override
  String get generateInDepth => 'Создать подробное объяснение';
  @override
  String get aiOffInSheet =>
      'AI-объяснения выключены: ключ OpenAI не настроен. Слова при этом '
      'сохраняются.';
  @override
  String get noExplanationYet => 'Объяснения пока нет.';
  @override
  String get codyExplains => 'Cody объясняет';
  @override
  String get copied => 'Скопировано';
  @override
  String get copy => 'Копировать';
  @override
  String get regenerate => 'Создать заново';
  @override
  String get codyThinking => 'Cody думает…';

  // Failures
  @override
  String failureShortReason(Object error) => switch (error) {
    StorageException() => 'не сохранено',
    ServiceException(:final failure) => switch (failure) {
      ServiceFailure.notConfigured => 'AI выключен',
      ServiceFailure.network => 'нет сети',
      ServiceFailure.timeout => 'нет ответа',
      ServiceFailure.unauthorized => 'ключ API отклонён',
      ServiceFailure.quotaExceeded => 'нет средств на AI',
      ServiceFailure.rateLimited => 'AI перегружен',
      ServiceFailure.server => 'сбой AI-сервиса',
      ServiceFailure.incomplete => 'ответ оборвался',
      ServiceFailure.refused => 'AI отказался',
      ServiceFailure.rejected ||
      ServiceFailure.invalidResponse => 'непонятный ответ',
    },
    _ => 'что-то пошло не так',
  };

  @override
  String failureMessage(Object error) => switch (error) {
    StorageException() =>
      'Объяснение получено, но не сохранилось. ${storageError(error)}',
    ServiceException() => '${serviceError(error)} ${_advice(error.failure)}',
    _ => 'Что-то пошло не так. Попробуйте ещё раз.',
  };

  String _advice(ServiceFailure f) => switch (f) {
    ServiceFailure.notConfigured =>
      'Добавьте ключ OpenAI API, чтобы включить объяснения.',
    ServiceFailure.network =>
      'Проверьте подключение к интернету и попробуйте снова.',
    ServiceFailure.timeout ||
    ServiceFailure.rateLimited ||
    ServiceFailure.server ||
    ServiceFailure.incomplete => 'Попробуйте ещё раз чуть позже.',
    ServiceFailure.unauthorized => 'Проверьте ключ OpenAI API в файле .env.',
    ServiceFailure.quotaExceeded => 'Пополните счёт OpenAI и попробуйте снова.',
    ServiceFailure.refused ||
    ServiceFailure.rejected ||
    ServiceFailure.invalidResponse =>
      'Попробуйте ещё раз; если не поможет — проверьте написание слова.',
  };

  @override
  String serviceError(ServiceException e) {
    final s = e.service;
    return switch (e.failure) {
      ServiceFailure.notConfigured => '$s не настроен в приложении.',
      ServiceFailure.network =>
        'Не удалось связаться с $s. Проверьте подключение к интернету.',
      ServiceFailure.timeout => '$s не ответил вовремя.',
      ServiceFailure.unauthorized => '$s отклонил ключ API.',
      ServiceFailure.quotaExceeded =>
        'На счёте $s закончились средства или лимит.',
      ServiceFailure.rateLimited =>
        '$s сейчас перегружен. Попробуйте чуть позже.',
      ServiceFailure.server => 'У $s сбой на сервере. Попробуйте позже.',
      ServiceFailure.rejected => '$s не смог обработать запрос.',
      ServiceFailure.invalidResponse =>
        '$s вернул ответ, который приложение не смогло прочитать.',
      ServiceFailure.incomplete => '$s не закончил ответ.',
      ServiceFailure.refused => '$s отказался отвечать.',
    };
  }

  // Editor
  @override
  String notTranslated(String reason) =>
      'Не переведено: $reason Введите перевод сами или сохраните без него.';
  @override
  String get enterWordFirst => 'Сначала введите слово';
  @override
  String get wordExists => 'Это слово уже есть в словаре';
  @override
  String editorSubtitle({required bool translation, required bool ai}) =>
      switch ((translation, ai)) {
        (true, true) => 'Cody переведёт и объяснит его.',
        (true, false) => 'Cody переведёт его. AI-объяснения выключены.',
        (false, true) => 'Введите перевод — Cody объяснит слово.',
        (false, false) => 'Локальный режим: перевод вводится вручную.',
      };
  @override
  String get addAWord => 'Новое слово';
  @override
  String get english => 'По-английски';
  @override
  String get englishHint => 'например, serendipity';
  @override
  String get russian => 'Перевод';
  @override
  String get russianAutoHint => 'Заполнится автоматически';
  @override
  String get russianTypeHint => 'Введите перевод';
  @override
  String get autoTranslate => 'Автоперевод';
  @override
  String get autoTranslateOn => 'Переводить через DeepL по мере ввода';
  @override
  String get autoTranslateUnavailable => 'DeepL не настроен в приложении';
  @override
  String get translating => 'Перевожу…';
  @override
  String get saving => 'Сохраняю…';
  @override
  String get saveWithoutTranslation => 'Сохранить без перевода';
  @override
  String get saveChanges => 'Сохранить';

  // Toast
  @override
  String get wordAdded => 'Слово добавлено!';
  @override
  String get savedToDictionary => 'Сохранено в словаре';
  @override
  String wordInDictionary(String word) => '«$word» теперь в словаре';

  // Word menu
  @override
  String get explain => 'Объяснение';
  @override
  String get vocabulariesMenu => 'Коллекции…';

  // Vocabularies
  @override
  String get editVocabulary => 'Изменить коллекцию';
  @override
  String get newVocabulary => 'Новая коллекция';
  @override
  String get vocabDialogSubtitle =>
      'Соберите связанные слова в тематическую '
      'подборку.';
  @override
  String get name => 'Название';
  @override
  String get nameHint => 'например, Путешествия';
  @override
  String get nameRequired => 'Введите название';
  @override
  String get descriptionOptional => 'Описание (необязательно)';
  @override
  String get icon => 'Значок';
  @override
  String get deleteVocabTitle => 'Удалить коллекцию?';
  @override
  String deleteVocabMessage(String name, int wordsStaying) => wordsStaying == 0
      ? '«$name» будет удалена.'
      : '«$name» будет удалена. Её ${_words(wordsStaying)} останутся в '
            'словаре.';
  @override
  String vocabDeleted(String name) => '«$name» удалена.';
  @override
  String get vocabsSubtitleEmpty => 'Собирайте слова в тематические подборки';
  @override
  String get cantOpenVocabs => 'Не удаётся открыть коллекции';
  @override
  String nothingChanged(String reason) => '$reason Ничего не изменено.';
  @override
  String get noVocabsTitle => 'Коллекций пока нет';
  @override
  String get noVocabsMessage =>
      'Создайте подборки вроде «Путешествия» или «Работа», чтобы держать '
      'связанные слова вместе.';
  @override
  String get createVocab => 'Создать коллекцию';
  @override
  String get noDescription => 'Без описания';
  @override
  String removedFromVocab(String word) => '«$word» убрано из коллекции.';
  @override
  String get vocabGoneTitle => 'Этой коллекции больше нет';
  @override
  String get vocabGoneMessage => 'Она была удалена.';
  @override
  String get noWordsHereTitle => 'Здесь пока нет слов';
  @override
  String get noWordsHereMessage =>
      'Добавьте слова из словаря. Одно слово может быть в нескольких '
      'коллекциях.';
  @override
  String get addWords => 'Добавить слова';
  @override
  String get removeFromVocab => 'Убрать из коллекции';
  @override
  String chooseWhere(String word) => 'Выберите, куда отнести «$word».';
  @override
  String get noVocabsCreateOne =>
      'Коллекций пока нет. Создайте их на вкладке «Коллекции».';
  @override
  String get pickerDictionaryEmpty =>
      'Словарь пуст. Сначала добавьте слова в словарь.';
  @override
  String get pickerAllAdded => 'Все слова словаря уже в этой коллекции.';
  @override
  String pickerNoMatch(String query) => 'Нет слов по запросу «$query».';
  @override
  String addNWords(int n) =>
      n <= 1 ? 'Добавить слово' : 'Добавить ${_words(n)}';

  // Backup
  @override
  String backupSaved(String location) => 'Копия сохранена: $location';
  @override
  String notCopied(String reason) => 'Не скопировано: $reason';
  @override
  String get backupCopied =>
      'Копия в буфере обмена. Вставьте её в надёжное место или в '
      'Codictionary на другом устройстве.';
  @override
  String get clipboardEmpty =>
      'Буфер обмена пуст. Сначала скопируйте резервную копию.';
  @override
  String couldNotRead(String name, String reason) =>
      'Не удалось прочитать $name: $reason';
  @override
  String invalidBackup(String reason) =>
      'Это не подходящая резервная копия: $reason Ничего не изменено.';
  @override
  String get currentUnreadable =>
      'Текущие данные не читаются, поэтому их нельзя сохранить перед '
      'восстановлением. Сначала воспользуйтесь восстановлением на вкладке '
      '«Словарь».';
  @override
  String get replaceTitle => 'Заменить словарь?';
  @override
  String replaceMessage(String date, String backup, String current) =>
      'Копия от $date: $backup.\nОна заменит текущие $current. Перед этим '
      'текущие данные сохранятся в страховочную копию.';
  @override
  String get replace => 'Заменить';
  @override
  String restored(String count, String location) =>
      'Восстановлено: $count. Страховочная копия: $location';
  @override
  String notRestored(String reason) => 'Не восстановлено: $reason';
  @override
  String get backupTitle => 'Резервные копии';
  @override
  String get backupSubtitle =>
      'Сохраните слова или перенесите их на другое устройство';
  @override
  String get backUpTitle => 'Сохранить копию словаря';
  @override
  String backUpText(String count) =>
      '$count — с объяснениями, датами и вашим порядком.';
  @override
  String get readingData => 'Читаю данные…';
  @override
  String get saveBackupFile => 'Сохранить в файл';
  @override
  String get copyToClipboard => 'Скопировать в буфер';
  @override
  String get restoreTitle => 'Восстановить из копии';
  @override
  String get restoreText =>
      'Восстановление заменяет текущий словарь и коллекции. Перед этим '
      'текущие данные сохраняются в страховочную копию.';
  @override
  String get pasteFromClipboard => 'Вставить из буфера';
  @override
  String get openFile => 'Открыть файл…';
  @override
  String get backupsOnDevice => 'Копии на этом устройстве';
  @override
  String get restore => 'Восстановить';

  @override
  String backupProblem(BackupFormatException e) {
    final where = switch (e.item) {
      'word' => 'Слово №${e.index}',
      'vocabulary' => 'Коллекция №${e.index}',
      _ => 'Копия',
    };
    final f = e.field;
    return switch (e.problem) {
      BackupProblem.notJson =>
        'Текст не является JSON. Скопируйте копию целиком и попробуйте снова.',
      BackupProblem.notBackup => 'Это не резервная копия Codictionary.',
      BackupProblem.noVersion => 'У копии нет корректной версии.',
      BackupProblem.newerVersion =>
        'Копия сделана более новой версией Codictionary (формат ${e.value}). '
            'Обновите приложение, чтобы её восстановить.',
      BackupProblem.missingList => 'Нет раздела «$f».',
      BackupProblem.notObject => '$where: неверная запись.',
      BackupProblem.missingField => '$where: нет поля «$f».',
      BackupProblem.emptyField => '$where: пустое поле «$f».',
      BackupProblem.notText => '$where: поле «$f» должно быть текстом.',
      BackupProblem.notDate => '$where: в поле «$f» не дата.',
      BackupProblem.duplicateWordId =>
        'Повторяется идентификатор слова «${e.value}».',
      BackupProblem.duplicateWord => '«${e.value}» встречается дважды.',
      BackupProblem.duplicateVocabularyId =>
        'Повторяется идентификатор коллекции «${e.value}».',
      BackupProblem.membersNotList =>
        '$where: список слов («wordIds») записан неверно.',
      BackupProblem.memberTwice => '$where: одно слово указано дважды.',
      BackupProblem.unknownMember =>
        '$where ссылается на слово, которого нет в копии («${e.value}»).',
    };
  }
}
