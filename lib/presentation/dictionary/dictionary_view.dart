import 'dart:async';
import 'package:flutter/material.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../dictionary/dictionary_view_model.dart';
import '../../models/word.dart';
import '../widgets/code_dictionary_title.dart';
import '../widgets/word_card_menu.dart';
import '../dialogs/confirm_delete_dialog.dart';
import '../dialogs/confirm_bulk_delete_dialog.dart';
import '../widgets/added_word_popup.dart' as toasts;

class DictionaryView extends StatefulWidget {
  final List<Word> defaultWords;
  const DictionaryView({super.key, required this.defaultWords});

  @override
  State<DictionaryView> createState() => _DictionaryViewState();
}

class _DictionaryViewState extends State<DictionaryView> {
  late final DictionaryViewModel vm;
  final TextEditingController _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    vm = DictionaryViewModel();
    vm.load(seed: widget.defaultWords);
    _search.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      vm.onQueryChanged(_search.text);
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) {
        return Scaffold(
          appBar: vm.selectionMode
               ? AppBar(
                  title: Text('${vm.selectedCount} selected'),
                  leading: IconButton(
                    tooltip: 'Close selection',
                    icon: const Icon(Icons.close),
                    onPressed: () => vm.toggleSelectionMode(false),
                  ),
                  actions: [
                      IconButton(
                        tooltip: vm.areAllSelected ? 'Clear selection' : 'Select all',
                        icon: Icon(vm.areAllSelected ? Icons.select_all : Icons.select_all_outlined),
                        onPressed: () {
                          if (vm.areAllSelected) {
                            vm.clearSelection();
                          } else {
                            vm.selectAll();
                          }
                        },
                      ),
                      if (vm.selectedCount > 0)
                        IconButton(
                          tooltip: 'Delete selected',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await showConfirmBulkDeleteDialog(
                              context,
                              vm.selectedCount,
                            );
                            if (ok) {
                              // Capture removed words before deletion for undo
                              final removed = vm.words
                                  .where((w) => vm.selected.contains(w.id))
                                  .toList(growable: false);
                              final count = removed.length;
                              await vm.deleteSelected();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$count word(s) deleted.'),
                                  action: SnackBarAction(
                                    label: 'UNDO',
                                    onPressed: () {
                                      // Fire-and-forget restore
                                      vm.restoreWords(removed);
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                  ],
                )
              : AppBar(
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
                  actions: [
                    IconButton(
                      tooltip: 'Sort A-Z',
                      onPressed: () => vm.setSort(SortMode.alphaAsc),
                      icon: const Icon(Icons.sort_by_alpha),
                    ),
                    IconButton(
                      tooltip: 'Sort Z-A',
                      onPressed: () => vm.setSort(SortMode.alphaDesc),
                      icon: const Icon(Icons.swap_vert),
                    ),
                    IconButton(
                      tooltip: 'Sort by date',
                      onPressed: () => vm.setSort(SortMode.dateAdded),
                      icon: const Icon(Icons.schedule),
                    ),
                  ],
                ),
          drawerScrimColor: Colors.black54,
          drawer: const _DictionarySidebar(),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  controller: _search,
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
                      itemCount: vm.filtered.length,
                      onReorder: (oldIndex, newIndex) {
                        vm.reorder(oldIndex, newIndex);
                      },
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
                            child: InkWell(
                              onLongPress: () {
                                if (!vm.selectionMode) vm.toggleSelectionMode(true);
                                vm.toggleSelect(word.id);
                              },
                              onTap: () {
                                if (vm.selectionMode) {
                                  vm.toggleSelect(word.id);
                                }
                              },
                              child: Stack(
                                children: [
                                  Card(
                                    elevation: 2,
                                    shape: RoundedRectangleBorder(
                                      side: vm.selectionMode && isSelected
                                          ? BorderSide(
                                              color: Theme.of(context).colorScheme.primary,
                                              width: 2,
                                            )
                                          : BorderSide.none,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
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
                                                final idx = vm.words.indexWhere((w) => w.id == word.id);
                                                if (idx >= 0) {
                                                  _showWordExplanation(context, vm, idx);
                                                }
                                              },
                                              onEdit: () async {
                                                final idx = vm.words.indexWhere((w) => w.id == word.id);
                                                if (idx >= 0) await _addOrEditWord(vm: vm, index: idx);
                                              },
                                              onDelete: () async {
                                                final ok = await showConfirmDeleteDialog(context, word.eng);
                                                if (ok) {
                                                  // Keep a copy for undo
                                                  final removed = word;
                                                  await vm.deleteById(word.id);
                                                  if (!mounted) return;
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Text('"${removed.eng}" deleted.'),
                                                      action: SnackBarAction(
                                                        label: 'UNDO',
                                                        onPressed: () {
                                                          vm.restoreWord(removed);
                                                        },
                                                      ),
                                                    ),
                                                  );
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (vm.selectionMode)
                                    Positioned(
                                      top: 6,
                                      left: 6,
                                      child: AnimatedScale(
                                        scale: isSelected ? 1.0 : 0.9,
                                        duration: const Duration(milliseconds: 150),
                                        child: CircleAvatar(
                                          radius: 12,
                                          backgroundColor: isSelected
                                              ? Theme.of(context).colorScheme.primary
                                              : Colors.black12,
                                          child: Icon(
                                            isSelected ? Icons.check : Icons.circle,
                                            size: 14,
                                            color: isSelected ? Colors.white : Colors.white70,
                                          ),
                                        ),
                                      ),
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
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await _addOrEditWord(vm: vm);
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Word'),
          ),
        );
      },
    );
  }

  Future<void> _addOrEditWord({required DictionaryViewModel vm, int? index}) async {
    final isEdit = index != null;
    final editIndex = index ?? -1;
    final engController = TextEditingController(text: isEdit ? vm.words[editIndex].eng : '');
    final rusController = TextEditingController(text: isEdit ? vm.words[editIndex].rus : '');
    final engFocus = FocusNode();
    final rusFocus = FocusNode();
    bool autoTranslate = true;
    bool isSaving = false;
    bool didEdit = false;

    Future<bool> save(StateSetter setDialogState) async {
      final eng = engController.text.trim();
      String rus = rusController.text.trim();
      if (eng.isEmpty) return false;
      if (autoTranslate && rus.isEmpty) {
        try {
          rus = await vm.translateToRu(eng);
        } catch (_) {}
      }
      setDialogState(() => isSaving = true);
      bool success = false;
      if (isEdit) {
        final ok = await vm.editWord(editIndex, eng: eng, rus: rus);
        if (ok) {
          didEdit = true;
          success = true;
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This word already exists in this vocabulary.')),
            );
          }
        }
      } else {
        final ok = await vm.addWord(eng: eng, rus: rus);
        if (ok) {
          success = true;
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('This word already exists in this vocabulary.')),
            );
          }
        }
      }
      if (context.mounted) {
        setDialogState(() => isSaving = false);
      }
      return success;
    }

    final added = await showDialog<bool>(
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
                  onSubmitted: (_) async {
                    final ok = await save(setDialogState);
                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.pop(context, isEdit ? null : true);
                    }
                  },
                  onChanged: (text) async {
                    if (!autoTranslate) return;
                    final trimmed = text.trim();
                    _debounce?.cancel();
                    if (trimmed.isEmpty) return;
                    _debounce = Timer(
                      const Duration(milliseconds: 500),
                      () async {
                        try {
                          final translated = await vm.translateToRu(trimmed);
                          if (rusController.text != translated) {
                            final newValue = TextEditingValue(
                              text: translated,
                              selection: TextSelection.collapsed(offset: translated.length),
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
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) async {
                    final ok = await save(setDialogState);
                    if (!context.mounted) return;
                    if (ok) {
                      Navigator.pop(context, isEdit ? null : true);
                    }
                  },
                ),
                Row(
                  children: [
                    Checkbox(
                      value: autoTranslate,
                      onChanged: isSaving ? null : (v) => setDialogState(() => autoTranslate = v ?? true),
                    ),
                    const Text('Auto-translate'),
                  ],
                ),
                if (isSaving) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: const [
                      SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                      SizedBox(width: 10),
                      Text('Saving...'),
                    ],
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(context, rootNavigator: true).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        final ok = await save(setDialogState);
                        if (!context.mounted) return;
                        if (ok) {
                          Navigator.of(context, rootNavigator: true).pop(!isEdit);
                        }
                      },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );

    if (added == true) {
      if (!mounted) return;
      await toasts.showWordAddedPopup(context);
    }
    if (didEdit) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Word updated.')),
      );
    }
  }

  Future<void> _showWordExplanation(BuildContext context, DictionaryViewModel vm, int index) async {
    if (index < 0 || index >= vm.words.length) return;
    String shortAnswer = vm.currentDescription(index);
    String? longAnswer = vm.currentLongDescription(index);
    int tabIndex = 0;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> regenerateShort() async {
              setState(() => shortAnswer = 'Loading...');
              try {
                final newText = await vm.regenerateDescription(index);
                if (!context.mounted) return;
                setState(() => shortAnswer = newText);
              } catch (e) {
                if (!context.mounted) return;
                setState(() => shortAnswer = 'Error: $e');
              }
            }

            Future<void> generateOrRegenerateLong() async {
              setState(() => longAnswer = 'Loading...');
              try {
                final newText = await vm.generateOrRegenerateLong(index);
                if (!context.mounted) return;
                setState(() => longAnswer = newText);
              } catch (e) {
                if (!context.mounted) return;
                setState(() => longAnswer = 'Error: $e');
              }
            }

            return AlertDialog(
              title: Text(
                'Explanation for "${vm.words[index].eng}"',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SizedBox(
                  height: 520,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12, right: 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Builder(
                                  builder: (context) {
                                    final bool hasLong =
                                        (longAnswer != null && longAnswer!.trim().isNotEmpty && longAnswer != 'Loading...' && longAnswer != 'No detailed description yet.');
                                    final bool isDetailed = tabIndex == 1;
                                    // For Short tab: text only inside the container
                                    if (!isDetailed) {
                                      return _BookLikeContainer(
                                        backgroundColor: const Color(0xFFFFF8E7),
                                        borderColor: const Color(0xFFD9C9A3),
                                        spineColor: const Color(0xFFE0D2B6),
                                        child: Padding(
                                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: SingleChildScrollView(
                                                  child: Text(
                                                    shortAnswer,
                                                    style: const TextStyle(height: 1.35),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Image.asset(
                                                'assets/media/cody_info.png',
                                                width: 120,
                                                height: 120,
                                                filterQuality: FilterQuality.high,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }
                                    // For Detailed tab: place the image inside the container on the right if content exists
                                    return _BookLikeContainer(
                                      backgroundColor: const Color(0xFFEFF6FF),
                                      borderColor: const Color(0xFFB6D0F5),
                                      spineColor: const Color(0xFFC8DBF8),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: SingleChildScrollView(
                                                child: Text(
                                                  longAnswer ?? 'No detailed description yet.',
                                                  style: const TextStyle(height: 1.35),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Image.asset(
                                              'assets/media/cody_info.png',
                                              width: 120,
                                              height: 120,
                                              filterQuality: FilterQuality.high,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: tabIndex == 0
                                    ? IconButton(
                                        tooltip: 'Regenerate short',
                                        onPressed: regenerateShort,
                                        icon: const Icon(Icons.autorenew),
                                      )
                                    : IconButton(
                                        tooltip: (longAnswer == null || longAnswer == 'Loading...')
                                            ? 'Generate a more detailed description'
                                            : 'Regenerate detailed description',
                                        onPressed: generateOrRegenerateLong,
                                        icon: const Icon(Icons.autorenew),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          IconButton(
                            tooltip: 'Short',
                            onPressed: () => setState(() => tabIndex = 0),
                            icon: Icon(
                              Icons.flash_on,
                              color: tabIndex == 0 ? Theme.of(context).colorScheme.primary : null,
                            ),
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            tooltip: 'Detailed',
                            onPressed: () => setState(() => tabIndex = 1),
                            icon: Icon(
                              Icons.article_outlined,
                              color: tabIndex == 1 ? Theme.of(context).colorScheme.primary : null,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
}

class _DictionarySidebar extends StatelessWidget {
  const _DictionarySidebar();

  @override
  Widget build(BuildContext context) {
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
  }
}

class _BookLikeContainer extends StatelessWidget {
  const _BookLikeContainer({
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    required this.spineColor,
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final Color spineColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 6)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 10,
              decoration: BoxDecoration(
                color: spineColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: child,
          ),
        ],
      ),
    );
  }
}
