import 'package:flutter/material.dart';

import '../../controllers/watch_history_controller.dart';
import '../../models/category_view_model.dart';
import '../../models/content_type.dart';
import '../../models/favorite.dart';
import '../../models/playlist_content_model.dart';
import '../../models/watch_history.dart';
import '../../repositories/favorites_repository.dart';
import '../../screens/category_detail_screen.dart';
import '../../screens/movies/movie_screen.dart';
import '../../services/app_state.dart';
import '../../services/watch_history_service.dart';
import '../../utils/get_playlist_type.dart';
import '../../utils/navigate_by_content_type.dart';
import '../app_routes.dart';
import '../../utils/title_cleaner.dart';
import 'home_feed.dart';

/// Onglet Accueil pour un compte Xtream : charge les données puis affiche
/// [HomeFeedView]. Se met à jour au retour d'un autre écran (après avoir
/// regardé quelque chose, par exemple).
class XtreamHomeTab extends StatefulWidget {
  final List<CategoryViewModel> movieCategories;
  final List<CategoryViewModel> seriesCategories;

  const XtreamHomeTab({
    super.key,
    required this.movieCategories,
    required this.seriesCategories,
  });

  @override
  State<XtreamHomeTab> createState() => _XtreamHomeTabState();
}

class _XtreamHomeTabState extends State<XtreamHomeTab> with RouteAware {
  final _favorites = FavoritesRepository();
  final _history = WatchHistoryService();
  HomeFeedData? _data;
  bool _heroInList = false;
  ContentItem? _hero;

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
  void didUpdateWidget(covariant XtreamHomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.movieCategories.length != widget.movieCategories.length ||
        oldWidget.seriesCategories.length != widget.seriesCategories.length) {
      _load();
    }
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
    // Les comptes M3U n'ont pas de notes : pas de rangées « mieux notés ».
    final repo = isXtreamCode ? AppState.xtreamCodeRepository : null;

    final results = await Future.wait<List<dynamic>>([
      _history.getContinueWatching(playlist.id),
      _favorites.getAllFavorites(),
      repo?.getTopRatedMovies() ?? Future.value(const []),
      repo?.getTopRatedSeries() ?? Future.value(const []),
    ]);

    final continueWatching = (results[0] as List<WatchHistory>)
        .where((h) {
          final p = HomeFeedView.progressOf(h);
          return p == null || p < 0.95;
        })
        .take(15)
        .toList();

    final topMovies = groupVersions(
      results[2] as List,
      (m) => m.name as String,
    )
        .map(
          (m) => ContentItem(
            m.streamId,
            m.name,
            m.streamIcon,
            ContentType.vod,
            containerExtension: m.containerExtension,
            vodStream: m,
          ),
        )
        .toList();
    final topSeries = groupVersions(
      results[3] as List,
      (s) => s.name as String,
      identityOf: (s) => yearOf(s.releaseDate as String?),
    )
        .map(
          (s) => ContentItem(
            s.seriesId,
            s.name,
            s.cover ?? '',
            ContentType.series,
            seriesStream: s,
          ),
        )
        .toList();

    // Affiche à la une : change chaque jour, stable dans la journée.
    _hero ??= _pickHero(topMovies, topSeries);
    final hero = _hero;
    final inList = hero == null
        ? false
        : await _favorites.isFavorite(hero.id, hero.contentType);

    if (!mounted) return;
    setState(() {
      _heroInList = inList;
      _data = HomeFeedData(
        hero: hero,
        continueWatching: continueWatching,
        favorites: groupVersions(
          results[1] as List<Favorite>,
          (f) => f.name,
          scopeOf: (f) => f.contentType.name,
        ),
        topMovies: topMovies,
        topSeries: topSeries,
        movieCategories: widget.movieCategories,
        seriesCategories: widget.seriesCategories,
      );
    });
  }

  ContentItem? _pickHero(List<ContentItem> movies, List<ContentItem> series) {
    final pool = [...movies.take(10), ...series.take(10)];
    if (pool.isEmpty) {
      for (final c in [...widget.movieCategories, ...widget.seriesCategories]) {
        pool.addAll(c.contentItems.where((i) => i.imagePath.isNotEmpty));
        if (pool.length > 10) break;
      }
    }
    if (pool.isEmpty) return null;
    final now = DateTime.now();
    final day = now.year * 400 + now.month * 31 + now.day;
    return pool[day % pool.length];
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return HomeFeedView(
      data: data,
      heroInList: _heroInList,
      topInset: MediaQuery.paddingOf(context).top + 56,
      onRefresh: _load,
      actions: HomeFeedActions(
        openItem: (item) => navigateByContentType(context, item),
        playItem: (item) => item.contentType == ContentType.vod
            ? Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MovieScreen(contentItem: item, autoPlay: true),
                ),
              )
            : navigateByContentType(context, item),
        resume: (h) => WatchHistoryController().playContent(context, h),
        removeFromHistory: _confirmRemove,
        openFavorite: (f) async {
          final item = await _favorites.getContentItemFromFavorite(f);
          if (item != null && context.mounted) {
            navigateByContentType(context, item);
          }
        },
        openCategory: (c) => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CategoryDetailScreen(category: c),
          ),
        ),
        toggleMyList: (item) async {
          final added = await _favorites.toggleFavorite(item);
          if (!mounted) return;
          setState(() => _heroInList = added);
          _load();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                added ? 'Ajouté à Ma liste' : 'Retiré de Ma liste',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmRemove(WatchHistory h) async {
    final remove = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                h.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline_rounded),
              title: const Text('Retirer de « Continuer à regarder »'),
              onTap: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (remove == true) {
      await _history.deleteWatchHistory(h.playlistId, h.streamId);
      _load();
    }
  }
}
