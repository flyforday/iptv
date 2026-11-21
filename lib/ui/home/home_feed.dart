import 'package:flutter/material.dart';

import '../../models/category_view_model.dart';
import '../../models/content_type.dart';
import '../../models/favorite.dart';
import '../../models/playlist_content_model.dart';
import '../../models/watch_history.dart';
import '../widgets/hero_banner.dart';
import '../widgets/media_row.dart';
import '../widgets/poster_card.dart';
import '../../utils/title_cleaner.dart';

/// Tout ce que l'accueil affiche, déjà chargé.
class HomeFeedData {
  final ContentItem? hero;
  final List<WatchHistory> continueWatching;
  final List<Favorite> favorites;
  final List<ContentItem> topMovies;
  final List<ContentItem> topSeries;
  final List<CategoryViewModel> movieCategories;
  final List<CategoryViewModel> seriesCategories;

  const HomeFeedData({
    this.hero,
    this.continueWatching = const [],
    this.favorites = const [],
    this.topMovies = const [],
    this.topSeries = const [],
    this.movieCategories = const [],
    this.seriesCategories = const [],
  });
}

/// Actions possibles depuis l'accueil.
class HomeFeedActions {
  final void Function(ContentItem item) openItem;
  final void Function(ContentItem item) playItem;
  final void Function(WatchHistory history) resume;
  final void Function(WatchHistory history)? removeFromHistory;
  final void Function(Favorite favorite) openFavorite;
  final void Function(CategoryViewModel category) openCategory;
  final void Function(ContentItem item)? toggleMyList;

  const HomeFeedActions({
    required this.openItem,
    required this.playItem,
    required this.resume,
    required this.openFavorite,
    required this.openCategory,
    this.removeFromHistory,
    this.toggleMyList,
  });
}

/// Liste défilante de l'accueil : affiche à la une puis rangées.
class HomeFeedView extends StatelessWidget {
  final HomeFeedData data;
  final HomeFeedActions actions;
  final bool heroInList;
  final Future<void> Function()? onRefresh;

  /// Hauteur réservée en haut (barre transparente au-dessus de l'affiche).
  final double topInset;

