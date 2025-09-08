Так, а ты можешь мне собрать мой Dart-файл с учетом твоих правок? Я тебе просто сейчас Dart-файл скину, потому что я, мне кажется, совсем потерялся. Я пытался делать все изменения, которые ты хотел, но у меня что-то как-то совсем плоховато стало.

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:uuid/uuid.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:uuid/uuid.dart';

final _uuid = const Uuid();
final apiKey = dotenv.env['OPENAI_API_KEY'];

// ====== Конфиг ======
const String TRANSLATE_URL = "https://api-free.deepl.com/v2/translate";
const String GPT5_MINI_URL = "https://api.openai.com/v1/responses";
// Константы для размера карточки — «фиксированная и пропорциональная»
const double kCardWidth = 320; // целевая ширина карточки
const double kCardAspect = 1.6; // ширина / высота (подгони по вкусу)
double get kCardHeight => kCardWidth / kCardAspect;

bool _dragging = false; // чтобы фиксировать колонки во время DnD
int?
_lockedCrossAxisCount; // заморозим количество столбцов на время перетаскивания

@override
Widget build(BuildContext context) {
  final list =
      filteredWords; // что показываем (весь список или отфильтрованный)

  final grid = ReorderableGridView.builder(
    padding: const EdgeInsets.all(12),
    // ВНИМАНИЕ: используем MaxCrossAxisExtent — количество столбцов посчитается само
    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: _effectiveMaxExtent(context), // см. функцию ниже
      mainAxisExtent: kCardHeight,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
    ),
    itemCount: list.length,
    itemBuilder: (context, i) {
      final item = list[i];
      return _WordCard(
        key: ValueKey(item['id']),
        eng: item['eng'] ?? '',
        rus: item['rus'] ?? '',
        onView: () => _showWordExplanation(
          context,
          words.indexWhere((w) => w['id'] == item['id']),
        ),
        onEdit: () => _addOrEditWord(
          index: words.indexWhere((w) => w['id'] == item['id']),
        ),
        onDelete: () =>
            _deleteWord(words.indexWhere((w) => w['id'] == item['id'])),
        // если пакет поддерживает drag-handle — можно прокинуть сюда builder для ручки
      );
    },
    dragEnabled: searchQuery.isEmpty, // запрещаем реордер, если включён фильтр
    onDragStart: () {
      setState(() {
        _dragging = true;
        _lockedCrossAxisCount = _currentCrossAxisCount(context);
      });
    },
    onDragEnd: () {
      setState(() {
        _dragging = false;
        _lockedCrossAxisCount = null;
      });
    },
    onReorder: (oldIndex, newIndex) {
      // Преобразуем индексы из filtered -> в реальный words
      if (searchQuery.isNotEmpty) return; // подстраховка
      setState(() {
        final moved = words.removeAt(oldIndex);
        words.insert(newIndex, moved);
        filteredWords = List.from(words);
      });
      saveDict(words);
    },
  );

  return Scaffold(
    appBar: AppBar(
      // ...
    ),
    body: grid,
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _addOrEditWord(),
      icon: const Icon(Icons.add),
      label: const Text('Add Word'),
    ),
  );
}

/// Пока тянем карточку — не меняем число столбцов (фиксим на время дропа),
/// иначе на Windows при ресайзе во время DnD сетка «прыгнет».
double _effectiveMaxExtent(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (_dragging && _lockedCrossAxisCount != null) {
    final count = _lockedCrossAxisCount!.clamp(1, 50);
    final spacing = 12.0;
    // подберём maxExtent так, чтобы count сохранился
    return (width - (count + 1) * spacing) / count;
  }
  return kCardWidth; // нормальный режим: считаем по целевой ширине карточки
}

int _currentCrossAxisCount(BuildContext context) {
  final maxExtent = kCardWidth;
  final width = MediaQuery.of(context).size.width;
  final count = (width / maxExtent).floor().clamp(1, 50);
  return count;
}

