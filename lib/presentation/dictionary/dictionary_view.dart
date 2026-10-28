import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../../domain/entities/word_entity.dart';
import '../dialogs/confirm_bulk_delete_dialog.dart';
import '../dialogs/confirm_delete_dialog.dart';
import '../theme/app_tokens.dart';
import '../widgets/added_word_popup.dart' as toasts;
import '../widgets/brand_mark.dart';
import '../widgets/empty_state.dart';
import '../widgets/theme_toggle_button.dart';
import 'dictionary_view_model.dart';
import 'widgets/dictionary_hero.dart';
import 'widgets/selection_bar.dart';
import 'widgets/word_card.dart';
import 'widgets/word_details_sheet.dart';
import 'widgets/word_editor_dialog.dart';

class DictionaryView extends StatefulWidget {
  final List<WordEntity> defaultWords;
  const DictionaryView({super.key, required this.defaultWords});

  @override
  State<DictionaryView> createState() => _DictionaryViewState();
}

class _DictionaryViewState extends State<DictionaryView> {
  static const double _minCardWidth = 240;
  static const double _cardHeight = 156;
  static const double _gap = AppSpacing.lg;

  late final DictionaryViewModel vm;
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  bool _loaded = false;

  /// Sort chosen by the user; null while the grid is in manual order.
  SortMode? _sort;

