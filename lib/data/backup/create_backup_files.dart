import '../../domain/services/backup_files.dart';
import 'backup_files_io.dart'
    if (dart.library.html) 'backup_files_web.dart'
    as platform;

BackupFiles createBackupFiles() => platform.createBackupFiles();