Future<String> askGPT5Mini(String prompt) async {
  final resp = await http.post(
    Uri.parse(GPT5_MINI_URL), // https://api.openai.com/v1/responses
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $apiKey",
    },
    body: jsonEncode({
      "model": "gpt-4.1-mini", // не "gpt-5-mini"
      "input": prompt,
      "temperature": 1,
      "max_output_tokens": 400, // можно 200–500
    }),
  );

  if (resp.statusCode != 200) {
    throw Exception("OpenAI API error: ${resp.statusCode} ${resp.body}");
  }

  final data = jsonDecode(resp.body);

  // Response API: data['output'] — список сообщений, каждое содержит content[]
  final output = data['output'] as List<dynamic>? ?? const [];
  if (output.isEmpty) return "No output from model.";

  final first =
      output.first as Map<String, dynamic>?; // {id, type, role, content, ...}
  final content = first?['content'] as List<dynamic>? ?? const [];

  // Ищем text-часть (обычно type == 'output_text')
  String? text;
  for (final part in content) {
    final p = part as Map<String, dynamic>;
    if (p['text'] is String) {
      text = p['text'] as String;
      break;
    }
  }

  return text ?? "No text in response.";
}

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
              final resp = await http.post(
                Uri.parse("https://api.openai.com/v1/responses"),
                headers: {
                  "Content-Type": "application/json",
                  "Authorization": "Bearer $apiKey",
                },
                body: jsonEncode({
                  "model": "gpt-4.1-mini",
                  "input": prompt,
                  "temperature": 1,
                  "max_output_tokens": 500,
                }),
              );

              if (resp.statusCode == 200) {
                final data = jsonDecode(resp.body);
                final output = data['output'] as List<dynamic>? ?? [];
                final firstMessage = output.isNotEmpty ? output[0] : null;
                final text = firstMessage != null
                    ? (firstMessage['content'] as List<dynamic>)[0]['text']
                          as String
                    : "No content";

                setState(() => gptAnswer = text);
              } else {
                setState(
                  () => gptAnswer = "Error: ${resp.statusCode} ${resp.body}",
                );
              }
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

// ====== Утилиты ======
Future<File> _getDictFile() async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/dictionary.json');
  // Для отладки полезно напечатать путь
  debugPrint('Dictionary file path: ${file.path}');
  return file;
}

const List<Map<String, String>> _defaultWords = [
  {"eng": "apple", "rus": "яблоко"},
  {"eng": "dog", "rus": "собака"},
  {"eng": "house", "rus": "дом"},
];

Future<List<Map<String, String>>> loadDict() async {
  try {
    final file = await _getDictFile();
    if (await file.exists()) {
      final text = await file.readAsString();
      if (text.trim().isEmpty) {
        debugPrint('Dict file empty -> returning default');
        await saveDict(_defaultWords); // перезапишем дефолтом
        return List.from(_defaultWords);
      }
      final raw = jsonDecode(text);
      if (raw is List) {
        // конвертация каждого элемента в Map<String,String>
        final list = raw.map<Map<String, String>>((e) {
          if (e is Map) return Map<String, String>.from(e);
          return <String, String>{};
        }).toList();
        return list;
      }
      debugPrint('Dict file JSON not a list -> using default');
    } else {
      // Файла нет — попробуем взять bundled asset (если он есть)
      try {
        final asset = await rootBundle.loadString('assets/dictionary.json');
        final raw = jsonDecode(asset);
        final list = (raw as List)
            .map<Map<String, String>>((e) => Map<String, String>.from(e))
            .toList();
        // Сохраним копию в documents, чтобы далее использовать её
        await saveDict(list);
        debugPrint('Copied initial dictionary from assets into documents');
        return list;
      } catch (e) {
        debugPrint('No asset dictionary or failed to load it: $e');
        // создадим файл с дефолтом
        await saveDict(_defaultWords);
        return List.from(_defaultWords);
      }
    }
  } catch (e, st) {
    debugPrint('loadDict error: $e\n$st');
  }
  // fallback
  return List.from(_defaultWords);
}

Future<void> saveDict(List<Map<String, String>> dict) async {
  try {
    final file = await _getDictFile();
    final text = jsonEncode(dict);
    await file.writeAsString(text);
    debugPrint('Saved dictionary (${dict.length} entries) to ${file.path}');
  } catch (e, st) {
    debugPrint('saveDict error: $e\n$st');
  }
}

Future<String> translateWord(String word) async {
  final resp = await http.post(
    Uri.parse(TRANSLATE_URL),
    headers: {"Content-Type": "application/x-www-form-urlencoded"},
    body: "auth_key=$API_KEY&text=$word&target_lang=RU",
  );

  if (resp.statusCode != 200) {
    throw Exception("Translation failed: ${resp.body}");
  }

  final data = jsonDecode(resp.body);
  return data["translations"][0]["text"];
}

// ====== Приложение ======
Future<void> main() async {
  // обязательно нужно вызвать, чтобы инициализировать биндинги Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // загружаем переменные из .env
  await dotenv.load(fileName: ".env");

  runApp(const MyApp());
}

