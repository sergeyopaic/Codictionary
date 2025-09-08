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

// ====== ?РїС—Р…?РїС—Р…????NРїС—Р…?РїС—Р… ???? N??????РїС—Р…NРїС—Р…?РїС—Р…????NZ ======
const List<Word> _defaultWords = [
  Word(id: '1', eng: 'apple', rus: 'N??РїС—Р…?РїС—Р…??????'),
  Word(id: '2', eng: 'dog', rus: 'N????РїС—Р…?РїС—Р…???РїС—Р…'),
  Word(id: '3', eng: 'house', rus: '??????'),
];

// ====== ?YNРїС—Р…???РїС—Р…???РїС—Р…?РїС—Р…?????РїС—Р… ======
Future<void> main() async {
  // ???РїС—Р…N??РїС—Р…?РїС—Р…NРїС—Р…?РїС—Р…?РїС—Р…N????? ??N??РїС—Р…???? ??NРїС—Р…?РїС—Р…???РїС—Р…NРїС—Р…N?, NРїС—Р…NРїС—Р…???РїС—Р…NРїС—Р… ??????NРїС—Р…???РїС—Р…?РїС—Р…???РїС—Р…??NРїС—Р…?????РїС—Р…NРїС—Р…N? ?РїС—Р…?????????????? Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // ?РїС—Р…?РїС—Р…??NРїС—Р…N??РїС—Р…?РїС—Р…?РїС—Р…?? ???РїС—Р…NРїС—Р…?РїС—Р…???РїС—Р…????NРїС—Р…?РїС—Р… ???РїС—Р… .env
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

void showAddedWordPopup(BuildContext context) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  final entry = OverlayEntry(
    builder: (context) =>
        Positioned(right: 16, bottom: 80, child: _AnimatedPopup()),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    try {
      overlay.insert(entry);
      Future.delayed(const Duration(seconds: 2), () {
        entry.remove();
      });
    } catch (_) {}
  });
}

class _AnimatedPopup extends StatefulWidget {
  @override
  State<_AnimatedPopup> createState() => _AnimatedPopupState();
}

class _AnimatedPopupState extends State<_AnimatedPopup>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip
            .none, // NРїС—Р…NРїС—Р…???РїС—Р…NРїС—Р… gif ?????? ??NРїС—Р…?РїС—Р…?РїС—Р…?РїС—Р…?РїС—Р…NРїС—Р…N? ?РїС—Р…?РїС—Р… ??NРїС—Р…?РїС—Р…???РїС—Р…?РїС—Р…NРїС—Р…
        children: [
          // ?????РїС—Р…NРїС—Р…?РїС—Р…?РїС—Р…?РїС—Р… ???РїС—Р…NРїС—Р…NРїС—Р…??NРїС—Р…???РїС—Р…
          Card(
            color: Colors.green.shade300,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.check, color: Colors.white),
                  SizedBox(width: 8),
                  Text("Word added!", style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ),

          // ?Y??NРїС—Р…???? ????NРїС—Р…???РїС—Р… (???????РїС—Р…NРїС—Р…NРїС—Р… ???РїС—Р…NРїС—Р…NРїС—Р…??NРїС—Р…????)
          Positioned(
            top: -60,
            child: Image.asset("lib/media/clap_up.gif", width: 80, height: 80),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

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
    return MaterialApp(
      title: 'Codictionary',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: DictionaryScreen(
        gpt: gpt,
        translate: translate,
        storage: storage,
        defaultWords: defaultWords,
      ),
    );
  }
}
