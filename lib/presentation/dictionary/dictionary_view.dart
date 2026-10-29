import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';

import '../../domain/entities/word_entity.dart';
import '../../domain/exceptions/storage_exceptions.dart';
import '../app_scope.dart';
import '../dialogs/confirm_bulk_delete_dialog.dart';
import '../dialogs/confirm_delete_dialog.dart';
import '../theme/app_tokens.dart';
import '../vocabs/word_collections_dialog.dart';
import '../widgets/added_word_popup.dart' as toasts;
import '../widgets/brand_mark.dart';
import '../widgets/empty_state.dart';
import '../widgets/theme_toggle_button.dart';
import 'dictionary_view_model.dart';
import 'widgets/dictionary_hero.dart';
import 'widgets/selection_bar.dart';
import 'widgets/storage_error_view.dart';
import 'widgets/word_card.dart';
import 'widgets/word_details_sheet.dart';
import 'widgets/word_editor_dialog.dart';
import '../l10n/app_strings.dart';

class DictionaryView extends StatefulWidget {
  const DictionaryView({super.key, this.dataGeneration = 0});

  /// Changes when the stored data was replaced (restore); triggers a reload.
  final int dataGeneration;

  @override
  State<DictionaryView> createState() => _DictionaryViewState();
}

class _DictionaryViewState extends State<DictionaryView> {
  static const double _minCardWidth = 240;

  /// Card height at normal text size; grows with the text scale.
  static const double _cardHeight = 148;
  static const double _gap = AppSpacing.lg;

