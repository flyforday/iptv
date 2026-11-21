import 'package:flutter/material.dart';

import '../../screens/playlist_screen.dart';
import 'profiles_view.dart';

/// Menu du carré de profil (en haut à droite) : changer de profil ou
/// ouvrir les réglages.
Future<void> showProfileMenu(
  BuildContext context, {
  required String profileId,
  required String profileName,
  required VoidCallback onSettings,
}) {
  return showModalBottomSheet<void>(
    context: context,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: ProfilesView.colorFor(profileId),
                  foregroundColor: Colors.white,
                  child: Text(
                    profileName.trim().isEmpty
                        ? '?'
                        : profileName.trim().characters.first.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                title: Text(
                  profileName,
                  style: theme.textTheme.titleMedium,
                ),
                subtitle: const Text('Profil actuel'),
              ),
              const Divider(indent: 16, endIndent: 16),
              ListTile(
                leading: const Icon(Icons.switch_account_rounded),
                title: const Text('Changer de profil'),
                onTap: () {
                  Navigator.pop(sheet);
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const PlaylistScreen()),
                    (_) => false,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_rounded),
                title: const Text('Réglages et abonnement'),
                onTap: () {
                  Navigator.pop(sheet);
                  onSettings();
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