  @override
  void initState() {
    super.initState();
    vm = DictionaryViewModel();
    vm.load(seed: widget.defaultWords).whenComplete(() {
      if (mounted) setState(() => _loaded = true);
    });
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
    _searchFocus.dispose();
    vm.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions

  Future<void> _addWord({String? initialEng}) async {
    final added = await showWordEditorDialog(
      context,
      vm: vm,
      initialEng: initialEng,
    );
    if (!added || !mounted) return;
    final eng = vm.words.isEmpty ? null : vm.words.last.source;
    await toasts.showWordAddedPopup(context, word: eng);
  }

  Future<void> _editWord(String id) async {
    final idx = vm.words.indexWhere((w) => w.id == id);
    if (idx < 0) return;
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showWordEditorDialog(context, vm: vm, index: idx);
    if (!saved) return;
    messenger.showSnackBar(const SnackBar(content: Text('Word updated.')));
  }

  Future<void> _deleteWord(WordEntity word) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showConfirmDeleteDialog(context, word.source);
    if (!ok) return;
    await vm.deleteById(word.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text('"${word.source}" deleted.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => vm.restoreWord(word),
        ),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showConfirmBulkDeleteDialog(context, vm.selectedCount);
    if (!ok) return;
    // Capture removed words before deletion for undo
    final removed = vm.words
        .where((w) => vm.selected.contains(w.id))
        .toList(growable: false);
    await vm.deleteSelected();
    vm.toggleSelectionMode(false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          removed.length == 1
              ? '1 word deleted.'
              : '${removed.length} words deleted.',
        ),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => vm.restoreWords(removed),
        ),
      ),
    );
  }

  void _openDetails(WordEntity word) {
    showWordDetails(
      context,
      vm: vm,
      wordId: word.id,
      onEdit: () => _editWord(word.id),
      onDelete: () => _deleteWord(word),
    );
  }

  void _setSort(SortMode? mode) {
    setState(() => _sort = mode);
    if (mode != null) vm.setSort(mode);
  }

  // ---------------------------------------------------------------------------
  // Build

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): _addWord,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.escape): () {
          if (vm.selectionMode) vm.toggleSelectionMode(false);
        },
      },
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(
          listenable: vm,
          builder: (context, _) => _buildScaffold(context),
        ),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final wide = AppBreakpoints.isWide(context);
    final pad = wide ? AppSpacing.xxl : AppSpacing.lg;
    final explained = vm.words
        .where(
          (w) =>
              w.shortExplanation != null &&
              w.shortExplanation!.trim().isNotEmpty,
        )
        .length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppBreakpoints.maxContentWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(pad, pad, pad, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!wide) ...[
                            const Row(
                              children: [
                                Expanded(child: BrandMark(size: 36)),
                                ThemeToggleButton(),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                          ],
                          DictionaryHero(
                            total: vm.words.length,
                            explained: explained,
                            compact: !wide,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          _buildToolbar(context, wide),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
                    Expanded(child: _buildContent(context, pad)),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: AppSpacing.xl,
              child: Center(
                child: SelectionBar(
                  visible: vm.selectionMode,
                  selectedCount: vm.selectedCount,
                  allSelected: vm.areAllSelected,
                  onClose: () => vm.toggleSelectionMode(false),
                  onToggleAll: vm.areAllSelected
                      ? vm.clearSelection
                      : vm.selectAll,
                  onDelete: _deleteSelected,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: AnimatedScale(
        scale: vm.selectionMode ? 0 : 1,
        duration: AppMotion.medium,
        curve: AppMotion.emphasized,
        child: FloatingActionButton.extended(
          tooltip: 'Add word (Ctrl+N)',
          onPressed: vm.selectionMode ? null : _addWord,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add word'),
        ),
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, bool wide) {
    final search = ListenableBuilder(
      listenable: _search,
      builder: (context, _) => SearchBar(
        controller: _search,
        focusNode: _searchFocus,
        hintText: wide
            ? 'Search words or translations  (Ctrl+F)'
            : 'Search words',
        leading: const Icon(Icons.search_rounded),
        trailing: [
          if (_search.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              onPressed: _search.clear,
              icon: const Icon(Icons.close_rounded),
            ),
          if (!wide) _SortMenu(value: _sort, onChanged: _setSort),
          if (!wide) _selectButton(),
        ],
      ),
    );

    if (!wide) return search;

    return Row(
      children: [
        Expanded(child: search),
        const SizedBox(width: AppSpacing.md),
        SegmentedButton<SortMode>(
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(0, 52)),
          ),
          segments: const [
            ButtonSegment(
              value: SortMode.alphaAsc,
              icon: Icon(Icons.arrow_downward_rounded, size: 18),
              label: Text('A–Z'),
              tooltip: 'Sort A to Z',
            ),
            ButtonSegment(
              value: SortMode.alphaDesc,
              icon: Icon(Icons.arrow_upward_rounded, size: 18),
              label: Text('Z–A'),
              tooltip: 'Sort Z to A',
            ),
            ButtonSegment(
              value: SortMode.dateAdded,
              icon: Icon(Icons.schedule_rounded, size: 18),
              label: Text('Recent'),
              tooltip: 'Newest first',
            ),
          ],
          selected: {?_sort},
          onSelectionChanged: (s) => _setSort(s.isEmpty ? null : s.first),
        ),
        const SizedBox(width: AppSpacing.sm),
        _selectButton(),
      ],
    );
  }

  Widget _selectButton() {
    return IconButton(
      tooltip: vm.selectionMode ? 'Done selecting' : 'Select words',
      isSelected: vm.selectionMode,
      onPressed: vm.words.isEmpty
          ? null
          : () => vm.toggleSelectionMode(!vm.selectionMode),
      icon: const Icon(Icons.checklist_rounded),
    );
  }

  Widget _buildContent(BuildContext context, double pad) {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.words.isEmpty) {
      return EmptyState(
        image: CodyArt.standing,
        title: 'Your dictionary is empty',
        message:
            'Add your first word — Cody will translate it and explain how '
            'it\'s used.',
        action: FilledButton.icon(
          onPressed: _addWord,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add your first word'),
        ),
      );
    }
    if (vm.filtered.isEmpty) {
      final q = _search.text.trim();
      return EmptyState(
        image: CodyArt.reading,
        title: 'No matches',
        message:
            'Nothing found for "$q". Try another spelling or add it as a '
            'new word.',
        action: FilledButton.tonalIcon(
          onPressed: () => _addWord(initialEng: q),
          icon: const Icon(Icons.add_rounded),
          label: Text('Add "$q"'),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth - pad * 2;
        final columns = ((available + _gap) / (_minCardWidth + _gap))
            .floor()
            .clamp(1, 6);
        final radius = BorderRadius.circular(AppRadius.lg);
        final scheme = Theme.of(context).colorScheme;

        return ReorderableGridView.builder(
          padding: EdgeInsets.fromLTRB(pad, AppSpacing.xs, pad, 120),
          itemCount: vm.filtered.length,
          dragEnabled: !vm.selectionMode,
          onReorder: (oldIndex, newIndex) {
            setState(() => _sort = null);
            vm.reorder(oldIndex, newIndex);
          },
          dragWidgetBuilderV2: DragWidgetBuilderV2(
            builder: (index, child, _) => Material(
              type: MaterialType.transparency,
              child: Transform.scale(
                scale: 1.04,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    boxShadow: [
                      BoxShadow(
                        color: scheme.shadow.withValues(alpha: 0.25),
                        blurRadius: 32,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
            ),
          ),
          placeholderBuilder: (_, _, _) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              color: scheme.primaryContainer.withValues(alpha: 0.35),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: _gap,
            mainAxisSpacing: _gap,
            mainAxisExtent: _cardHeight,
          ),
          itemBuilder: (context, i) {
            final word = vm.filtered[i];
            final removing = vm.removing.contains(word.id);
            return AnimatedScale(
              key: ValueKey(word.id),
              scale: removing ? 0.9 : 1,
              duration: AppMotion.medium,
              child: AnimatedOpacity(
                opacity: removing ? 0 : 1,
                duration: AppMotion.medium,
                child: WordCard(
                  word: word,
                  selectionMode: vm.selectionMode,
                  selected: vm.selected.contains(word.id),
                  onTap: () => _openDetails(word),
                  onToggleSelect: () => vm.toggleSelect(word.id),
                  onExplain: () => _openDetails(word),
                  onEdit: () => _editWord(word.id),
                  onDelete: () => _deleteWord(word),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.value, required this.onChanged});

  final SortMode? value;
  final ValueChanged<SortMode?> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget item(SortMode mode, IconData icon, String label) {
      return MenuItemButton(
        leadingIcon: Icon(icon),
        trailingIcon: value == mode ? const Icon(Icons.check_rounded) : null,
        onPressed: () => onChanged(value == mode ? null : mode),
        child: Text(label),
      );
    }

    return MenuAnchor(
      menuChildren: [
        item(SortMode.alphaAsc, Icons.arrow_downward_rounded, 'A to Z'),
        item(SortMode.alphaDesc, Icons.arrow_upward_rounded, 'Z to A'),
        item(SortMode.dateAdded, Icons.schedule_rounded, 'Newest first'),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: 'Sort',
        isSelected: value != null,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.sort_rounded),
      ),
    );
  }
}
