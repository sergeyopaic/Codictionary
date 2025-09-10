import 'dart:async';
import 'package:flutter/material.dart';
import '../widgets/code_dictionary_title.dart';
import '../widgets/word_card_menu.dart';
import '../widgets/added_word_popup.dart';
import '../utils/letter_limit_formatter.dart';
import '../dictionary/dictionary_view_model.dart';
import '../../models/word.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import '../vocabs/vocabs_view.dart';
import '../core/widgets/animated_item_wrapper.dart';
import '../dialogs/confirm_bulk_delete_dialog.dart';

enum _SortOption { alphabetical, alphaDesc, dateAdded }

class DictionaryView extends StatefulWidget {
  final List<Word> defaultWords;
  const DictionaryView({super.key, required this.defaultWords});
  @override
  State<DictionaryView> createState() => _DictionaryBodyState();
}

class _DictionaryBodyState extends State<DictionaryView> {
  final TextEditingController searchController = TextEditingController();
  Timer? debounce;
  late final DictionaryViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = DictionaryViewModel();
    vm.load(seed: widget.defaultWords);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          toolbarHeight: 120,
          centerTitle: true,
          leadingWidth: 100,
          leading: Builder(
            builder: (ctx) {
              return Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.menu),
                    tooltip: 'Menu',
                    onPressed: () => Scaffold.of(ctx).openDrawer(),
                  ),
                  AnimatedBuilder(
                    animation: vm,
                    builder: (context, _) => Checkbox(
                      value: vm.selectionMode,
                      onChanged: (v) => vm.toggleSelectionMode(v ?? false),
                    ),
                  ),
                ],
              );
            },
          ),
          title: const CodeDictionaryTitle(
            key: ValueKey('app_title'),
            fontSize: 90,
            strokeWidth: 4,
            fillColor: Color.fromARGB(255, 231, 255, 223),
            strokeColor: Color(0xCC000000),
            fontFamily: 'CodictionaryCartoon',
            imagePath: 'assets/media/CODY.png',
          ),
          actions: [
            PopupMenuButton<_SortOption>(
              tooltip: 'Sort',
              icon: const Icon(Icons.sort),
              onSelected: (_SortOption value) {
                switch (value) {
                  case _SortOption.alphabetical:
                    vm.setSort(SortMode.alphaAsc);
                    break;
                  case _SortOption.alphaDesc:
                    vm.setSort(SortMode.alphaDesc);
                    break;
                  case _SortOption.dateAdded:
                    vm.setSort(SortMode.dateAdded);
                    break;
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _SortOption.alphabetical,
                  child: Row(
                    children: const [
                      Icon(Icons.sort_by_alpha),
                      SizedBox(width: 10),
                      Text('Alphabetical'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _SortOption.alphaDesc,
                  child: Row(
                    children: const [
                      Icon(Icons.sort_by_alpha),
                      SizedBox(width: 10),
                      Text('Alphabetical Z-A'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _SortOption.dateAdded,
                  child: Row(
                    children: const [
                      Icon(Icons.schedule),
                      SizedBox(width: 10),
                      Text('Date added'),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
          ],
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
                  children: [
                    const DrawerHeader(
                      child: Text(
                        'Menu',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.library_books),
                      title: const Text('My Vocabularies'),
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const VocabsView()),
                        );
                      },
                    ),
                    const ListTile(
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
                onChanged: (t) {
                  debounce?.cancel();
                  debounce = Timer(const Duration(milliseconds: 200), () {
                    vm.onQueryChanged(t);
                  });
                },
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
                    itemCount: vm.filtered.length,
                    onReorder: (oldIndex, newIndex) =>
                        vm.reorder(oldIndex, newIndex),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.6,
                    ),
                    itemBuilder: (context, i) {
                      final word = vm.filtered[i];
                      final isRemoving = vm.removing.contains(word.id);
                      final isSelected = vm.selected.contains(word.id);
                      return ReorderableDelayedDragStartListener(
                        key: ValueKey(word.id),
                        index: i,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: isRemoving ? 0.0 : 1.0,
                          child: AnimatedItemWrapper(
                            switchKey: ValueKey(
                              '${vm.currentSort.name}-${word.id}-$i',
                            ),
                            child: Card(
                              elevation: 2,
                              child: Stack(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                            onExplain: () =>
                                                _showWordExplanation(
                                                  context,
                                                  vm,
                                                  i,
                                                ),
                                            onEdit: () => _showAddEditDialog(
                                              context,
                                              vm,
                                              index: i,
                                            ),
                                            onDelete: () async {
                                              final ok =
                                                  await _confirmDeleteDialog(
                                                    context,
                                                    word.eng,
                                                  );
                                              if (ok) {
                                                await vm.deleteById(word.id);
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (vm.selectionMode)
                                    Positioned(
                                      left: 4,
                                      bottom: 4,
                                      child: Checkbox(
                                        value: isSelected,
                                        onChanged: (_) =>
                                            vm.toggleSelect(word.id),
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
          ],
        ),
        bottomNavigationBar: vm.selectionMode
            ? SafeArea(
                top: false,
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Divider(
                        height: 1,
                        thickness: 1,
                        color: Theme.of(context).dividerColor,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Builder(
                              builder: (context) {
                                final cs = Theme.of(context).colorScheme;
                                return Chip(
                                  avatar: Icon(
                                    Icons.checklist,
                                    size: 16,
                                    color: cs.onSecondaryContainer,
                                  ),
                                  label: Text('${vm.selectedCount} selected'),
                                  side: BorderSide(color: cs.outline),
                                  backgroundColor: cs.secondaryContainer,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                );
                              },
                            ),
                            const Spacer(),
                            OverflowBar(
                              spacing: 8,
                              overflowAlignment: OverflowBarAlignment.end,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: null, // inactive for now
                                  icon: const Icon(Icons.library_add_outlined),
                                  label: const Text('Add to dict'),
                                ),
                                FilledButton.tonalIcon(
                                  onPressed: null, // inactive for now
                                  icon: const Icon(Icons.more_horiz),
                                  label: const Text('More'),
                                ),
                                FilledButton.icon(
                                  icon: const Icon(Icons.delete_outline),
                                  label: const Text('Delete'),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.errorContainer,
                                    foregroundColor: Theme.of(
                                      context,
                                    ).colorScheme.onErrorContainer,
                                  ),
                                  onPressed: vm.selectedCount == 0
                                      ? null
                                      : () async {
                                          final ok = await showConfirmBulkDeleteDialog(
                                            context,
                                            vm.selectedCount,
                                          );
                                          if (ok) {
                                            await vm.deleteSelected();
                                            vm.toggleSelectionMode(false);
                                          }
                                        },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
        floatingActionButton: FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Add Word'),
          onPressed: () => _showAddEditDialog(context, vm),
        ),
      ),
    );
  }

  Future<void> _showAddEditDialog(
    BuildContext context,
    DictionaryViewModel vm, {
    int? index,
  }) async {
    final isEdit = index != null;
    final engController = TextEditingController(
      text: isEdit ? vm.words[index].eng : '',
    );
    final rusController = TextEditingController(
      text: isEdit ? vm.words[index].rus : '',
    );
    final engFocus = FocusNode();
    final rusFocus = FocusNode();
    bool autoTranslate = true;
    bool isSaving = false;
    Timer? debounceTimer;

    Future<void> save(StateSetter setDialogState) async {
      final eng = engController.text.trim();
      String rus = rusController.text.trim();
      if (eng.isEmpty) return;

      if (autoTranslate && rus.isEmpty) {
        try {
          rus = await vm.autoTranslate(eng);
        } catch (_) {}
      }

      setDialogState(() => isSaving = true);

      if (index == null) {
        final ok = await vm.addWord(eng: eng, rus: rus);
        if (!ok) {
          setDialogState(() => isSaving = false);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This word already exists in this vocabulary.'),
              ),
            );
          }
          return;
        }
        // Added successfully: keep dialog open for next input
        setDialogState(() => isSaving = false);
        if (context.mounted) {
          await showWordAddedPopup(context);
        }
        engController.clear();
        rusController.clear();
        if (context.mounted) {
          FocusScope.of(context).requestFocus(engFocus);
        }
      } else {
        final ok = await vm.editWord(index, eng: eng, rus: rus);
        if (!ok) {
          setDialogState(() => isSaving = false);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('This word already exists in this vocabulary.'),
              ),
            );
          }
          return;
        }
        // Edited successfully: keep dialog open to allow further tweaks
        setDialogState(() => isSaving = false);
        if (context.mounted) {
          await showWordAddedPopup(context);
        }
      }
      if (!mounted) return;
    }

    await showDialog<bool>(
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
                          final translated = await vm.autoTranslate(trimmed);
                          if (rusController.text != translated) {
                            rusController.value = TextEditingValue(
                              text: translated,
                              selection: TextSelection.collapsed(
                                offset: translated.length,
                              ),
                              composing: TextRange.empty,
                            );
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
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
              FilledButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        await save(setDialogState);
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
  }

  Future<void> _showWordExplanation(
    BuildContext context,
    DictionaryViewModel vm,
    int index,
  ) async {
    if (index < 0 || index >= vm.words.length) return;
    String gptAnswer = vm.currentDescription(index);

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> regenerate() async {
              setState(() => gptAnswer = 'Loading...');
              try {
                final newText = await vm.regenerateDescription(index);
                if (!context.mounted) return;
                setState(() => gptAnswer = newText);
              } catch (e) {
                if (!context.mounted) return;
                setState(() => gptAnswer = 'Error: $e');
              }
            }

            return AlertDialog(
              title: Text('Explanation for "${vm.words[index].eng}"'),
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
              contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              content: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 84,
                      child: FittedBox(
                        fit: BoxFit.contain,
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
                            '"$wordEng" will be removed from your dictionary.',
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
}

