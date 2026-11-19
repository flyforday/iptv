import 'package:flutter/material.dart';

import '../../utils/app_themes.dart';

class ShellTab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final WidgetBuilder builder;

  /// Si vrai, la barre du haut est transparente et posée sur le contenu
  /// (accueil avec grande affiche).
  final bool overlayTopBar;

  const ShellTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.builder,
    this.overlayTopBar = false,
  });
}

/// Squelette de l'app : barre du haut (marque, recherche, profil) et
/// navigation par onglets en bas (téléphone) ou à gauche (grande tablette).
class MainShell extends StatefulWidget {
  final List<ShellTab> tabs;
  final VoidCallback onSearch;
  final VoidCallback onProfile;
  final String profileInitial;
  final Color profileColor;
  final int initialIndex;

  const MainShell({
    super.key,
    required this.tabs,
    required this.onSearch,
    required this.onProfile,
    this.profileInitial = '',
    this.profileColor = AppColors.pink,
    this.initialIndex = 0,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _index = widget.initialIndex;
  final Set<int> _built = {};

  @override
  Widget build(BuildContext context) {
    _built.add(_index);
    final wide = MediaQuery.sizeOf(context).width >= 900;

    // Les onglets déjà ouverts restent en mémoire (position de défilement
    // conservée), les autres ne sont construits qu'au premier passage.
    final pages = IndexedStack(
      index: _index,
      children: [
        for (var i = 0; i < widget.tabs.length; i++)
          _built.contains(i)
              ? _TabPage(
                  key: ValueKey('tab_$i'),
                  tab: widget.tabs[i],
                  topBar: _TopBar(
                    title: i == 0 ? null : widget.tabs[i].label,
                    overlay: widget.tabs[i].overlayTopBar,
                    onSearch: widget.onSearch,
                    onProfile: widget.onProfile,
                    profileInitial: widget.profileInitial,
                    profileColor: widget.profileColor,
                  ),
                )
              : const SizedBox.shrink(),
      ],
    );

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            SafeArea(
              right: false,
              child: NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (i) => setState(() => _index = i),
                labelType: NavigationRailLabelType.all,
                groupAlignment: -0.85,
                destinations: [
                  for (final t in widget.tabs)
                    NavigationRailDestination(
                      icon: Icon(t.icon),
                      selectedIcon: Icon(t.selectedIcon),
                      label: Text(t.label),
                    ),
                ],
              ),
            ),
            Expanded(child: pages),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: false,
      body: pages,
      bottomNavigationBar: DecoratedBox(
        // Fine ligne de séparation au-dessus de la barre d'onglets.
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (final t in widget.tabs)
              NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.selectedIcon),
                label: t.label,
              ),
          ],
        ),
      ),
    );
  }
}

class _TabPage extends StatelessWidget {
  final ShellTab tab;
  final Widget topBar;

  const _TabPage({super.key, required this.tab, required this.topBar});

  @override
  Widget build(BuildContext context) {
    if (tab.overlayTopBar) {
      return Stack(
        children: [
          Positioned.fill(child: tab.builder(context)),
          Positioned(left: 0, right: 0, top: 0, child: topBar),
        ],
      );
    }
    return Column(
      children: [
        topBar,
        Expanded(child: tab.builder(context)),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final String? title;
  final bool overlay;
  final VoidCallback onSearch;
  final VoidCallback onProfile;
  final String profileInitial;
  final Color profileColor;

  const _TopBar({
    required this.title,
    required this.overlay,
    required this.onSearch,
    required this.onProfile,
    required this.profileInitial,
    required this.profileColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fg = overlay ? Colors.white : theme.colorScheme.onSurface;
    return Material(
      color: overlay ? Colors.transparent : theme.scaffoldBackgroundColor,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 8),
            child: Row(
              children: [
                if (title == null)
                  BrandMark(color: overlay ? Colors.white : null)
                else
                  Text(
                    title!,
                    style: theme.appBarTheme.titleTextStyle?.copyWith(
                      color: fg,
                    ),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Rechercher',
                  onPressed: onSearch,
                  icon: Icon(Icons.search_rounded, color: fg, size: 27),
                ),
                const SizedBox(width: 2),
                InkWell(
                  onTap: onProfile,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: profileColor,
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: profileInitial.isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              color: Colors.white,
                              size: 20,
                            )
                          : Text(
                              profileInitial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
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

/// Logo texte de l'app.
class BrandMark extends StatelessWidget {
  final bool compact;
  final Color? color;

  const BrandMark({super.key, this.compact = false, this.color});

  @override
  Widget build(BuildContext context) {
    final fg = color ?? Theme.of(context).colorScheme.onSurface;
    if (compact) {
      return Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.pink,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.pink,
            borderRadius: BorderRadius.circular(7),
          ),
          child: const Icon(
            Icons.play_arrow_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Famille',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 21,
            letterSpacing: -0.4,
            color: fg,
          ),
        ),
        Text(
          'TV',
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 21,
            letterSpacing: -0.4,
            color: AppColors.pink,
          ),
        ),
      ],
    );
  }
}
