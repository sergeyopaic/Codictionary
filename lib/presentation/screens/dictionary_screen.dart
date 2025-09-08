import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../../models/word.dart';
import '../../services/gpt_service.dart';
import '../../services/translate_service.dart';
import '../../services/storage_service.dart';
import '../dialogs/gpt_test_dialog.dart';
import '../widgets/code_dictionary_title.dart';

class DictionaryScreen extends StatefulWidget {
  final GptService gpt;
  final TranslateService translate;
  final StorageService storage;
  final List<Word> defaultWords;
  const DictionaryScreen({
    super.key,
    required this.gpt,
    required this.translate,
    required this.storage,
    required this.defaultWords,
  });
  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  List<Word> words = [];
  List<Word> filteredWords = [];
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';

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
    final loaded = await widget.storage.loadWords();
    if (loaded.isEmpty) {
      words = List<Word>.from(widget.defaultWords);
      await widget.storage.saveWords(words);
    } else {
      final seen = <String>{};
      final fixed = <Word>[];
      for (final w in loaded) {
        var id = w.id;
        final duplicate = id.isEmpty || seen.contains(id);
        if (duplicate) {
          id = const Uuid().v4();
        }
        seen.add(id);
        fixed.add(Word(id: id, eng: w.eng, rus: w.rus, desc: w.desc));
      }
      words = fixed;
      // Persist back if anything changed
      final bool sameLength = fixed.length == loaded.length;
      final bool sameIds =
          sameLength &&
          fixed.asMap().entries.every((e) => e.value.id == loaded[e.key].id);
      if (!sameLength || !sameIds) {
        await widget.storage.saveWords(words);
      }
    }
    if (!mounted) return;
    setState(() => filteredWords = List.from(words));
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
      filteredWords = words
          .where(
            (word) =>
                word.eng.toLowerCase().contains(searchQuery) ||
                word.rus.toLowerCase().contains(searchQuery),
          )
          .toList();
    }
  }

  Future<void> _showWordExplanation(BuildContext context, int index) async {
    if (index < 0 || index >= words.length) return;
    String gptAnswer = words[index].desc ?? 'Waiting for response...';

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> regenerate() async {
              setState(() => gptAnswer = 'Loading...');
              try {
                final eng = words[index].eng;
                final newText = await widget.gpt.explainWord(eng);
                if (!context.mounted) return;
                setState(() => gptAnswer = newText);
                words[index] = words[index].copyWith(desc: newText);
                await widget.storage.saveWords(words);
              } catch (e) {
                if (!context.mounted) return;
                setState(() => gptAnswer = 'Error: $e');
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
                    if (gptAnswer == 'Loading...') ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 8),
                          Text('Generating...'),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: regenerate,
                          child: const Text('Regenerate text'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addOrEditWord({int? index}) async {
    final bool isEdit = index != null;
    final engController = TextEditingController(
      text: isEdit ? words[index].eng : '',
    );
    final rusController = TextEditingController(
      text: isEdit ? words[index].rus : '',
    );
    String? desc = isEdit ? words[index].desc : null;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> autoTranslateIfNeeded() async {
              final eng = engController.text.trim();
              if (rusController.text.trim().isEmpty && eng.isNotEmpty) {
                try {
                  final translated = await widget.translate.translateToRu(eng);
                  if (!context.mounted) return;
                  setDialogState(() => rusController.text = translated);
                } catch (_) {}
              }
            }

            Future<void> generateDescription() async {
              setDialogState(() => desc = 'Loading...');
              try {
                final eng = engController.text.trim();
                final text = await widget.gpt.explainWord(eng);
                if (!context.mounted) return;
                setDialogState(() => desc = text);
              } catch (e) {
                if (!context.mounted) return;
                setDialogState(() => desc = 'Error generating description: $e');
              }
            }

            return AlertDialog(
              title: Text(isEdit ? 'Edit Word' : 'Add Word'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: engController,
                      decoration: const InputDecoration(labelText: 'ENG'),
                      onChanged: (_) => autoTranslateIfNeeded(),
                    ),
                    TextField(
                      controller: rusController,
                      decoration: const InputDecoration(labelText: 'RUS'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            desc ?? 'No description. Tap "Regenerate text".',
                          ),
                        ),
                        IconButton(
                          tooltip: 'Regenerate text',
                          icon: const Icon(Icons.refresh),
                          onPressed: generateDescription,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final eng = engController.text.trim();
                    final rus = rusController.text.trim();
                    if (eng.isEmpty || rus.isEmpty) return;
                    if (isEdit) {
                      final updated = words[index].copyWith(
                        eng: eng,
                        rus: rus,
                        desc: desc,
                      );
                      setState(() => words[index] = updated);
                    } else {
                      final newWord = Word(
                        id: const Uuid().v4(),
                        eng: eng,
                        rus: rus,
                        desc: desc,
                      );
                      setState(() => words.add(newWord));
                    }
                    await widget.storage.saveWords(words);
                    if (!context.mounted) return;
                    Navigator.of(context).pop();
                  },
                  child: Text(isEdit ? 'Save' : 'Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteWord(int index) async {
    if (index < 0 || index >= words.length) return;
    final word = words[index];
    setState(() => words.removeAt(index));
    await widget.storage.saveWords(words);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Deleted ${word.eng}')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 90,
        centerTitle: true,
        title: const CodeDictionaryTitle(
          fontSize: 56,
          strokeWidth: 5,
          fillColor: Color.fromARGB(255, 231, 255, 223),
          strokeColor: Color(0xCC000000),
          fontFamily: 'CodictionaryCartoon',
          imagePath: 'lib/media/CODY.png',
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search...',
              ),
            ),
          ),
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
                    widget.storage.saveWords(words);
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
                                    onPressed: () {
                                      final idx = words.indexOf(word);
                                      if (idx >= 0)
                                        _showWordExplanation(context, idx);
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Edit',
                                    icon: const Icon(Icons.edit),
                                    onPressed: () {
                                      final idx = words.indexOf(word);
                                      if (idx >= 0) _addOrEditWord(index: idx);
                                    },
                                  ),
                                  IconButton(
                                    tooltip: 'Delete',
                                    icon: const Icon(Icons.delete),
                                    onPressed: () {
                                      final idx = words.indexOf(word);
                                      if (idx >= 0) _deleteWord(idx);
                                    },
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
              label: const Text('Test GPT'),
              onPressed: () => showGPTTestDialog(context, widget.gpt),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Word'),
        onPressed: () => _addOrEditWord(),
      ),
    );
  }
}
