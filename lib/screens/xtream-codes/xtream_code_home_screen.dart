import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:another_iptv_player/controllers/xtream_code_home_controller.dart';
import 'package:another_iptv_player/models/api_configuration_model.dart';
import 'package:another_iptv_player/models/category_view_model.dart';
import 'package:another_iptv_player/models/playlist_model.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/screens/category_detail_screen.dart';
import 'package:another_iptv_player/screens/xtream-codes/xtream_code_playlist_settings_screen.dart';
import 'package:another_iptv_player/screens/watch_history_screen.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/utils/navigate_by_content_type.dart';

import '../../ui/home/catalog_view.dart';
import '../../ui/home/main_shell.dart';
import '../../ui/home/xtream_home_tab.dart';
import '../../ui/search/unified_search_screen.dart';
import '../../ui/widgets/poster_card.dart';

class XtreamCodeHomeScreen extends StatefulWidget {
  final Playlist playlist;

  const XtreamCodeHomeScreen({super.key, required this.playlist});

  @override
  State<XtreamCodeHomeScreen> createState() => _XtreamCodeHomeScreenState();
}

class _XtreamCodeHomeScreenState extends State<XtreamCodeHomeScreen> {
  late XtreamCodeHomeController _controller;

  @override
  void initState() {
    super.initState();
    final repository = IptvRepository(
      ApiConfig(
        baseUrl: widget.playlist.url!,
        username: widget.playlist.username!,
        password: widget.playlist.password!,
      ),
      widget.playlist.id,
    );
    AppState.xtreamCodeRepository = repository;
    _controller = XtreamCodeHomeController(false);
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
      child: Consumer<XtreamCodeHomeController>(
        builder: (context, controller, _) {
          final name = widget.playlist.name.trim();
          return MainShell(
            profileInitial: name.isEmpty ? '' : name[0].toUpperCase(),
            onSearch: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const UnifiedSearchScreen()),
            ),
            onProfile: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    XtreamCodePlaylistSettingsScreen(playlist: widget.playlist),
              ),
            ),
            tabs: [
              ShellTab(
                label: 'Accueil',
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                overlayTopBar: true,
                builder: (_) => XtreamHomeTab(
                  movieCategories: controller.movieCategories,
                  seriesCategories: controller.seriesCategories,
                ),
              ),
              ShellTab(
                label: 'Films',
                icon: Icons.movie_outlined,
                selectedIcon: Icons.movie_rounded,
                builder: (context) => CatalogView(
                  categories: controller.movieCategories,
                  onOpen: (item) => navigateByContentType(context, item),
                  onSeeAll: _openCategory,
                ),
              ),
              ShellTab(
                label: 'Séries',
                icon: Icons.video_library_outlined,
                selectedIcon: Icons.video_library_rounded,
                builder: (context) => CatalogView(
                  categories: controller.seriesCategories,
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
              ShellTab(
                label: 'Ma liste',
                icon: Icons.bookmark_border_rounded,
                selectedIcon: Icons.bookmark_rounded,
                builder: (_) =>
                    WatchHistoryScreen(playlistId: widget.playlist.id),
              ),
            ],
          );
        },
      ),
    );
  }
}
