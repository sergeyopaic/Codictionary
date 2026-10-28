import 'package:flutter/material.dart';

import '../../core/di/service_locator.dart';
import '../../domain/exceptions/storage_exceptions.dart';
import '../../services/storage_service.dart';
import '../dialogs/confirm_dialog.dart';
import '../theme/app_tokens.dart';
import '../widgets/empty_state.dart';
import '../widgets/page_header.dart';
import 'create_vocabulary_dialog.dart';

class VocabsView extends StatefulWidget {
  const VocabsView({super.key});

  @override
  State<VocabsView> createState() => _VocabsViewState();
}

class _VocabsViewState extends State<VocabsView> {
  final List<_Vocab> _vocabs = [];
  late final StorageService _storage;
  bool _loaded = false;

  /// Set when stored vocabularies could not be read. Editing is disabled so
  /// the stored data is not replaced by an empty list.
  StorageException? _loadError;

  @override
  void initState() {
    super.initState();
    _storage = sl<StorageService>();
    _load();
  }

  Future<void> _load() async {
    List<Map<String, String>> raw = const [];
    StorageException? error;
    try {
      raw = await _storage.loadVocabularies();
    } on StorageException catch (e) {
      error = e;
    }
    if (!mounted) return;
    setState(() {
      _vocabs
        ..clear()
        ..addAll(raw.map(_Vocab.fromMap));
      _loadError = error;
      _loaded = true;
    });
  }

  /// Saves the list. On failure shows why and reloads what is really stored,
  /// so the screen never shows an unsaved change as saved.
  Future<void> _persist() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _storage.saveVocabularies(_vocabs.map((e) => e.toMap()).toList());
    } on StorageException catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Not saved: ${e.message}')),
      );
      await _load();
    }
  }

  Future<void> _create() async {
    final res = await showCreateVocabularyDialog(context);
    if (res == null) return;
    setState(() => _vocabs.add(_Vocab.fromMap(res)));
    await _persist();
  }

  Future<void> _editAt(int index) async {
    final v = _vocabs[index];
    final res = await showCreateVocabularyDialog(
      context,
      initialName: v.name,
      initialDescription: v.description,
      initialIcon: v.iconPath,
    );
    if (res == null) return;
    setState(() => _vocabs[index] = _Vocab.fromMap(res));
    await _persist();
  }

  Future<void> _deleteAt(int index) async {
    final v = _vocabs[index];
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showConfirmDialog(
      context,
      title: 'Delete vocabulary?',
      message: '"${v.name}" will be removed.',
    );
    if (!ok) return;
    setState(() => _vocabs.removeAt(index));
    await _persist();
    messenger.showSnackBar(
      SnackBar(
        content: Text('"${v.name}" deleted.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            if (!mounted) return;
            setState(() => _vocabs.insert(index.clamp(0, _vocabs.length), v));
            _persist();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = AppBreakpoints.isWide(context);
    final pad = wide ? AppSpacing.xxl : AppSpacing.lg;
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
                    title: 'Vocabularies',
                    subtitle: _vocabs.isEmpty
                        ? 'Organize words into themed collections'
                        : '${_vocabs.length} '
                              '${_vocabs.length == 1 ? 'collection' : 'collections'}',
                    trailing: wide && _loadError == null
                        ? FilledButton.icon(
                            onPressed: _create,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('New vocabulary'),
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
      floatingActionButton: wide || _loadError != null
          ? null
          : FloatingActionButton.extended(
              icon: const Icon(Icons.add_rounded),
              label: const Text('New vocabulary'),
              onPressed: _create,
            ),
    );
  }

  Widget _buildContent(double pad) {
    if (!_loaded) return const Center(child: CircularProgressIndicator());
    final loadError = _loadError;
    if (loadError != null) {
      return EmptyState(
        image: CodyArt.delete,
        title: "Can't open your vocabularies",
        message: '${loadError.message} Nothing was changed.',
        action: FilledButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      );
    }
    if (_vocabs.isEmpty) {
      return EmptyState(
        image: CodyArt.reading,
        title: 'No vocabularies yet',
        message:
            'Create collections like "Travel" or "Work" to keep related '
            'words together.',
        action: FilledButton.icon(
          onPressed: _create,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Create a vocabulary'),
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
            mainAxisExtent: 112,
          ),
          itemCount: _vocabs.length,
          itemBuilder: (context, i) => _VocabCard(
            vocab: _vocabs[i],
            onEdit: () => _editAt(i),
            onDelete: () => _deleteAt(i),
          ),
        );
      },
    );
  }
}

class _Vocab {
  final String name;
  final String description;
  final String iconPath;
  const _Vocab({
    required this.name,
    required this.description,
    required this.iconPath,
  });

  Map<String, String> toMap() => {
    'name': name,
    'description': description,
    'icon': iconPath,
  };

  factory _Vocab.fromMap(Map<String, String> m) => _Vocab(
    name: (m['name'] ?? '').isEmpty ? 'Untitled' : m['name']!,
    description: m['description'] ?? '',
    iconPath: m['icon'] ?? vocabIconPath(1),
  );
}

class _VocabCard extends StatelessWidget {
  final _Vocab vocab;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _VocabCard({
    required this.vocab,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      child: InkWell(
        onTap: onEdit,
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
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      vocab.description.isEmpty
                          ? 'No description'
                          : vocab.description,
                      maxLines: 2,
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
                    child: const Text('Edit'),
                  ),
                  MenuItemButton(
                    leadingIcon: Icon(
                      Icons.delete_outline_rounded,
                      color: scheme.error,
                    ),
                    onPressed: onDelete,
                    child: Text(
                      'Delete',
                      style: TextStyle(color: scheme.error),
                    ),
                  ),
                ],
                builder: (context, controller, _) => IconButton(
                  tooltip: 'Options',
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
