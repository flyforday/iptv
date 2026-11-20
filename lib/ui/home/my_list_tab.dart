import 'package:flutter/material.dart';

import '../../controllers/watch_history_controller.dart';
import '../../models/content_type.dart';
import '../../models/favorite.dart';
import '../../models/watch_history.dart';
import '../../repositories/favorites_repository.dart';
import '../../services/app_state.dart';
import '../../services/custom_lists_service.dart';
import '../../services/watch_history_service.dart';
import '../../utils/navigate_by_content_type.dart';
import '../../utils/title_cleaner.dart';
import '../app_routes.dart';
import '../lists/list_picker_sheet.dart';
import '../widgets/media_row.dart';
import '../widgets/poster_card.dart';
import 'home_feed.dart';

/// Contenu de l'onglet « Ma liste ».
class MyListData {
  final List<Favorite> favorites;
  final List<WatchHistory> history;
  final List<CustomList> customLists;

  const MyListData({
    this.favorites = const [],
    this.history = const [],
    this.customLists = const [],
  });
}

/// Onglet « Ma liste » : vus récemment, Ma liste, les listes perso
/// (« Films de Noël »…), mes chaînes, et un bouton pour créer une liste.
class MyListView extends StatelessWidget {
  final MyListData data;
  final void Function(Favorite f) onOpenFavorite;
  final void Function(Favorite f) onRemoveFavorite;
  final void Function(WatchHistory h) onResume;
  final void Function(WatchHistory h) onRemoveHistory;
  final void Function(CustomList list, Favorite f) onRemoveFromList;
  final VoidCallback onCreateList;
  final void Function(CustomList list) onListMenu;
  final Future<void> Function()? onRefresh;

  const MyListView({
    super.key,
    required this.data,
    required this.onOpenFavorite,
    required this.onRemoveFavorite,
    required this.onResume,
    required this.onRemoveHistory,
    required this.onRemoveFromList,
    required this.onCreateList,
    required this.onListMenu,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sizes = MediaSizes.of(context);
    final titles = groupVersions(
      data.favorites.where((f) => f.contentType != ContentType.liveStream),
      (f) => f.name,
      scopeOf: (f) => f.contentType.name,
    );
    final channels = data.favorites
        .where((f) => f.contentType == ContentType.liveStream)
        .toList();

    final createButton = Padding(
      padding: EdgeInsets.symmetric(horizontal: sizes.gutter),
      child: Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: onCreateList,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Créer une liste'),
        ),
      ),
    );

    if (titles.isEmpty &&
        channels.isEmpty &&
        data.history.isEmpty &&
        data.customLists.isEmpty) {
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
                'chaîne pour la retrouver ici. Tu peux aussi créer tes '
                'propres listes, par exemple « Films de Noël ».',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onCreateList,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Créer une liste'),
              ),
            ],
          ),
        ),
      );
    }

    Widget poster(Favorite f, double width, VoidCallback onLongPress) =>
        PosterCard(
          title: f.name,
          imageUrl: f.imagePath,
          width: width,
          onTap: () => onOpenFavorite(f),
          onLongPress: onLongPress,
        );

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
          title: 'Ma liste',
          items: titles,
          itemBuilder: (context, f, width) =>
              poster(f, width, () => onRemoveFavorite(f)),
        ),
        for (final l in data.customLists)
          _CustomListRow(
            list: l,
            onMenu: () => onListMenu(l),
            itemBuilder: (context, f, width) =>
                poster(f, width, () => onRemoveFromList(l, f)),
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
        createButton,
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

/// Rangée d'une liste perso, avec un bouton « … » (renommer, supprimer).
class _CustomListRow extends StatelessWidget {
  final CustomList list;
  final VoidCallback onMenu;
  final Widget Function(BuildContext context, Favorite f, double width)
  itemBuilder;

  const _CustomListRow({
    required this.list,
    required this.onMenu,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sizes = MediaSizes.of(context);
    final width = sizes.widthFor(PosterShape.poster);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: sizes.gutter, right: 4),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    list.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Gérer la liste',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: onMenu,
                ),
              ],
            ),
          ),
          if (list.items.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(sizes.gutter, 0, sizes.gutter, 0),
              child: Text(
                'Liste vide. Sur un film ou une série, appuie sur '
                '« Ma liste » puis choisis « ${list.name} ».',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            )
          else
            SizedBox(
              height: PosterShape.poster.heightFor(width),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: sizes.gutter),
                itemCount: list.items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) =>
                    itemBuilder(context, list.items[i], width),
              ),
            ),
        ],
      ),
    );
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
  final _lists = CustomListsService();
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
    final lists = await _lists.load(playlist.id);
    if (!mounted) return;
    setState(
      () => _data = MyListData(
        favorites: favorites,
        history: history,
        customLists: lists,
      ),
    );
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
        if (!await _confirm(cleanTitle(f.name), 'Retirer de Ma liste')) return;
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
      onRemoveFromList: (l, f) async {
        if (!await _confirm(cleanTitle(f.name), 'Retirer de « ${l.name} »')) {
          return;
        }
        await _lists.remove(f.playlistId, l.id, f.streamId);
        _load();
      },
      onCreateList: () async {
        final playlist = AppState.currentPlaylist;
        final name = await askListName(context);
        if (name == null || playlist == null) return;
        await _lists.create(playlist.id, name);
        _load();
      },
      onListMenu: _listMenu,
    );
  }

  Future<void> _listMenu(CustomList list) async {
    final playlist = AppState.currentPlaylist;
    if (playlist == null) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                list.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(sheet).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Renommer'),
              onTap: () => Navigator.pop(sheet, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Supprimer la liste'),
              onTap: () => Navigator.pop(sheet, 'delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'rename') {
      final name = await askListName(
        context,
        initial: list.name,
        title: 'Renommer la liste',
        action: 'Enregistrer',
      );
      if (name == null) return;
      await _lists.rename(playlist.id, list.id, name);
    } else if (action == 'delete') {
      if (!await _confirm(list.name, 'Supprimer (les films restent dispo)')) {
        return;
      }
      await _lists.delete(playlist.id, list.id);
    } else {
      return;
    }
    _load();
  }
}
