import 'package:codictionary/core/di/service_locator.dart';
import 'package:codictionary/data/repositories/word_repository_impl.dart';
import 'package:codictionary/domain/repositories/word_repository.dart';
import 'package:codictionary/domain/usecases/add_word.dart';
import 'package:codictionary/domain/usecases/get_all_words.dart';
import 'package:codictionary/domain/usecases/recover_words.dart';
import 'package:codictionary/domain/usecases/remove_word.dart';
import 'package:codictionary/domain/usecases/restore_word.dart';
import 'package:codictionary/domain/usecases/update_word.dart';
import 'package:codictionary/services/storage/storage_interface.dart' as legacy;
import 'package:codictionary/services/storage_service.dart' as selector;

Future<void> registerInitialDependencies() async {
  registerInitialDependenciesSync();
}

void registerInitialDependenciesSync() {
  final legacy.StorageService storage = selector.createStorageService();

  if (!sl.isRegistered<legacy.StorageService>()) {
    sl.registerLazySingleton<legacy.StorageService>(() => storage);
  }
  if (!sl.isRegistered<WordRepository>()) {
    sl.registerLazySingleton<WordRepository>(() => WordRepositoryImpl(sl()));
  }
  if (!sl.isRegistered<AddWord>()) {
    sl.registerFactory<AddWord>(() => AddWord(sl()));
  }
  if (!sl.isRegistered<GetAllWords>()) {
    sl.registerFactory<GetAllWords>(() => GetAllWords(sl()));
  }
  if (!sl.isRegistered<RemoveWord>()) {
    sl.registerFactory<RemoveWord>(() => RemoveWord(sl()));
  }
  if (!sl.isRegistered<UpdateWord>()) {
    sl.registerFactory<UpdateWord>(() => UpdateWord(sl()));
  }
  if (!sl.isRegistered<RecoverWords>()) {
    sl.registerFactory<RecoverWords>(() => RecoverWords(sl()));
  }
  if (!sl.isRegistered<RestoreWord>()) {
    sl.registerFactory<RestoreWord>(() => RestoreWord(sl()));
  }
}
