import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'models/word.dart';
import 'services/gpt_service.dart';
import 'services/storage_service.dart';
import 'services/translate_service.dart';
import 'presentation/screens/dictionary_screen.dart';

late String? apiKey;
late String? deeplApiKey;

late final GptService gpt;
late final TranslateService translate;
late final StorageService storage;

final List<Word> _defaultWords = [
  Word(id: '1', eng: 'apple', rus: 'яблоко', addedAt: DateTime.now()),
  Word(id: '2', eng: 'dog', rus: 'собака', addedAt: DateTime.now()),
  Word(id: '3', eng: 'house', rus: 'дом', addedAt: DateTime.now()),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  apiKey = dotenv.env['OPENAI_API_KEY'];
  deeplApiKey = dotenv.env['DEEPL_API_KEY'];
  storage = createStorageService();
  gpt = GptService(apiKey ?? '');
  translate = TranslateService(deeplApiKey ?? '');

  runApp(
    MyApp(
      gpt: gpt,
      translate: translate,
      storage: storage,
      defaultWords: _defaultWords,
    ),
  );
}

/// Root widget that wires services and hosts the DictionaryScreen.
class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.gpt,
    required this.translate,
    required this.storage,
    required this.defaultWords,
  });

  final GptService gpt;
  final TranslateService translate;
  final StorageService storage;
  final List<Word> defaultWords;

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.blue,
        brightness: Brightness.light,
      ),
      useMaterial3: true,
    ).copyWith(scaffoldBackgroundColor: Colors.white);

    return MaterialApp(
      title: 'Codictionary',
      theme: theme,
      home: DictionaryScreen(
        gpt: gpt,
        translate: translate,
        storage: storage,
        defaultWords: defaultWords,
      ),
    );
  }
}
