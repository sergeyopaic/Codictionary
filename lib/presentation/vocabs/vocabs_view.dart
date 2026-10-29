import 'package:flutter/material.dart';

import '../../domain/entities/vocabulary.dart';
import '../../domain/exceptions/storage_exceptions.dart';
import '../app_scope.dart';
import '../dialogs/confirm_dialog.dart';
import '../theme/app_tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_header.dart';
import 'create_vocabulary_dialog.dart';
import 'vocabs_view_model.dart';
import 'vocabulary_words_view.dart';
import '../l10n/app_strings.dart';

class VocabsView extends StatefulWidget {
  const VocabsView({super.key, this.isActive = true});

  /// Whether this tab is on screen. Becoming active reloads, so words added
  /// or deleted in the dictionary show up in the collections.
  final bool isActive;

  @override
  State<VocabsView> createState() => _VocabsViewState();
}

class _VocabsViewState extends State<VocabsView> {
  late final VocabsViewModel vm;

  @override
  void initState() {
    super.initState();
    vm = VocabsViewModel(AppScope.read(context));
    vm.load();
  }

  @override
  void didUpdateWidget(VocabsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) vm.load();
  }

  @override
  void dispose() {
    vm.dispose();
    super.dispose();
  }

  void _notSaved(ScaffoldMessengerState messenger, StorageException e) {
    // The messenger outlives await gaps; take the strings from it.
    final s = messenger.context.s;
    messenger.showSnackBar(
      SnackBar(content: Text(s.notSaved(s.storageError(e)))),
    );
  }

  Future<void> _create() async {
    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;
    final res = await showCreateVocabularyDialog(context);
    if (res == null) return;
    try {
      await vm.create(
        name: _name(res, s),
        description: res['description'] ?? '',
        iconPath: res['icon'] ?? vocabIconPath(1),
      );
    } on StorageException catch (e) {
      _notSaved(messenger, e);
    }
  }

  Future<void> _edit(Vocabulary v) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;
    final res = await showCreateVocabularyDialog(
      context,
      initialName: v.name,
      initialDescription: v.description,
      initialIcon: v.iconPath,
    );
    if (res == null) return;
    try {
      await vm.updateDetails(
        v.copyWith(
          name: _name(res, s),
          description: res['description'] ?? '',
          iconPath: res['icon'] ?? v.iconPath,
        ),
      );
    } on StorageException catch (e) {
      _notSaved(messenger, e);
    }
  }

  Future<void> _delete(Vocabulary v) async {
    final messenger = ScaffoldMessenger.of(context);
    final s = context.s;
    final count = vm.wordsOf(v).length;
    final ok = await showConfirmDialog(
      context,
      title: s.deleteVocabTitle,
      message: s.deleteVocabMessage(v.name, count),
    );
    if (!ok) return;
    final ({Vocabulary vocabulary, int index})? deleted;
    try {
      deleted = await vm.delete(v.id);
    } on StorageException catch (e) {
      _notSaved(messenger, e);
      return;
    }
    if (deleted == null) return;
    final undo = deleted;
    messenger.hideCurrentSnackBar(); // Undo must not wait in the queue
    messenger.showSnackBar(
      SnackBar(
        content: Text(s.vocabDeleted(v.name)),
        action: SnackBarAction(
          label: s.undo,
          onPressed: () async {
            try {
              await vm.restore(undo.vocabulary, undo.index);
            } on StorageException catch (e) {
              _notSaved(messenger, e);
            }
          },
        ),
      ),
    );
  }

  void _open(Vocabulary v) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => VocabularyWordsView(vm: vm, vocabularyId: v.id),
      ),
    );
  }

  static String _name(Map<String, String> res, AppStrings s) =>
      (res['name'] ?? '').isEmpty ? s.untitled : res['name']!;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: vm,
      builder: (context, _) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    final wide = AppBreakpoints.isWide(context);
    final pad = wide ? AppSpacing.xxl : AppSpacing.lg;
    final count = vm.vocabularies.length;
    final canEdit = vm.loaded && vm.loadError == null;
    // The header button needs room next to the title; with less width or
    // large text it becomes a floating button instead.
    final headerButton =
        MediaQuery.sizeOf(context).width >= 1100 &&
        AppBreakpoints.textScale(context) <= 1.3;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.maxContentWidth,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, AppSpacing.xl),
                  child: PageHeader(
                    title: context.s.navVocabularies,
                    subtitle: count == 0
                        ? context.s.vocabsSubtitleEmpty
                        : context.s.collectionCount(count),
                    trailing: headerButton && canEdit
                        ? FilledButton.icon(
                            onPressed: _create,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(context.s.newVocabulary),
                          )
                        : null,
                  ),
                ),
                Expanded(child: _buildContent(pad)),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: headerButton || !canEdit
          ? null
          : FloatingActionButton.extended(
              // Tabs stay alive in an IndexedStack, so several FABs coexist;
              // without distinct tags opening a page crashes the hero animation.
              heroTag: null,
              icon: const Icon(Icons.add_rounded),
              label: Text(context.s.newVocabulary),
              onPressed: _create,
            ),
    );
  }

  Widget _buildContent(double pad) {
    if (!vm.loaded) return const Center(child: CircularProgressIndicator());
    final loadError = vm.loadError;
    if (loadError != null) {
      return EmptyState(
        image: CodyArt.delete,
        title: context.s.cantOpenVocabs,
        message: context.s.nothingChanged(context.s.storageError(loadError)),
        action: FilledButton.icon(
          onPressed: vm.load,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(context.s.tryAgain),
        ),
      );
    }
    if (vm.vocabularies.isEmpty) {
      return EmptyState(
        image: CodyArt.reading,
        title: context.s.noVocabsTitle,
        message: context.s.noVocabsMessage,
        action: FilledButton.icon(
          onPressed: _create,
          icon: const Icon(Icons.add_rounded),
          label: Text(context.s.createVocab),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AppSpacing.lg;
        final available = constraints.maxWidth - pad * 2;
        final columns = ((available + gap) / (300 + gap)).floor().clamp(1, 5);
        return GridView.builder(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, 120),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            mainAxisExtent: 112 * AppBreakpoints.textScale(context),
          ),
          itemCount: vm.vocabularies.length,
          itemBuilder: (context, i) {
            final v = vm.vocabularies[i];
            return _VocabCard(
              vocab: v,
              wordCount: vm.wordsOf(v).length,
              onOpen: () => _open(v),
              onEdit: () => _edit(v),
              onDelete: () => _delete(v),
            );
          },
        );
      },
    );
  }
}

