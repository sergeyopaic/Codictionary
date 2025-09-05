import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

// ====== Конфиг ======
const String API_KEY = "3d24a792-7f04-4396-9446-528aa5d638b2:fx";
const String TRANSLATE_URL = "https://api-free.deepl.com/v2/translate";

// ====== Утилиты ======
Future<File> _getDictFile() async {
  final dir = await getApplicationDocumentsDirectory();
  return File('${dir.path}/dictionary.json');
}

Future<List<Map<String, String>>> loadDict() async {
  try {
    final file = await _getDictFile();
    if (await file.exists()) {
      final data = jsonDecode(await file.readAsString());
      return List<Map<String, String>>.from(data);
    }
  } catch (_) {}
  return [];
}

Future<void> saveDict(List<Map<String, String>> dict) async {
  final file = await _getDictFile();
  await file.writeAsString(jsonEncode(dict));
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
void main() {
  runApp(const MyApp());
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
      _filterWords();
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
    final engController = TextEditingController(text: index != null ? words[index]["eng"] : '');
    final rusController = TextEditingController(text: index != null ? words[index]["rus"] : '');
    
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
    }
    
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(index == null ? "Add Word" : "Edit Word"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: engController,
              decoration: const InputDecoration(labelText: "English"),
              textInputAction: TextInputAction.next,
              onChanged: (text) {
                if (!autoTranslate || text.trim().isEmpty) return;

                // отменяем предыдущий таймер
                debounceTimer?.cancel();

                // создаём новый таймер на 1.5 секунды
                debounceTimer = Timer(const Duration(milliseconds: 500), () async {
                  try {
                    rusController.text = await translateWord(text.trim());
                  } catch (e) {
                    // Можно проигнорировать ошибку или показать SnackBar
                  }
                });
              },
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ),
            TextField(
              controller: rusController,
              decoration: const InputDecoration(labelText: "Russian"),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => save(), 
            ),
            Row(
              children: [
                Checkbox(
                  value: autoTranslate,
                  onChanged: (v) => setState(() => autoTranslate = v ?? true),
                ),
                const Text("Auto-translate")
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: save, child: const Text("Save")),
        ],
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
      body: ReorderableListView.builder(
  itemCount: filteredWords.length,
  onReorder: (oldIndex, newIndex) {
    setState(() {
      // Коррекция, когда элемент сдвигается вниз
      if (newIndex > oldIndex) newIndex -= 1;

      // Находим индекс в оригинальном списке
      final item = filteredWords.removeAt(oldIndex);
      filteredWords.insert(newIndex, item);

      // Переносим изменения в основной список words
      words.clear();
      words.addAll(filteredWords);
      saveDict(words);
    });
  },
  itemBuilder: (context, i) {
    final word = filteredWords[i];
    return ListTile(
      key: ValueKey(word), // Обязательно для ReorderableListView
      title: Text(word["eng"] ?? ""),
      subtitle: Text(word["rus"] ?? ""),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _addOrEditWord(index: words.indexOf(word)),
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

      floatingActionButton: FloatingActionButton(
        onPressed: () => _addOrEditWord(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
