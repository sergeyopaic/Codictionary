import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_tokens.dart';
import '../dictionary_view_model.dart';

/// Opens the word details (AI explanation) as a dialog on wide screens and as
/// a bottom sheet on narrow ones.
Future<void> showWordDetails(
  BuildContext context, {
  required DictionaryViewModel vm,
  required String wordId,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  final size = MediaQuery.sizeOf(context);
  final details = WordDetails(
    vm: vm,
    wordId: wordId,
    onEdit: onEdit,
    onDelete: onDelete,
  );
  if (AppBreakpoints.isWide(context)) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 680,
            maxHeight: math.min(640, size.height * 0.88),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: details,
          ),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => SizedBox(
      height: size.height * 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          0,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: details,
      ),
    ),
  );
}

class WordDetails extends StatefulWidget {
  const WordDetails({
    super.key,
    required this.vm,
    required this.wordId,
    required this.onEdit,
    required this.onDelete,
  });

  final DictionaryViewModel vm;
  final String wordId;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  State<WordDetails> createState() => _WordDetailsState();
}

class _WordDetailsState extends State<WordDetails> {
  int _tab = 0;
  bool _loadingShort = false;
  bool _loadingLong = false;
  String? _errorShort;
  String? _errorLong;

  int get _index => widget.vm.words.indexWhere((w) => w.id == widget.wordId);

  Future<void> _regenerateShort() async {
    final i = _index;
    if (i < 0) return;
    setState(() {
      _loadingShort = true;
      _errorShort = null;
    });
    try {
      await widget.vm.regenerateDescription(i);
    } catch (e) {
      _errorShort = '$e';
    }
    if (mounted) setState(() => _loadingShort = false);
  }

  Future<void> _generateLong() async {
    final i = _index;
    if (i < 0) return;
    setState(() {
      _loadingLong = true;
      _errorLong = null;
    });
    try {
      await widget.vm.generateOrRegenerateLong(i);
    } catch (e) {
      _errorLong = '$e';
    }
    if (mounted) setState(() => _loadingLong = false);
  }

  void _close(VoidCallback then) {
    Navigator.of(context).pop();
    then();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.vm,
      builder: (context, _) {
        final i = _index;
        if (i < 0) return const SizedBox.shrink();
        final word = widget.vm.words[i];
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final isShort = _tab == 0;
        final text = isShort ? word.desc : word.descLong;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                        word.eng,
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SelectableText(
                        word.rus.isEmpty ? '—' : word.rus,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: scheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit word',
                  onPressed: () => _close(widget.onEdit),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: () => _close(widget.onDelete),
                  icon: Icon(Icons.delete_outline_rounded, color: scheme.error),
                ),
                if (AppBreakpoints.isWide(context))
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<int>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: 0,
                    icon: Icon(Icons.bolt_rounded),
                    label: Text('Quick'),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: Icon(Icons.article_outlined),
                    label: Text('In depth'),
                  ),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.medium,
                child: _ExplanationPanel(
                  key: ValueKey(_tab),
                  title: isShort ? 'Quick explanation' : 'In-depth explanation',
                  color: isShort
                      ? scheme.secondaryContainer
                      : scheme.tertiaryContainer,
                  text: text,
                  loading: isShort ? _loadingShort : _loadingLong,
                  error: isShort ? _errorShort : _errorLong,
                  emptyLabel: isShort
                      ? 'Generate explanation'
                      : 'Generate in-depth explanation',
                  onGenerate: isShort ? _regenerateShort : _generateLong,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExplanationPanel extends StatefulWidget {
  const _ExplanationPanel({
    super.key,
    required this.title,
    required this.color,
    required this.text,
    required this.loading,
    required this.error,
    required this.emptyLabel,
    required this.onGenerate,
  });

  final String title;
  final Color color;
  final String? text;
  final bool loading;
  final String? error;
  final String emptyLabel;
  final VoidCallback onGenerate;

  @override
  State<_ExplanationPanel> createState() => _ExplanationPanelState();
}

class _ExplanationPanelState extends State<_ExplanationPanel> {
  bool _copied = false;
  Timer? _copiedTimer;

  @override
  void dispose() {
    _copiedTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = widget.text?.trim();
    final hasText = text != null && text.isNotEmpty;

    Widget body;
    if (widget.loading) {
      body = const _ThinkingPlaceholder();
    } else if (widget.error != null) {
      body = _Message(
        icon: Icons.cloud_off_rounded,
        text: 'Cody couldn\'t reach the AI service.\n${widget.error}',
        action: FilledButton.tonalIcon(
          onPressed: widget.onGenerate,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      );
    } else if (!hasText) {
      body = _Message(
        icon: Icons.auto_awesome_rounded,
        text: 'No explanation yet.',
        action: FilledButton.tonalIcon(
          onPressed: widget.onGenerate,
          icon: const Icon(Icons.auto_awesome_rounded),
          label: Text(widget.emptyLabel),
        ),
      );
    } else {
      body = SingleChildScrollView(
        child: SelectableText(
          text,
          style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: widget.color.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: widget.color),
      ),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.surfaceContainerLowest,
                ),
                padding: const EdgeInsets.all(3),
                child: Image.asset(
                  CodyArt.reading,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cody explains', style: theme.textTheme.titleSmall),
                    Text(
                      widget.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasText && !widget.loading) ...[
                IconButton(
                  tooltip: _copied ? 'Copied' : 'Copy',
                  onPressed: () => _copy(text),
                  icon: Icon(
                    _copied ? Icons.check_rounded : Icons.copy_rounded,
                    size: 20,
                  ),
                ),
                IconButton(
                  tooltip: 'Regenerate',
                  onPressed: widget.onGenerate,
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: body,
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: theme.colorScheme.tertiary),
            const SizedBox(height: AppSpacing.md),
            Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Pulsing skeleton lines shown while the AI is generating text.
class _ThinkingPlaceholder extends StatefulWidget {
  const _ThinkingPlaceholder();

  @override
  State<_ThinkingPlaceholder> createState() => _ThinkingPlaceholderState();
}

class _ThinkingPlaceholderState extends State<_ThinkingPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    const widths = [1.0, 0.92, 0.97, 0.6];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cody is thinking…',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        FadeTransition(
          opacity: Tween(begin: 0.35, end: 0.9).animate(_pulse),
          child: Column(
            children: [
              for (final w in widths)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: w,
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(7),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
