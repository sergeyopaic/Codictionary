import 'package:flutter/widgets.dart';

import 'composition/app_config.dart';
import 'composition/app_dependencies.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await AppConfig.load();
  final useCases = buildProductionUseCases(config);
  // Read before the first frame so the saved theme applies without a flash.
  final settings = await useCases.loadSettings();
  runApp(CodictionaryApp(useCases: useCases, initialSettings: settings));
}
