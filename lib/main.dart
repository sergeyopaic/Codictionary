import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';

import 'models/word.dart';
import 'services/gpt_service.dart';
import 'services/storage_service.dart';
import 'services/translate_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

late String? apiKey;
late String? deeplApiKey;

late final GptService gpt;
late final TranslateService translate;
late final StorageService storage;

Future<void> showGPTTestDialog(BuildContext context) async {
  final TextEditingController promptController = TextEditingController();
  String gptAnswer = "Waiting for response...";

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> sendPrompt() async {
            final prompt = promptController.text.trim();
            if (prompt.isEmpty) return;

            setState(() => gptAnswer = "Loading...");

            try {
              final text = await gpt.sendPrompt(prompt);
              setState(() => gptAnswer = text);
            } catch (e) {
              setState(() => gptAnswer = "Exception: $e");
            }
          }

          return AlertDialog(
            title: const Text("GPT Test"),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: promptController,
                    decoration: const InputDecoration(
                      labelText: "Enter prompt",
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(gptAnswer, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
              ElevatedButton(onPressed: sendPrompt, child: const Text("Send")),
            ],
          );
        },
      );
    },
  );
}

// ====== Данные по умолчанию ======
const List<Word> _defaultWords = [
  Word(id: '1', eng: 'apple', rus: 'яблоко'),
  Word(id: '2', eng: 'dog', rus: 'собака'),
  Word(id: '3', eng: 'house', rus: 'дом'),
];

// ====== Приложение ======
Future<void> main() async {
  // обязательно нужно вызвать, чтобы инициализировать биндинги Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // загружаем переменные из .env
  await dotenv.load(fileName: ".env");
  apiKey = dotenv.env['OPENAI_API_KEY'];
  deeplApiKey = dotenv.env['DEEPL_API_KEY'];
  storage = createStorageService();
  gpt = GptService(apiKey ?? '');
  translate = TranslateService(deeplApiKey ?? '');

  runApp(const MyApp());
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
        clipBehavior: Clip.none, // чтобы gif мог вылезать за пределы
        children: [
          // Сначала карточка
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

          // Потом гифка (поверх карточки)
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
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Codictionary',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const DictionaryScreen(),
    );
  }
}

class CodeDictionaryTitle extends StatelessWidget {
  const CodeDictionaryTitle({
    super.key,
    this.text = 'Codictionary',
    this.fontSize = 90, // размер шрифта в AppBar
    this.strokeWidth = 3.0, // толщина обводки
    this.strokeColor = const Color(0xCC000000),
    this.fillColor = Colors.white, // цвет заливки текста
    this.imagePath = 'assets/images/cody.png',
    this.gap = 8.0, // отступ между маскотом и текстом
    this.fontFamily, // 'CodictionaryCartoon' если добавил шрифт
  });

  final String text;
  final double fontSize;
  final double strokeWidth;
  final Color strokeColor;
  final Color fillColor;
  final String imagePath;
  final double gap;
  final String? fontFamily;

