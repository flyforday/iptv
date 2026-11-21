import 'package:another_iptv_player/screens/m3u/m3u_items_screen.dart';
import 'package:another_iptv_player/screens/m3u/m3u_playlist_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:another_iptv_player/controllers/m3u_home_controller.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/repositories/m3u_repository.dart';
import 'package:another_iptv_player/screens/category_detail_screen.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';

import '../../services/app_state.dart';
import '../../ui/home/catalog_view.dart';
import '../../ui/home/main_shell.dart';
import '../../ui/home/my_list_tab.dart';
import '../../ui/home/xtream_home_tab.dart';
import '../../ui/profiles/profile_menu.dart';
import '../../ui/profiles/profiles_view.dart';
import '../../ui/widgets/poster_card.dart';

/// Accueil d'un profil M3U : même présentation que les profils Xtream.
class M3UHomeScreen extends StatefulWidget {
  final Playlist playlist;

  const M3UHomeScreen({super.key, required this.playlist});

  @override
  State<M3UHomeScreen> createState() => _M3UHomeScreenState();
}

class _M3UHomeScreenState extends State<M3UHomeScreen> {
  late M3UHomeController _controller;

  @override
  void initState() {
    super.initState();
    AppState.m3uRepository = M3uRepository();
    _controller = M3UHomeController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _openCategory(CategoryViewModel category) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryDetailScreen(category: category),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<M3UHomeController>(
        builder: (context, controller, _) {
          final name = widget.playlist.name.trim();
          return MainShell(
            profileInitial: name.isEmpty ? '' : name[0].toUpperCase(),
            profileColor: ProfilesView.colorFor(widget.playlist.id),
            onSearch: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => M3uItemsScreen(
                  m3uItems: controller.m3uItems ?? const [],
                ),
              ),
            ),
            onProfile: () => showProfileMenu(
              context,
              profileId: widget.playlist.id,
              profileName: widget.playlist.name,
              onSettings: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      M3uPlaylistSettingsScreen(playlist: widget.playlist),
                ),
              ),
            ),
            tabs: [
              ShellTab(
                label: 'Accueil',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                overlayTopBar: true,
                builder: (_) => XtreamHomeTab(
                  movieCategories: controller.vodCategories ?? const [],
                  seriesCategories: controller.seriesCategories ?? const [],
                ),
              ),
              ShellTab(
                label: 'Films',
                icon: Icons.movie_outlined,
                selectedIcon: Icons.movie_rounded,
                builder: (context) => CatalogView(
                  categories: controller.vodCategories ?? const [],
                  onOpen: (item) => navigateByContentType(context, item),
                  onSeeAll: _openCategory,
                ),
              ),
              ShellTab(
                label: 'Séries',
                icon: Icons.video_library_outlined,
                selectedIcon: Icons.video_library_rounded,
                builder: (context) => CatalogView(
                  categories: controller.seriesCategories ?? const [],
                  onOpen: (item) => navigateByContentType(context, item),
                  onSeeAll: _openCategory,
                ),
              ),
              ShellTab(
                label: 'TV',
                icon: Icons.live_tv_outlined,
                selectedIcon: Icons.live_tv_rounded,
                builder: (context) => CatalogView(
                  categories: controller.liveCategories ?? const [],
                  shape: PosterShape.channel,
                  onOpen: (item) => navigateByContentType(context, item),
                  onSeeAll: _openCategory,
                ),
              ),
              const ShellTab(
                label: 'Ma liste',
                icon: Icons.bookmark_border_rounded,
                selectedIcon: Icons.bookmark_rounded,
                builder: _myList,
              ),
            ],
          );
        },
      ),
    );
  }

  static Widget _myList(BuildContext context) => const MyListTab();
}
