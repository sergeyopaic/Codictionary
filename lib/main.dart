import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';

final apiKey = dotenv.env['OPENAI_API_KEY'];

// ====== Конфиг ======
const String API_KEY = "3d24a792-7f04-4396-9446-528aa5d638b2:fx";
const String TRANSLATE_URL = "https://api-free.deepl.com/v2/translate";
const String GPT5_MINI_URL = "https://api.openai.com/v1/responses";

Future<String> askGPT5Mini(String prompt) async {
  final response = await http.post(
    Uri.parse(GPT5_MINI_URL),
    headers: {
      "Content-Type": "application/json",
      "Authorization": "Bearer $apiKey",
    },
    body: jsonEncode({
      "model": "gpt-5-mini",
      "input": prompt,
      "temperature": 1,
      "max_output_tokens": 200,
    }),
  );

  if (response.statusCode != 200) {
    throw Exception("Ошибка API: ${response.body}");
  }

  final data = jsonDecode(response.body);
  // GPT возвращает массив choices, берём первый
  return data['choices'][0]['message']['content'];
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
                  "Authorization": "Bearer $OPENAI_API_KEY",
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

class DictionaryScreen extends StatefulWidget {
  const DictionaryScreen({super.key});
  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  List<Map<String, String>> words = [];
  List<Map<String, String>> filteredWords = [];
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
    final dict = await loadDict();
    setState(() {
      words = dict;
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
        final eng = word["eng"]?.toLowerCase() ?? "";
        final rus = word["rus"]?.toLowerCase() ?? "";
        return eng.contains(searchQuery) || rus.contains(searchQuery);
      }).toList();
    }
  }

  Future<void> _addOrEditWord({int? index}) async {
    Timer? debounceTimer;
    final engController = TextEditingController(
      text: index != null ? words[index]["eng"] : '',
    );

    final rusController = TextEditingController(
      text: index != null ? words[index]["rus"] : '',
    );
    final engFocus = FocusNode();
    final rusFocus = FocusNode();
    bool autoTranslate = true;
    Future<void> save() async {
      final eng = engController.text.trim();
      String rus = rusController.text.trim();
      if (eng.isEmpty) return;

      if (autoTranslate && rus.isEmpty) {
        rus = await translateWord(eng);
      }

      final newEntry = {"eng": eng, "rus": rus};
      setState(() {
        if (index == null) {
          words.add(newEntry);
        } else {
          words[index] = newEntry;
        }
        _filterWords();
      });
      await saveDict(words);
      Navigator.pop(context);
      showAddedWordPopup(context);
    }

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
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
                  onSubmitted: (_) => save(),
                  onChanged: (text) {
                    if (!autoTranslate || text.trim().isEmpty) return;
                    debounceTimer?.cancel();
                    debounceTimer = Timer(
                      const Duration(milliseconds: 500),
                      () async {
                        rusController.text = await translateWord(text.trim());
                      },
                    );
                  },
                ),
                TextField(
                  controller: rusController,
                  focusNode: rusFocus,
                  decoration: const InputDecoration(labelText: "Russian"),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => save(),
                ),
                Row(
                  children: [
                    Checkbox(
                      value: autoTranslate,
                      onChanged: (v) => setDialogState(() {
                        autoTranslate = v ?? true;
                      }),
                    ),
                    const Text("Auto-translate"),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(onPressed: save, child: const Text("Save")),
            ],
          );
        },
      ),
    );
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
        title: const Text("Codictionary"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                hintText: "Search...",
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
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