class _VocabCard extends StatelessWidget {
  final Vocabulary vocab;
  final int wordCount;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _VocabCard({
    required this.vocab,
    required this.wordCount,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
          ),
          child: Row(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  color: scheme.secondaryContainer.withValues(alpha: 0.7),
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Image.asset(
                  // Decorative: a text next to it says the same.
                  excludeFromSemantics: true,

                  vocabIconHiRes(vocab.iconPath),
                  filterQuality: FilterQuality.high,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.menu_book_rounded,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      vocab.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      context.s.wordCount(wordCount),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      vocab.description.isEmpty
                          ? context.s.noDescription
                          : vocab.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: vocab.description.isEmpty
                            ? FontStyle.italic
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              MenuAnchor(
                alignmentOffset: const Offset(-160, 4),
                menuChildren: [
                  MenuItemButton(
                    leadingIcon: const Icon(Icons.edit_outlined),
                    onPressed: onEdit,
                    child: Text(context.s.edit),
                  ),
                  MenuItemButton(
                    leadingIcon: Icon(
                      Icons.delete_outline_rounded,
                      color: scheme.error,
                    ),
                    onPressed: onDelete,
                    child: Text(
                      context.s.delete,
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                ],
                builder: (context, controller, _) => IconButton(
                  tooltip: context.s.options,
                  icon: const Icon(Icons.more_vert_rounded),
                  onPressed: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
