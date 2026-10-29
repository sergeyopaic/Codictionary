import '../data/remote/deepl_translator.dart';
import '../data/remote/openai_explainer.dart';
import '../data/repositories/vocabulary_repository_impl.dart';
import '../data/repositories/word_repository_impl.dart';
import '../data/storage/create_storage_service.dart';
import '../domain/services/translator.dart';
import '../domain/services/word_explainer.dart';
import '../domain/usecases/add_word.dart';
import '../domain/usecases/explain_word.dart';
import '../domain/usecases/get_all_words.dart';
import '../domain/usecases/get_vocabularies.dart';
import '../domain/usecases/manage_vocabularies.dart';
import '../domain/usecases/recover_words.dart';
import '../domain/usecases/remove_word.dart';
import '../domain/usecases/reorder_words.dart';
import '../domain/usecases/restore_word.dart';
import '../domain/usecases/translate_word.dart';
import '../domain/usecases/update_word.dart';
import '../presentation/app_scope.dart';
import 'app_config.dart';

/// The only place that connects domain contracts to data implementations.
///
/// [buildUseCases] wires a given storage and external services (tests pass
/// fakes); [buildProductionUseCases] adds the real platform storage and API
/// clients. Each call builds an independent object graph: no global state.
AppUseCases buildUseCases({
  required StorageService storage,
  required WordExplainer explainer,
  required Translator translator,
}) {
  // One repository instance per storage: it serializes read–modify–write.
  final words = WordRepositoryImpl(storage);
  final vocabularies = VocabularyRepositoryImpl(storage);
  return AppUseCases(
    getAllWords: GetAllWords(words),
    addWord: AddWord(words),
    updateWord: UpdateWord(words),
    restoreWord: RestoreWord(words),
    removeWord: RemoveWord(words),
    reorderWords: ReorderWords(words),
    recoverWords: RecoverWords(words),
    explainWord: ExplainWord(explainer),
    translateWord: TranslateWord(translator),
    getVocabularies: GetVocabularies(vocabularies),
    createVocabulary: CreateVocabulary(vocabularies),
    updateVocabulary: UpdateVocabulary(vocabularies),
    deleteVocabulary: DeleteVocabulary(vocabularies),
    restoreVocabulary: RestoreVocabulary(vocabularies),
    setWordInVocabulary: SetWordInVocabulary(vocabularies),
  );
}

AppUseCases buildProductionUseCases(AppConfig config) => buildUseCases(
  storage: createStorageService(),
  explainer: OpenAiExplainer(config.openAiApiKey),
  translator: DeepLTranslator(config.deeplApiKey),
);
