import 'package:flutter/material.dart';
import 'create_vocabulary_dialog.dart';
import '../../services/storage_service.dart';

class VocabsView extends StatefulWidget {
  const VocabsView({super.key});

  @override
  State<VocabsView> createState() => _VocabsViewState();
}

class _VocabsViewState extends State<VocabsView> {
  final List<_Vocab> _vocabs = [];
  late final StorageService _storage;

  @override
  void initState() {
    super.initState();
    _storage = createStorageService();
    _load();
  }

  Future<void> _load() async {
    final raw = await _storage.loadVocabularies();
    if (!mounted) return;
    setState(() {
      _vocabs
        ..clear()
        ..addAll(raw.map(_Vocab.fromMap));
    });
  }

  Future<void> _create() async {
    final res = await showCreateVocabularyDialog(context);
    if (res == null) return;
    final created = _Vocab(
      name: res['name'] ?? 'Untitled',
      description: res['description'] ?? '',
      iconPath: res['icon'] ?? 'assets/media/icons/new_dictionary/1.png',
    );
    setState(() {
      _vocabs.add(created);
    });
    await _storage.saveVocabularies(_vocabs.map((e) => e.toMap()).toList());
  }

  Future<void> _renameAt(int index) async {
    final v = _vocabs[index];
    final nameController = TextEditingController(text: v.name);
    final descController = TextEditingController(text: v.description);
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        title: const Text('Rename Dictionary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: 'Description (optional)'),
              minLines: 1,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _vocabs[index] = _Vocab(
        name: nameController.text.trim().isEmpty ? v.name : nameController.text.trim(),
        description: descController.text.trim(),
        iconPath: v.iconPath,
      );
    });
    await _storage.saveVocabularies(_vocabs.map((e) => e.toMap()).toList());
  }

  Future<void> _deleteAt(int index) async {
    final v = _vocabs[index];
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AlertDialog(
        title: const Text('Delete Dictionary'),
        content: Text('"${v.name}" will be removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => Navigator.of(context).pop(true),
            label: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _vocabs.removeAt(index);
    });
    await _storage.saveVocabularies(_vocabs.map((e) => e.toMap()).toList());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${v.name}" deleted.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vocabularies'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Add vocabulary',
            icon: const Icon(Icons.library_add),
            onPressed: _create,
          ),
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
                  const ListTile(
                    leading: Icon(Icons.library_books),
                    title: Text('My Vocabularies'),
                    enabled: false,
                  ),
                  ListTile(
                    leading: const Icon(Icons.menu_book_outlined),
                    title: const Text('Dictionary'),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).maybePop();
                    },
                  ),
                  const Divider(),
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _vocabs.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No vocabularies yet.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _create,
                      icon: const Icon(Icons.add),
                      label: const Text('Add one'),
                    ),
                  ],
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final columns = width.isFinite
                      ? (width / 260).floor().clamp(1, 5)
                      : 2;
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1.8,
                    ),
                    itemCount: _vocabs.length,
                    itemBuilder: (context, i) {
                      final v = _vocabs[i];
                      return _VocabCard(
                        vocab: v,
                        onRename: () => _renameAt(i),
                        onDelete: () => _deleteAt(i),
                      );
                    },
                  );
                },
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.library_add),
        label: const Text('Add vocabulary'),
        onPressed: _create,
      ),
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
    name: m['name'] ?? 'Untitled',
    description: m['description'] ?? '',
    iconPath: m['icon'] ?? 'assets/media/icons/new_dictionary/1.png',
  );
}

class _VocabCard extends StatelessWidget {
  final _Vocab vocab;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const _VocabCard({required this.vocab, required this.onRename, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              padding: const EdgeInsets.all(8),
              child: Image.asset(
                vocab.iconPath.replaceFirst(
                  '/new_dictionary/',
                  '/new_dictionary/2.0x/',
                ),
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => const Icon(Icons.menu_book),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    vocab.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vocab.description.isEmpty
                        ? 'No description'
                        : vocab.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Options',
              onSelected: (value) {
                if (value == 'rename') onRename();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'rename',
                  child: ListTile(
                    leading: Icon(Icons.edit),
                    title: Text('Rename'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete),
                    title: Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