  @override
  Widget build(BuildContext context) {
    // высота картинки ≈ высоте текста (чуть больше, чтобы визуально совпало)
    final double imageHeight = fontSize * 1.15;

    final TextStyle base = TextStyle(
      fontSize: fontSize,
      height: 1.0, // плотнее посадка
      letterSpacing: 0.5,
      fontFamily: fontFamily, // 'CodictionaryCartoon' если подключил шрифт
      fontWeight: FontWeight.w700,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          imagePath,
          height: imageHeight,
          filterQuality: FilterQuality.high,
        ),
        SizedBox(width: gap),
        // Двойной текст: обводка + заливка
        Stack(
          children: [
            // Обводка
            Text(
              text,
              style: base.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = strokeWidth
                  ..color = strokeColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
            // Заливка
            Text(
              text,
              style: base.copyWith(color: fillColor),
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
            ),
          ],
        ),
      ],
    );
  }
}

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});
  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  List<Word> words = [];
  List<Word> filteredWords = [];
  final TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _loadWords();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadWords() async {
    final loaded = await storage.loadWords();
    if (loaded.isEmpty) {
      words = List<Word>.from(_defaultWords);
      await storage.saveWords(words);
    } else {
      // Ensure all words have unique, non-empty IDs to avoid GlobalKey conflicts
      // in ReorderableListView.
      final seen = <String>{};
      final fixed = <Word>[];
      for (final w in loaded) {
        var id = w.id;
        if (id.isEmpty || seen.contains(id)) {
          id = const Uuid().v4();
        }
        seen.add(id);
        fixed.add(Word(id: id, eng: w.eng, rus: w.rus, desc: w.desc));
      }
      words = fixed;
      // Persist back if anything changed
      if (fixed.length != loaded.length ||
          !fixed.asMap().entries.every((e) => e.value.id == loaded[e.key].id)) {
        await storage.saveWords(words);
      }
    }
    setState(() {
      filteredWords = List.from(words);
    });
  }

  void _onSearchChanged() {
    setState(() {
      searchQuery = searchController.text.trim().toLowerCase();
      _filterWords();
    });
  }

  void _filterWords() {
    if (searchQuery.isEmpty) {
      filteredWords = List.from(words);
    } else {
      filteredWords = words.where((word) {
        final eng = word.eng.toLowerCase();
        final rus = word.rus.toLowerCase();
        return eng.contains(searchQuery) || rus.contains(searchQuery);
      }).toList();
    }
  }

  Future<void> _showWordExplanation(BuildContext context, int index) async {
    if (index < 0 || index >= words.length) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Word not found.')));
      return;
    }

    String gptAnswer =
        words[index].desc ?? "Нет описания. Нажмите «Regenerate text».";

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> regenerate() async {
              setState(() => gptAnswer = "Loading...");
              try {
                final eng = words[index].eng;
                final newText = await gpt.explainWord(eng);
                if (!context.mounted) return;
                setState(() => gptAnswer = newText);

                words[index] = words[index].copyWith(desc: newText);
                await storage.saveWords(words);
              } catch (e) {
                if (!context.mounted) return;
                setState(() => gptAnswer = "Ошибка: $e");
              }
            }

            return AlertDialog(
              title: Text('Explanation for "${words[index].eng}"'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SingleChildScrollView(child: Text(gptAnswer)),
                    if (gptAnswer == "Loading...") ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Generating...'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: gptAnswer == "Loading..." ? null : regenerate,
                  child: const Text("Regenerate text"),
                ),
                TextButton(
                  onPressed: gptAnswer == "Loading..."
                      ? null
                      : () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addOrEditWord({int? index}) async {
    Timer? debounceTimer;

    final engController = TextEditingController(
      text: index != null ? words[index].eng : '',
    );
    final rusController = TextEditingController(
      text: index != null ? words[index].rus : '',
    );

    final engFocus = FocusNode();
    final rusFocus = FocusNode();

    bool autoTranslate = !kIsWeb; // Disable by default on web due to CORS
    bool isSaving = false;

    // <-- объявляем заранее, чтобы замыкания могли ссылаться
    StateSetter? _setDialogState;

    Future<void> save() async {
      final eng = engController.text.trim();
      String rus = rusController.text.trim();
      if (eng.isEmpty) return;

      // автоперевод при пустом RUS
      if (autoTranslate && rus.isEmpty) {
        try {
          rus = await translate.translateToRu(eng);
        } catch (_) {
          rus = rusController.text.trim();
        }
      }

      // показываем спиннер в диалоге
      _setDialogState?.call(() => isSaving = true);

      // генерируем описание ТОЛЬКО при добавлении
      String? desc = index != null ? words[index].desc : null;
      if (index == null) {
        try {
          desc = await gpt.explainWord(eng);
        } catch (e) {
          desc = 'Ошибка при генерации описания: $e';
        }
      }

      final newWord = Word(
        id: index != null ? words[index].id : const Uuid().v4(),
        eng: eng,
        rus: rus,
        desc: desc,
      );

      if (!mounted) return;

      setState(() {
        if (index == null) {
          words.add(newWord);
        } else {
          words[index] = newWord;
        }
        _filterWords();
      });

      await storage.saveWords(words);

      if (!mounted) return;
      Navigator.pop(context);
      showAddedWordPopup(context);
    }

    await showDialog(
      context: context,
      barrierDismissible: !isSaving,
      builder: (_) => StatefulBuilder(
        builder: (context, innerSetState) {
          // присваиваем ссылку, чтобы save() мог обновлять диалог
          _setDialogState = innerSetState;

          return AlertDialog(
            title: Text(index == null ? "Add Word" : "Edit Word"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: engController,
                  focusNode: engFocus,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: "English"),
                  enabled: !isSaving,
                  onSubmitted: (_) => save(),
                  onChanged: (text) {
                    if (!autoTranslate || text.trim().isEmpty) return;
                    debounceTimer?.cancel();
                    debounceTimer = Timer(
                      const Duration(milliseconds: 500),
                      () async {
                        try {
                          rusController.text = await translate.translateToRu(
                            text.trim(),
                          );
                        } catch (_) {
                          // игнорируем ошибку автоперевода
                        }
                      },
                    );
                  },
                ),
                TextField(
                  controller: rusController,
                  focusNode: rusFocus,
                  decoration: const InputDecoration(labelText: "Russian"),
                  textInputAction: TextInputAction.done,
                  enabled: !isSaving,
                  onSubmitted: (_) => save(),
                ),
                Row(
                  children: [
                    Checkbox(
                      value: autoTranslate,
                      onChanged: isSaving
                          ? null
                          : (v) => innerSetState(() {
                              autoTranslate = v ?? true;
                            }),
                    ),
                    const Text("Auto-translate"),
                  ],
                ),
                if (isSaving) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 10),
                      Text("Generating & saving..."),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: isSaving ? null : save,
                child: const Text("Save"),
              ),
            ],
          );
        },
      ),
    );

    debounceTimer?.cancel();
  }

  Future<void> _deleteWord(int index) async {
    setState(() {
      words.removeAt(index);
      _filterWords();
    });
    await storage.saveWords(words);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 90,
        centerTitle: true,
        title: const CodeDictionaryTitle(
          fontSize: 56, // подгони под высоту AppBar
          strokeWidth: 5, // «слегка мультяшно» — не переборщи
          fillColor: Color.fromARGB(
            255,
            231,
            255,
            223,
          ), // можно заменить на тему
          strokeColor: Color(0xCC000000),
          fontFamily: 'CodictionaryCartoon',
          imagePath: 'lib/media/CODY.png',
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final columns = width.isFinite
                    ? (width / 220).floor().clamp(1, 6)
                    : 2;
                return ReorderableGridView.builder(
                  itemCount: filteredWords.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      final item = filteredWords.removeAt(oldIndex);
                      filteredWords.insert(newIndex, item);
                      words = List<Word>.from(filteredWords);
                    });
                    storage.saveWords(words);
                  },
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.6,
                  ),
                  itemBuilder: (context, i) {
                    final word = filteredWords[i];
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(word.id),
                      index: i,
                      child: Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                word.eng,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                word.rus,
                                style: const TextStyle(fontSize: 14),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Spacer(),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    tooltip: 'Explain',
                                    icon: const Icon(Icons.remove_red_eye),
                                    onPressed: () => _showWordExplanation(
                                      context,
                                      words.indexOf(word),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Edit',
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _addOrEditWord(
                                      index: words.indexOf(word),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    icon: const Icon(Icons.delete),
                                    onPressed: () =>
                                        _deleteWord(words.indexOf(word)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.chat),
              label: const Text("Test GPT"),
              onPressed: () => showGPTTestDialog(context),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text("Add Word"),
        onPressed: () => _addOrEditWord(),
      ),
    );
  }
}
