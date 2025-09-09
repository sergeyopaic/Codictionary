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
import '../widgets/word_card_menu.dart';
import '../widgets/added_word_popup.dart';
import '../utils/letter_limit_formatter.dart';

/// Main screen showing the dictionary grid and handling add/edit/delete.
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

/// State for [DictionaryScreen]; manages words, filtering, and actions.
class _DictionaryScreenState extends State<DictionaryScreen> {
  List<Word> words = [];
  List<Word> filteredWords = [];
  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  final Set<String> _removing = <String>{};

  int _indexInWordsById(String id) => words.indexWhere((w) => w.id == id);

  Future<bool> _confirmDeleteDialog(
    BuildContext context,
    String wordEng,
  ) async {
    final theme = Theme.of(context);
    return (await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (context) {
            return AlertDialog(
              contentPadding: const EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16,
              ), // ← равные отступы
              actionsPadding: const EdgeInsets.fromLTRB(
                16,
                0,
                16,
                16,
              ), // ← кнопкам тоже боковые + нижний
              content: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment
                      .stretch, // ← растягиваем детей по высоте контента
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 84,
                      // гарантируем, что изображение займет всю высоту контентной области
                      child: FittedBox(
                        fit: BoxFit.contain, // или BoxFit.fitHeight
                        child: Image.asset(
                          'assets/media/cody_delete.png',
                          filterQuality: FilterQuality.high,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Delete this word?',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '“$wordEng” will be removed from your dictionary.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  onPressed: () =>
                      Navigator.of(context, rootNavigator: true).pop(true),
                ),
              ],
            );
          },
        )) ??
        false;
  }

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

  /// Loads words from storage, fixing duplicate/empty IDs, and seeds defaults.
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
        fixed.add(
          Word(
            id: id,
            eng: w.eng,
            rus: w.rus,
            desc: w.desc,
            addedAt: w.addedAt,
          ),
        );
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

  /// Reacts to changes in the search field and updates the filtered list.
  void _onSearchChanged() {
    setState(() {
      searchQuery = searchController.text.trim().toLowerCase();
      _filterWords();
    });
  }

  /// Applies current [searchQuery] to [words] and updates [filteredWords].
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

  /// Opens a dialog with extended info (GPT) for the word at [index].
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

  /// Opens Add/Edit dialog. When [index] is null, adds; otherwise edits.
  Future<void> _addOrEditWord({int? index}) async {
    // Adapted from working_logic.md: auto-translate, Enter-to-save, and saving state
    Timer? debounceTimer;
    final bool isEdit = index != null;
    final engController = TextEditingController(
      text: isEdit ? words[index].eng : '',
    );
    final rusController = TextEditingController(
      text: isEdit ? words[index].rus : '',
    );
    final engFocus = FocusNode();
    final rusFocus = FocusNode();
    bool autoTranslate = true;
    bool isSaving = false;
    String? desc = isEdit ? words[index].desc : null;

    Future<void> save(StateSetter setDialogState) async {
      final eng = engController.text.trim();
      String rus = rusController.text.trim();
      if (eng.isEmpty) return;

      if (autoTranslate && rus.isEmpty) {
        try {
          rus = await widget.translate.translateToRu(eng);
        } catch (_) {
          rus = rusController.text.trim();
        }
      }

      setDialogState(() => isSaving = true);

      if (!isEdit) {
        try {
          desc = await widget.gpt.explainWord(eng);
        } catch (e) {
          desc = 'Error generating description: $e';
        }
      } else {
        final original = words[index];
        final hasChanged =
            eng != original.eng ||
            rus != original.rus ||
            (desc ?? '') != (original.desc ?? '');
        if (hasChanged) {
          try {
            desc = await widget.gpt.explainWord(eng);
          } catch (e) {
            // Keep previous or user-entered desc if generation fails
            desc = desc ?? original.desc;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        if (isEdit) {
          words[index] = words[index].copyWith(eng: eng, rus: rus, desc: desc);
        } else {
          words.add(
            Word(
              id: const Uuid().v4(),
              eng: eng,
              rus: rus,
              desc: desc,
              addedAt: DateTime.now(),
            ),
          );
        }
        _filterWords();
      });
      await widget.storage.saveWords(words);
      if (!mounted) return;
    }

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(isEdit ? 'Edit Word' : 'Add Word'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: engController,
                  focusNode: engFocus,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'English'),
                  inputFormatters: [LetterLimitFormatter(50)],
                  enabled: !isSaving,
                  onSubmitted: (_) async {
                    await save(setDialogState);
                    if (!context.mounted) return;
                    Navigator.pop(context, isEdit ? null : true);
                  },
                  onChanged: (text) {
                    if (!autoTranslate) return;
                    final trimmed = text.trim();
                    debounceTimer?.cancel();
                    if (trimmed.isEmpty) return;
                    debounceTimer = Timer(
                      const Duration(milliseconds: 500),
                      () async {
                        try {
                          final translated = await widget.translate
                              .translateToRu(trimmed);
                          if (rusController.text != translated) {
                            final newValue = TextEditingValue(
                              text: translated,
                              selection: TextSelection.collapsed(
                                offset: translated.length,
                              ),
                              composing: TextRange.empty,
                            );
                            rusController.value = newValue;
                          }
                        } catch (_) {}
                      },
                    );
                  },
                ),
                TextField(
                  controller: rusController,
                  focusNode: rusFocus,
                  decoration: const InputDecoration(labelText: 'Russian'),
                  inputFormatters: [LetterLimitFormatter(50)],
                  textInputAction: TextInputAction.done,
                  enabled: !isSaving,
                  onSubmitted: (_) async {
                    await save(setDialogState);
                    if (!context.mounted) return;
                    Navigator.pop(context, isEdit ? null : true);
                  },
                ),
                Row(
                  children: [
                    Checkbox(
                      value: autoTranslate,
                      onChanged: isSaving
                          ? null
                          : (v) =>
                                setDialogState(() => autoTranslate = v ?? true),
                    ),
                    const Text('Auto-translate'),
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
                      Text('Generating & saving...'),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving
                    ? null
                    : () => Navigator.of(context, rootNavigator: true).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        await save(setDialogState);
                        if (!isEdit) {
                          if (!context.mounted) return;
                          Navigator.of(context, rootNavigator: true).pop(true);
                        } else {
                          if (!context.mounted) return;
                          Navigator.of(context, rootNavigator: true).pop();
                        }
                      },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    debounceTimer?.cancel();
    if (!mounted) return;
    if (result == true) {
      await showWordAddedPopup(context);
    }
  }

  /// Animates and deletes the word at [index], then persists to storage.
  Future<void> _deleteWord(int index) async {
    if (index < 0 || index >= words.length) return;
    final word = words[index];
    setState(() => _removing.add(word.id));
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() {
      words.removeAt(index);
      _removing.remove(word.id);
      _filterWords();
    });
    await widget.storage.saveWords(words);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('The word "${word.eng}" was deleted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 120,
        centerTitle: true,
        title: const CodeDictionaryTitle(
          fontSize: 90,
          strokeWidth: 4,
          fillColor: Color.fromARGB(255, 231, 255, 223),
          strokeColor: Color(0xCC000000),
          fontFamily: 'CodictionaryCartoon',
          imagePath: 'assets/media/CODY.png',
        ),
      ),
      drawerScrimColor: Colors.black54,
      drawer: Builder(
        builder: (context) {
          final width = MediaQuery.of(context).size.width * 0.25;
          return Drawer(
            width: width.clamp(240.0, 420.0),
            child: SafeArea(
              child: ListView(
                padding: EdgeInsets.zero,
                children: const [
                  DrawerHeader(
                    child: Text(
                      'Menu',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('Settings'),
                    enabled: false,
                  ),
                ],
              ),
            ),
          );
        },
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
                    final isRemoving = _removing.contains(word.id);
                    return ReorderableDelayedDragStartListener(
                      key: ValueKey(word.id),
                      index: i,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 200),
                        opacity: isRemoving ? 0.0 : 1.0,
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
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: WordCardMenu(
                                    onExplain: () {
                                      final idx = _indexInWordsById(word.id);
                                      if (idx >= 0) {
                                        _showWordExplanation(context, idx);
                                      }
                                    },
                                    onEdit: () {
                                      final idx = _indexInWordsById(word.id);
                                      if (idx >= 0) _addOrEditWord(index: idx);
                                    },
                                    onDelete: () async {
                                      final idx = _indexInWordsById(word.id);
                                      if (idx < 0) return;
                                      final ok = await _confirmDeleteDialog(
                                        context,
                                        word.eng,
                                      );
                                      if (ok) _deleteWord(idx);
                                    },
                                  ),
                                ),
                              ],
                            ),
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
