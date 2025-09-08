export 'storage/storage_interface.dart';
import 'package:codictionary/services/storage/storage_interface.dart';

import 'storage/storage_io.dart'
    if (dart.library.html) 'storage/storage_web.dart'
    as platform;

StorageService createStorageService() => platform.createStorageService();
