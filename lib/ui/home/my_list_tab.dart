import 'package:flutter/material.dart';

import '../../controllers/watch_history_controller.dart';
import '../../models/content_type.dart';
import '../../models/favorite.dart';
import '../../models/watch_history.dart';
import '../../repositories/favorites_repository.dart';
import '../../services/app_state.dart';
import '../../services/watch_history_service.dart';
import '../../utils/navigate_by_content_type.dart';
import '../app_routes.dart';
import '../widgets/media_row.dart';
import '../widgets/poster_card.dart';
import 'home_feed.dart';

/// Contenu de l'onglet « Ma liste ».
class MyListData {
  final List<Favorite> favorites;
  final List<WatchHistory> history;

  const MyListData({this.favorites = const [], this.history = const []});
}

/// Onglet « Ma liste » : mes films et séries, mes chaînes, vus récemment.
class MyListView extends StatelessWidget {
  final MyListData data;
  final void Function(Favorite f) onOpenFavorite;
  final void Function(Favorite f) onRemoveFavorite;
  final void Function(WatchHistory h) onResume;
  final void Function(WatchHistory h) onRemoveHistory;
  final Future<void> Function()? onRefresh;

  const MyListView({
    super.key,
    required this.data,
    required this.onOpenFavorite,
    required this.onRemoveFavorite,
    required this.onResume,
    required this.onRemoveHistory,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sizes = MediaSizes.of(context);
    final titles = data.favorites
        .where((f) => f.contentType != ContentType.liveStream)
        .toList();
    final channels = data.favorites
        .where((f) => f.contentType == ContentType.liveStream)
        .toList();

    if (titles.isEmpty && channels.isEmpty && data.history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.bookmark_add_outlined,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                'Ta liste est vide',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Appuie sur « Ma liste » sur un film, une série ou une '
                'chaîne pour la retrouver ici.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    final posterWidth = sizes.widthFor(PosterShape.poster);
    final list = ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      children: [
        MediaRow<WatchHistory>(
          title: 'Vus récemment',
          items: data.history,
          shape: PosterShape.landscape,
          itemBuilder: (context, h, width) => PosterCard(
            title: h.title,
            imageUrl: h.imagePath,
            width: width,
            shape: PosterShape.landscape,
            progress: HomeFeedView.progressOf(h),
            subtitle: HomeFeedView.remainingLabel(h),
            onTap: () => onResume(h),
            onLongPress: () => onRemoveHistory(h),
          ),
        ),
        MediaRow<Favorite>(
          title: 'Mes chaînes',
          items: channels,
          shape: PosterShape.channel,
          itemBuilder: (context, f, width) => PosterCard(
            title: f.name,
            imageUrl: f.imagePath,
            width: width,
            shape: PosterShape.channel,
            onTap: () => onOpenFavorite(f),
            onLongPress: () => onRemoveFavorite(f),
          ),
        ),
        if (titles.isNotEmpty) ...[
          SectionHeader(title: 'Mes films et séries', gutter: sizes.gutter),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: sizes.gutter),
            child: Wrap(
              spacing: 10,
              runSpacing: 12,
              children: [
                for (final f in titles)
                  PosterCard(
                    title: f.name,
                    imageUrl: f.imagePath,
                    width: posterWidth,
                    onTap: () => onOpenFavorite(f),
                    onLongPress: () => onRemoveFavorite(f),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

/// Charge les données de [MyListView] pour le profil courant.
class MyListTab extends StatefulWidget {
  const MyListTab({super.key});

  @override
  State<MyListTab> createState() => _MyListTabState();
}

class _MyListTabState extends State<MyListTab> with RouteAware {
  final _favorites = FavoritesRepository();
  final _history = WatchHistoryService();
  MyListData? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() => _load();

  Future<void> _load() async {
    final playlist = AppState.currentPlaylist;
    if (playlist == null) return;
    final favorites = await _favorites.getAllFavorites();
    final history = await _history.getRecentlyWatched(playlist.id, limit: 20);
    if (!mounted) return;
    setState(() => _data = MyListData(favorites: favorites, history: history));
  }

  Future<bool> _confirm(String title, String action) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline_rounded),
              title: Text(action),
              onTap: () => Navigator.pop(sheet, true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    return ok == true;
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) return const Center(child: CircularProgressIndicator());
    return MyListView(
      data: data,
      onRefresh: _load,
      onResume: (h) => WatchHistoryController().playContent(context, h),
      onOpenFavorite: (f) async {
        final item = await _favorites.getContentItemFromFavorite(f);
        if (item != null && context.mounted) {
          navigateByContentType(context, item);
        }
      },
      onRemoveFavorite: (f) async {
        if (!await _confirm(f.name, 'Retirer de Ma liste')) return;
        await _favorites.removeFavorite(
          f.streamId,
          f.contentType,
          episodeId: f.episodeId,
        );
        _load();
      },
      onRemoveHistory: (h) async {
        if (!await _confirm(h.title, 'Retirer de l’historique')) return;
        await _history.deleteWatchHistory(h.playlistId, h.streamId);
        _load();
      },
    );
  }
}
