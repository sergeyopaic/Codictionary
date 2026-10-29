export 'storage_service.dart';
import 'package:codictionary/data/storage/storage_service.dart';

import 'storage_io.dart' if (dart.library.html) 'storage_web.dart' as platform;

StorageService createStorageService() => platform.createStorageService();
