import 'package:codictionary/core/di/service_locator.dart';
import 'package:codictionary/data/repositories/word_repository_impl.dart';
import 'package:codictionary/domain/repositories/word_repository.dart';
import 'package:codictionary/domain/usecases/add_word.dart';
import 'package:codictionary/services/storage/storage_interface.dart' as legacy;
import 'package:codictionary/services/storage_service.dart' as selector;

Future<void> registerInitialDependencies() async {
  final legacy.StorageService storage = selector.createStorageService();

  sl
    ..registerLazySingleton<legacy.StorageService>(() => storage)
    ..registerLazySingleton<WordRepository>(() => WordRepositoryImpl(sl()))
    ..registerFactory<AddWord>(() => AddWord(sl()));
}