  late final DictionaryViewModel vm;
  final TextEditingController _search = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    vm = DictionaryViewModel(AppScope.read(context));
    vm.load().whenComplete(() {
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
  void didUpdateWidget(DictionaryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dataGeneration != oldWidget.dataGeneration) {
      if (vm.selectionMode) vm.toggleSelectionMode(false);
      vm.load();
    }
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

  Future<void> _addExamples() async {
    final messenger = ScaffoldMessenger.of(context);
    await _guard(messenger, vm.addExampleWords);
  }

  Future<void> _editWord(String id) async {
    if (vm.wordById(id) == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;
    final saved = await showWordEditorDialog(context, vm: vm, wordId: id);
    if (!saved) return;
    messenger.showSnackBar(SnackBar(content: Text(s.wordUpdated)));
  }

  Future<void> _deleteWord(WordEntity word) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;
    final ok = await showConfirmDeleteDialog(context, word.source);
    if (!ok) return;
    try {
      await vm.deleteById(word.id);
    } on StorageException catch (e) {
      _showStorageError(messenger, e);
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text(s.wordDeleted(word.source)),
        action: SnackBarAction(
          label: s.undo,
          onPressed: () => _guard(messenger, () => vm.restoreWord(word)),
        ),
      ),
    );
  }

  /// Reports a failed save. The data on disk is unchanged in that case.
  void _showStorageError(ScaffoldMessengerState messenger, StorageException e) {
    messenger.showSnackBar(
      SnackBar(
        // The messenger outlives await gaps; take the strings from it.
        content: Text(
          messenger.context.s.notSaved(messenger.context.s.storageError(e)),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  Future<void> _guard(
    ScaffoldMessengerState messenger,
    Future<void> Function() op,
  ) async {
    try {
      await op();
    } on StorageException catch (e) {
      _showStorageError(messenger, e);
    }
  }

  Future<void> _deleteSelected() async {
    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;
    final ok = await showConfirmBulkDeleteDialog(context, vm.selectedCount);
    if (!ok) return;
    // Capture removed words before deletion for undo
    final removed = vm.words
        .where((w) => vm.selected.contains(w.id))
        .toList(growable: false);
    StorageException? failure;
    try {
      await vm.deleteSelected();
    } on StorageException catch (e) {
      failure = e;
    }
    // Only offer Undo for words that really were deleted.
    final deleted = removed
        .where((w) => vm.wordById(w.id) == null)
        .toList(growable: false);
    if (failure != null) {
      _showStorageError(messenger, failure);
      if (deleted.isEmpty) return;
    }
    vm.toggleSelectionMode(false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(s.wordsDeleted(deleted.length)),
        action: SnackBarAction(
          label: s.undo,
          onPressed: () => _guard(messenger, () => vm.restoreWords(deleted)),
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

  /// Long-press on a card when dragging is not possible: say why instead of
  /// silently doing nothing.
  void _explainReorderBlocked() {
    final reason = switch (vm.reorderBlockedReason) {
      ReorderBlock.search => context.s.reorderBlockedSearch,
      ReorderBlock.sort => context.s.reorderBlockedSort,
      null => null,
    };
    if (reason == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(reason)));
  }

  // ---------------------------------------------------------------------------
  // Build

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        SingleActivator(
          LogicalKeyboardKey.keyN,
          control: !AppStrings.isApple,
          meta: AppStrings.isApple,
        ): _addWord,
        SingleActivator(
          LogicalKeyboardKey.keyF,
          control: !AppStrings.isApple,
          meta: AppStrings.isApple,
        ): _searchFocus.requestFocus,
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
    // Phones and short windows get a slim header so more words fit.
    final compact = !wide || MediaQuery.sizeOf(context).height < 720;
    // The one-row toolbar (search, sort, add) only fits on wide screens with
    // normal-sized text; otherwise sort goes into a menu and "Add word" is a
    // floating button.
    final inlineToolbar =
        MediaQuery.sizeOf(context).width >= 1100 &&
        AppBreakpoints.textScale(context) <= 1.3;
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
                                Expanded(child: BrandMark(size: 30)),
                                ThemeToggleButton(),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                          ],
                          DictionaryHero(
                            total: vm.words.length,
                            explained: explained,
                            compact: compact,
                            aiAvailable: vm.aiAvailable,
                          ),
                          SizedBox(
                            height: compact ? AppSpacing.md : AppSpacing.xl,
                          ),
                          _buildToolbar(context, inlineToolbar),
                          SizedBox(
                            height: compact ? AppSpacing.md : AppSpacing.lg,
                          ),
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
      floatingActionButton: inlineToolbar
          ? null
          : AnimatedScale(
              scale: vm.selectionMode || vm.loadError != null ? 0 : 1,
              duration: AppMotion.medium,
              curve: AppMotion.emphasized,
              child: FloatingActionButton.extended(
                // Tabs stay alive in an IndexedStack, so several FABs coexist;
                // without distinct tags opening a page crashes the hero animation.
                heroTag: null,
                tooltip: context.s.addWordTooltip(context.s.shortcut('N')),
                onPressed: vm.selectionMode || vm.loadError != null
                    ? null
                    : _addWord,
                icon: const Icon(Icons.add_rounded),
                label: Text(context.s.addWord),
              ),
            ),
    );
  }

  Widget _buildToolbar(BuildContext context, bool wide) {
    final search = ListenableBuilder(
      listenable: _search,
      // Mark the tappable search bar as a text field; its hint is already
      // read out as the label, so no extra label (it would be read twice).
      builder: (context, _) => Semantics(
        textField: true,
        child: SearchBar(
          controller: _search,
          focusNode: _searchFocus,
          hintText: wide
              ? context.s.searchHintLong(context.s.shortcut('F'))
              : context.s.searchHintShort,
          leading: const Icon(Icons.search_rounded),
          trailing: [
            if (_search.text.isNotEmpty)
              IconButton(
                tooltip: context.s.clear,
                onPressed: _search.clear,
                icon: const Icon(Icons.close_rounded),
              ),
            if (!wide) _SortMenu(value: vm.sortMode, onChanged: vm.setSort),
            if (!wide) _selectButton(),
          ],
        ),
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
          segments: [
            ButtonSegment(
              value: SortMode.alphaAsc,
              icon: Icon(Icons.arrow_downward_rounded, size: 18),
              label: Text(context.s.sortAZ),
              tooltip: context.s.sortAZTooltip,
            ),
            ButtonSegment(
              value: SortMode.alphaDesc,
              icon: Icon(Icons.arrow_upward_rounded, size: 18),
              label: Text(context.s.sortZA),
              tooltip: context.s.sortZATooltip,
            ),
            ButtonSegment(
              value: SortMode.dateAdded,
              icon: Icon(Icons.schedule_rounded, size: 18),
              label: Text(context.s.sortRecent),
              tooltip: context.s.sortRecentTooltip,
            ),
          ],
          selected: {?vm.sortMode},
          onSelectionChanged: (s) => vm.setSort(s.isEmpty ? null : s.first),
        ),
        const SizedBox(width: AppSpacing.sm),
        _selectButton(),
        const SizedBox(width: AppSpacing.sm),
        // On wide screens the add button lives here instead of a floating
        // button, so it never covers a card.
        FilledButton.icon(
          style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(0, 52)),
          ),
          onPressed: vm.selectionMode || vm.loadError != null ? null : _addWord,
          icon: const Icon(Icons.add_rounded),
          label: Text(context.s.addWord),
        ),
      ],
    );
  }

  Widget _selectButton() {
    return IconButton(
      tooltip: vm.selectionMode
          ? context.s.doneSelecting
          : context.s.selectWords,
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
    final loadError = vm.loadError;
    if (loadError != null) {
      return StorageErrorView(
        error: loadError,
        onRetry: vm.load,
        onRecover: vm.recover,
      );
    }
    if (vm.words.isEmpty) {
      return EmptyState(
        image: CodyArt.standing,
        title: context.s.emptyTitle,
        message: context.s.emptyMessage(
          translation: vm.translationAvailable,
          ai: vm.aiAvailable,
        ),
        action: Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            FilledButton.icon(
              onPressed: _addWord,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.s.addFirstWord),
            ),
            OutlinedButton.icon(
              onPressed: _addExamples,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(context.s.addExamples),
            ),
          ],
        ),
      );
    }
    if (vm.filtered.isEmpty) {
      final q = _search.text.trim();
      return EmptyState(
        image: CodyArt.reading,
        title: context.s.noMatchesTitle,
        message: context.s.noMatchesMessage(q),
        action: FilledButton.tonalIcon(
          onPressed: () => _addWord(initialEng: q),
          icon: const Icon(Icons.add_rounded),
          label: Text(context.s.addQuery(q)),
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
          // Only the full list in manual order can be reordered; see
          // DictionaryViewModel.canReorder.
          dragEnabled: vm.canReorder,
          onReorder: (oldIndex, newIndex) {
            _guard(
              ScaffoldMessenger.of(context),
              () => vm.reorder(oldIndex, newIndex),
            );
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
            mainAxisExtent: _cardHeight * AppBreakpoints.textScale(context),
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
                  generating: vm.isGenerating(word.id, ExplanationKind.short),
                  generationError: vm.generationError(
                    word.id,
                    ExplanationKind.short,
                  ),
                  aiAvailable: vm.aiAvailable,
                  onLongPress: vm.canReorder || vm.selectionMode
                      ? null
                      : _explainReorderBlocked,
                  onToggleSelect: () => vm.toggleSelect(word.id),
                  onExplain: () => _openDetails(word),
                  onEdit: () => _editWord(word.id),
                  onDelete: () => _deleteWord(word),
                  onCollections: () => showWordCollectionsDialog(
                    context,
                    wordId: word.id,
                    word: word.source,
                  ),
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
        item(
          SortMode.alphaAsc,
          Icons.arrow_downward_rounded,
          context.s.sortMenuAZ,
        ),
        item(
          SortMode.alphaDesc,
          Icons.arrow_upward_rounded,
          context.s.sortMenuZA,
        ),
        item(
          SortMode.dateAdded,
          Icons.schedule_rounded,
          context.s.sortRecentTooltip,
        ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: context.s.sortTooltip,
        isSelected: value != null,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.sort_rounded),
      ),
    );
  }
}
