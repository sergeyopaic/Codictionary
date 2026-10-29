import 'package:flutter/widgets.dart';

import 'composition/app_config.dart';
import 'composition/app_dependencies.dart';
import 'presentation/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = await AppConfig.load();
  runApp(CodictionaryApp(useCases: buildProductionUseCases(config)));
}
