import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/playlist_controller.dart';
import '../../models/playlist_model.dart';
import '../../widgets/playlist_states.dart';
import '../ui/profiles/add_profile_screen.dart';
import '../ui/profiles/profiles_view.dart';

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({super.key});

  @override
  PlaylistScreenState createState() => PlaylistScreenState();
}

class PlaylistScreenState extends State<PlaylistScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PlaylistController(),
      child: _PlaylistScreenBody(),
    );
  }
}

class _PlaylistScreenBody extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializePlaylistsIfNeeded(context);
    });

    return Consumer<PlaylistController>(
      builder: (context, controller, child) {
        if (controller.isLoading) {
          return const Scaffold(body: PlaylistLoadingState());
        }
        if (controller.error != null) {
          return Scaffold(
            body: PlaylistErrorState(
              error: controller.error!,
              onRetry: () => controller.loadPlaylists(context),
            ),
          );
        }
        final byId = {for (final p in controller.playlists) p.id: p};
        return ProfilesView(
          profiles: [
            for (final p in controller.playlists)
              ProfileEntry(
                id: p.id,
                name: p.name,
                subtitle: p.type == PlaylistType.xtream ? 'Codes Xtream' : 'Lien M3U',
              ),
          ],
          onOpen: (entry) => controller.openPlaylist(context, byId[entry.id]!),
          onAdd: () => _navigateToCreatePlaylist(context),
          onDelete: (entry) =>
              _showDeleteDialog(context, controller, byId[entry.id]!),
        );
      },
    );
  }

  void _initializePlaylistsIfNeeded(BuildContext context) {
    final controller = context.read<PlaylistController>();
    if (!controller.isLoading &&
        controller.playlists.isEmpty &&
        controller.error == null) {
      controller.loadPlaylists(context);
    }
  }

  void _navigateToCreatePlaylist(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddProfileScreen()),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    PlaylistController controller,
    Playlist playlist,
  ) {
    showDialog(
      context: context,
      builder: (context) => _DeletePlaylistDialog(
        playlist: playlist,
        onDelete: () async {
          final success = await controller.deletePlaylist(playlist.id);
          if (success && context.mounted) {
            _showSuccessSnackBar(context, playlist.name);
          }
        },
      ),
    );
  }

  void _showSuccessSnackBar(BuildContext context, String playlistName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.loc.playlist_deleted(playlistName)),
      ),
    );
  }
}

class _DeletePlaylistDialog extends StatelessWidget {
  final Playlist playlist;
  final VoidCallback onDelete;

  const _DeletePlaylistDialog({required this.playlist, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.loc.playlist_delete_confirmation_title),
      content: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              text: context.loc.playlist_delete_confirmation_message(
                playlist.name,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.loc.cancel),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onDelete();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Text(context.loc.delete),
        ),
      ],
    );
  }
}
