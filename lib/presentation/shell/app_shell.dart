import 'package:flutter/material.dart';

import '../backup/backup_view.dart';
import '../dictionary/dictionary_view.dart';
import '../theme/app_tokens.dart';
import '../theme/theme_controller.dart';
import '../vocabs/vocabs_view.dart';
import '../widgets/brand_mark.dart';
import '../l10n/app_strings.dart';

class _Destination {
  const _Destination(this.label, this.icon, this.selectedIcon);
  final String Function(AppStrings s) label;
  final IconData icon;
  final IconData selectedIcon;
}

String _dictionaryLabel(AppStrings s) => s.navDictionary;
String _vocabulariesLabel(AppStrings s) => s.navVocabularies;
String _backupLabel(AppStrings s) => s.navBackup;

const _destinations = [
  _Destination(
    _dictionaryLabel,
    Icons.menu_book_outlined,
    Icons.menu_book_rounded,
  ),
  _Destination(
    _vocabulariesLabel,
    Icons.collections_bookmark_outlined,
    Icons.collections_bookmark_rounded,
  ),
  _Destination(
    _backupLabel,
    Icons.settings_backup_restore_outlined,
    Icons.settings_backup_restore_rounded,
  ),
];

/// Adaptive app frame: a sidebar on wide screens, a bottom navigation bar on
/// narrow ones. Pages are kept alive in an [IndexedStack].
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  /// Bumped after a restore so pages that keep state reload their data.
  int _dataGeneration = 0;

  @override
  Widget build(BuildContext context) {
    final wide = AppBreakpoints.isWide(context);
    final pages = IndexedStack(
      index: _index,
      children: [
        DictionaryView(dataGeneration: _dataGeneration),
        VocabsView(isActive: _index == 1),
        BackupView(
          isActive: _index == 2,
          onRestored: () => setState(() => _dataGeneration++),
        ),
      ],
    );

    if (!wide) {
      return Scaffold(
        body: pages,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (final d in _destinations)
              NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label(context.s),
              ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          _Sidebar(
            index: _index,
            onSelected: (i) => setState(() => _index = i),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: pages),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.index, required this.onSelected});

  final int index;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: 264,
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        right: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xl,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          // Scrolls only when it does not fit (short window, large text);
          // otherwise the tip and theme selector sit at the bottom.
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                      child: BrandMark(size: 40),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: Text(
                        context.s.library,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    for (var i = 0; i < _destinations.length; i++)
                      _NavItem(
                        destination: _destinations[i],
                        selected: i == index,
                        onTap: () => onSelected(i),
                      ),
                    const Spacer(),
                    const SizedBox(height: AppSpacing.lg),
                    const _TipCard(),
                    const SizedBox(height: AppSpacing.md),
                    const _ThemeSelector(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _Destination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Icon(
                  selected ? destination.selectedIcon : destination.icon,
                  color: fg,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    destination.label(context.s),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  const _TipCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 18,
                color: scheme.onSecondaryContainer,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                context.s.tipTitle,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.s.tipBody(context.s.shortcut('N')),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector();

  @override
  Widget build(BuildContext context) {
    final controller = ThemeScope.of(context);
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: controller,
      builder: (context, mode, _) => SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        style: const ButtonStyle(visualDensity: VisualDensity.compact),
        segments: [
          ButtonSegment(
            value: ThemeMode.light,
            icon: Icon(Icons.light_mode_rounded, size: 18),
            tooltip: context.s.themeLight,
          ),
          ButtonSegment(
            value: ThemeMode.system,
            icon: Icon(Icons.brightness_auto_rounded, size: 18),
            tooltip: context.s.themeSystem,
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: Icon(Icons.dark_mode_rounded, size: 18),
            tooltip: context.s.themeDark,
          ),
        ],
        selected: {mode},
        onSelectionChanged: (s) => controller.value = s.first,
      ),
    );
  }
}