  const HomeFeedView({
    super.key,
    required this.data,
    required this.actions,
    this.heroInList = false,
    this.onRefresh,
    this.topInset = 0,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    final hero = data.hero;

    if (hero != null) {
      rows.add(
        HeroBanner(
          title: hero.name,
          imageUrl: heroImage(hero),
          tagline: heroTagline(hero),
          inList: heroInList,
          onPlay: () => actions.playItem(hero),
          onInfo: () => actions.openItem(hero),
          onToggleList: actions.toggleMyList == null
              ? null
              : () => actions.toggleMyList!(hero),
        ),
      );
      rows.add(const SizedBox(height: 8));
    } else {
      rows.add(SizedBox(height: topInset + 8));
    }

    rows.add(
      MediaRow<WatchHistory>(
        title: 'Continuer à regarder',
        items: data.continueWatching,
        shape: PosterShape.landscape,
        itemBuilder: (context, h, width) => PosterCard(
          title: h.title,
          imageUrl: h.imagePath,
          width: width,
          shape: PosterShape.landscape,
          progress: progressOf(h),
          subtitle: remainingLabel(h),
          onTap: () => actions.resume(h),
          onLongPress: actions.removeFromHistory == null
              ? null
              : () => actions.removeFromHistory!(h),
        ),
      ),
    );

    rows.add(
      MediaRow<Favorite>(
        title: 'Ma liste',
        items: data.favorites
            .where((f) => f.contentType != ContentType.liveStream)
            .toList(),
        itemBuilder: (context, f, width) => PosterCard(
          title: f.name,
          imageUrl: f.imagePath,
          width: width,
          onTap: () => actions.openFavorite(f),
        ),
      ),
    );

    rows.add(
      MediaRow<Favorite>(
        title: 'Mes chaînes',
        shape: PosterShape.channel,
        items: data.favorites
            .where((f) => f.contentType == ContentType.liveStream)
            .toList(),
        itemBuilder: (context, f, width) => PosterCard(
          title: f.name,
          imageUrl: f.imagePath,
          width: width,
          shape: PosterShape.channel,
          onTap: () => actions.openFavorite(f),
        ),
      ),
    );

    rows.add(_itemsRow('Films les mieux notés', data.topMovies));

    // Alterne catégories de films et de séries pour varier l'accueil.
    final movieCats = data.movieCategories.take(8).toList();
    final seriesCats = data.seriesCategories.take(8).toList();
    var seriesTopAdded = false;
    for (var i = 0; i < movieCats.length || i < seriesCats.length; i++) {
      if (i < movieCats.length) rows.add(_categoryRow(movieCats[i]));
      if (i == 1 && !seriesTopAdded) {
        rows.add(_itemsRow('Séries les mieux notées', data.topSeries));
        seriesTopAdded = true;
      }
      if (i < seriesCats.length) rows.add(_categoryRow(seriesCats[i]));
    }
    if (!seriesTopAdded) {
      rows.add(_itemsRow('Séries les mieux notées', data.topSeries));
    }
    rows.add(const SizedBox(height: 24));

    final list = ListView(padding: EdgeInsets.zero, children: rows);
    if (onRefresh == null) return list;
    return RefreshIndicator(
      onRefresh: onRefresh!,
      edgeOffset: topInset,
      child: list,
    );
  }

  Widget _itemsRow(String title, List<ContentItem> items) {
    return MediaRow<ContentItem>(
      title: title,
      items: items,
      itemBuilder: (context, item, width) => PosterCard(
        title: item.name,
        imageUrl: item.imagePath,
        width: width,
        onTap: () => actions.openItem(item),
      ),
    );
  }

  Widget _categoryRow(CategoryViewModel category) {
    return MediaRow<ContentItem>(
      title: cleanTitle(category.category.categoryName),
      items: groupVersions(
        category.contentItems,
        (i) => i.name,
        identityOf: (i) => yearOf(i.seriesStream?.releaseDate),
      ),
      onSeeAll: () => actions.openCategory(category),
      itemBuilder: (context, item, width) => PosterCard(
        title: item.name,
        imageUrl: item.imagePath,
        width: width,
        onTap: () => actions.openItem(item),
      ),
    );
  }

  static String? heroImage(ContentItem item) {
    final backdrops = item.seriesStream?.backdropPath;
    if (backdrops != null && backdrops.isNotEmpty && backdrops.first.isNotEmpty) {
      return backdrops.first;
    }
    return item.imagePath;
  }

  static String heroTagline(ContentItem item) {
    final parts = <String>[];
    final genre = item.vodStream?.genre ?? item.seriesStream?.genre;
    if (genre != null && genre.trim().isNotEmpty) {
      parts.addAll(
        genre
            .split(RegExp(r'[,/|]'))
            .map((g) => g.trim())
            .where((g) => g.isNotEmpty)
            .take(3),
      );
    }
    final date = item.seriesStream?.releaseDate;
    if (date != null && date.length >= 4) parts.add(date.substring(0, 4));
    if (parts.isEmpty) {
      parts.add(item.contentType == ContentType.series ? 'Série' : 'Film');
    }
    return parts.join('  •  ');
  }

  static double? progressOf(WatchHistory h) {
    final w = h.watchDuration?.inSeconds;
    final t = h.totalDuration?.inSeconds;
    if (w == null || t == null || t <= 0) return null;
    return w / t;
  }

  static String? remainingLabel(WatchHistory h) {
    final w = h.watchDuration;
    final t = h.totalDuration;
    if (h.contentType == ContentType.liveStream) return 'En direct';
    if (w == null || t == null || t.inSeconds <= 0) return null;
    final left = t - w;
    if (left.inMinutes < 1) return 'Presque fini';
    if (left.inHours >= 1) {
      return 'Reste ${left.inHours} h ${(left.inMinutes % 60).toString().padLeft(2, '0')}';
    }
    return 'Reste ${left.inMinutes} min';
  }
}
