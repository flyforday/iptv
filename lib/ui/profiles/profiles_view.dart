import 'package:flutter/material.dart';

import '../../utils/app_themes.dart';
import '../home/main_shell.dart';

class ProfileEntry {
  final String id;
  final String name;
  final String subtitle;

  const ProfileEntry({
    required this.id,
    required this.name,
    required this.subtitle,
  });
}

/// Écran « Qui regarde ? » : un profil par abonnement IPTV de la famille.
class ProfilesView extends StatefulWidget {
  final List<ProfileEntry> profiles;
  final void Function(ProfileEntry profile) onOpen;
  final VoidCallback onAdd;
  final void Function(ProfileEntry profile) onDelete;

  const ProfilesView({
    super.key,
    required this.profiles,
    required this.onOpen,
    required this.onAdd,
    required this.onDelete,
  });

  static const avatarColors = [
    AppColors.pink,
    Color(0xFF7B2FF7),
    Color(0xFF00A6D6),
    Color(0xFFF77F00),
    Color(0xFF2EC4B6),
    Color(0xFFE63946),
  ];

  /// Couleur stable par profil (même couleur à chaque lancement).
  static Color colorFor(String id) {
    var h = 0x811c9dc5;
    for (final c in id.codeUnits) {
      h = ((h ^ c) * 0x01000193) & 0x7fffffff;
    }
    return avatarColors[h % avatarColors.length];
  }

  @override
  State<ProfilesView> createState() => _ProfilesViewState();
}

class _ProfilesViewState extends State<ProfilesView> {
  bool _editing = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final tile = width >= 700 ? 150.0 : 112.0;
    final empty = widget.profiles.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: [
                  const BrandMark(),
                  const Spacer(),
                  if (!empty)
                    TextButton(
                      onPressed: () => setState(() => _editing = !_editing),
                      child: Text(_editing ? 'Terminé' : 'Modifier'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        empty
                            ? 'Bienvenue !'
                            : (_editing ? 'Gérer les profils' : 'Qui regarde ?'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (empty) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Ajoute ton abonnement IPTV pour retrouver tes '
                          'films, séries et chaînes.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Wrap(
                        spacing: 22,
                        runSpacing: 22,
                        alignment: WrapAlignment.center,
                        children: [
                          for (final p in widget.profiles)
                            _ProfileTile(
                              size: tile,
                              profile: p,
                              editing: _editing,
                              onTap: () => _editing
                                  ? widget.onDelete(p)
                                  : widget.onOpen(p),
                            ),
                          if (!_editing)
                            _AddTile(size: tile, onTap: widget.onAdd),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final double size;
  final ProfileEntry profile;
  final bool editing;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.size,
    required this.profile,
    required this.editing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = profile.name.trim();
    final color = ProfilesView.colorFor(profile.id);
    return SizedBox(
      width: size,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Stack(
              children: [
                Container(
                  width: size,
                  height: size,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color, Color.lerp(color, Colors.black, 0.45)!],
                    ),
                  ),
                  child: Text(
                    name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: size * 0.42,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (editing)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              profile.subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  final double size;
  final VoidCallback onTap;

  const _AddTile({required this.size, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.add_rounded,
                size: size * 0.4,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ajouter',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'un abonnement',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