void showAddedWordPopup(BuildContext context) {
  final overlay = Overlay.of(context);
  final entry = OverlayEntry(
    builder: (context) =>
        Positioned(right: 16, bottom: 80, child: _AnimatedPopup()),
  );

  overlay.insert(entry);
  Future.delayed(const Duration(seconds: 2), () {
    entry.remove();
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

class _WordCard extends StatelessWidget {
  const _WordCard({
    super.key,
    required this.eng,
    required this.rus,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  final String eng;
  final String rus;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Заголовок
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                eng,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Перевод
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                rus,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            const Spacer(),
            // Кнопки
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(Icons.visibility),
                  onPressed: onView,
                  tooltip: 'View',
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: onEdit,
                  tooltip: 'Edit',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: onDelete,
                  tooltip: 'Delete',
                ),
                // Если пакет поддерживает drag-handle, можно вставить сюда ручку:
                // ReorderableDragStartListener(index: i, child: const Icon(Icons.drag_handle))
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CoDictionaryTitle extends StatelessWidget {
  const CoDictionaryTitle({
    super.key,
    this.text = 'Codictionary',
    this.fontSize = 90, // размер шрифта в AppBar
    this.strokeWidth = 3.0, // толщина обводки
    this.strokeColor = const Color(0xCC000000),
    this.fillColor = Colors.white, // цвет заливки текста
    this.imagePath = 'assets/images/mascot.png',
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
  final _uuid = const Uuid();

  List<Map<String, String>> words = [];
  List<Map<String, String>> filteredWords = [];

  final TextEditingController searchController = TextEditingController();
  String searchQuery = "";

  bool _dragging = false;
  int? _lockedCrossAxisCount;

  @override
  void initState() {
    super.initState();
    _loadWords();
    searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadWords() async {
    final dict = await loadDict();
    // миграция id (важно для стабильных ключей)
    bool changed = false;
    for (final w in dict) {
      if ((w['id'] ?? '').isEmpty) {
        w['id'] = _uuid.v4();
        changed = true;
      }
    }
    if (changed) await saveDict(dict);

    setState(() {
      words = dict;
      filteredWords = List.from(words);
    });
  }

  Future<void> _showWordExplanation(BuildContext context, int index) async {
    if (index < 0 || index >= words.length) {
      // на всякий случай, если indexOf вернул -1
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Word not found.')));
      return;
    }

    String gptAnswer =
        words[index]["desc"] ?? "Нет описания. Нажмите «Regenerate text».";

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> regenerate() async {
              setState(() => gptAnswer = "Loading...");
              try {
                final eng = words[index]["eng"] ?? "";
                final prompt =
                    'Приведи пример использования слова "$eng" на английском языке. '
                    'Дай русскоязычное описание длиной примерно 200 слов о том, как это слово переводится и где используется.';
                final newText = await askGPT5Mini(prompt);
                if (!context.mounted) return;
                setState(() => gptAnswer = newText);

                // обновляем и сохраняем
                words[index]["desc"] = newText;
                await saveDict(words);
              } catch (e) {
                if (!context.mounted) return;
                setState(() => gptAnswer = "Ошибка: $e");
              }
            }

            return AlertDialog(
              title: Text('Explanation for "${words[index]["eng"] ?? ""}"'),
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
      text: index != null ? (words[index]["eng"] ?? '') : '',
    );
    final rusController = TextEditingController(
      text: index != null ? (words[index]["rus"] ?? '') : '',
    );

    final engFocus = FocusNode();
    final rusFocus = FocusNode();

    bool autoTranslate = true;
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
          rus = await translateWord(eng);
        } catch (_) {
          // оставляем как ввёл пользователь
          rus = rusController.text.trim();
        }
      }

      // показываем спиннер в диалоге
      _setDialogState?.call(() => isSaving = true);

      // генерируем описание ТОЛЬКО при добавлении
      String? desc = index != null ? (words[index]["desc"]) : null;
      if (index == null) {
        final prompt =
            'Приведи пример использования слова "$eng" на английском языке. '
            'Дай русскоязычное описание длиной примерно 200 слов о том, как это слово переводится и где используется.';
        try {
          desc = await askGPT5Mini(prompt);
        } catch (e) {
          desc = 'Ошибка при генерации описания: $e';
        }
      }

      final newEntry = <String, String>{
        "eng": eng,
        "rus": rus,
        if (desc != null) "desc": desc,
      };

      if (!mounted) return;

      setState(() {
        if (index == null) {
          words.add(newEntry);
        } else {
          words[index] =
              newEntry; // desc оставляем как было, если редактирование
        }
        _filterWords();
      });

      await saveDict(words);

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
                          rusController.text = await translateWord(text.trim());
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
    await saveDict(words);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 90,
        centerTitle: true,
        title: const CoDictionaryTitle(
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
            child: ReorderableListView.builder(
              itemCount: filteredWords.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final item = filteredWords.removeAt(oldIndex);
                  filteredWords.insert(newIndex, item);
                  words.clear();
                  words.addAll(filteredWords);
                  saveDict(words);
                });
              },
              itemBuilder: (context, i) {
                final word = filteredWords[i];
                return ListTile(
                  key: ValueKey(word),
                  title: Text(word["eng"] ?? ""),
                  subtitle: Text(word["rus"] ?? ""),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_red_eye),
                        onPressed: () =>
                            _showWordExplanation(context, words.indexOf(word)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () =>
                            _addOrEditWord(index: words.indexOf(word)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteWord(words.indexOf(word)),
                      ),
                    ],
                  ),
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
