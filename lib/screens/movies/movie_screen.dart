import 'dart:ui';

import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:another_iptv_player/models/api_configuration_model.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/watch_history.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/services/watch_history_service.dart';
import 'package:another_iptv_player/utils/get_playlist_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../widgets/player_widget.dart';
import '../../repositories/favorites_repository.dart';
import '../../ui/detail/detail_view.dart';
import '../../ui/widgets/media_row.dart';
import '../../services/custom_lists_service.dart';
import '../../ui/lists/list_picker_sheet.dart';
import '../../ui/widgets/poster_card.dart';
import '../../utils/title_cleaner.dart';

class MovieScreen extends StatefulWidget {
  final ContentItem contentItem;

  /// Lance la lecture directement (bouton Lecture de l'accueil).
  final bool autoPlay;

  const MovieScreen({
    super.key,
    required this.contentItem,
    this.autoPlay = false,
  });

  @override
  State<MovieScreen> createState() => _MovieScreenState();
}

class _MovieScreenState extends State<MovieScreen> {
  late final WatchHistoryService _watchHistoryService;
  late final IptvRepository? _repository;

  WatchHistory? _watchHistory;
  Map<String, dynamic>? _vodInfo;
  bool _isLoadingHistory = true;
  bool _isLoadingVodInfo = true;
  List<ContentItem> _categoryMovies = [];
  final _favorites = FavoritesRepository();
  bool _inList = false;
  List<ContentItem> _versions = [];

  @override
  void initState() {
    super.initState();
    _watchHistoryService = WatchHistoryService();

    if (isXtreamCode && AppState.currentPlaylist != null) {
      _repository = IptvRepository(
        ApiConfig(
          baseUrl: AppState.currentPlaylist!.url!,
          username: AppState.currentPlaylist!.username!,
          password: AppState.currentPlaylist!.password!,
        ),
        AppState.currentPlaylist!.id,
      );
    } else {
      _repository = null;
    }

    _loadWatchHistory();
    _loadVodInfo();
    _loadCategoryMovies();
    _loadFavorite();
    _loadVersions();
    if (widget.autoPlay) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openPlayer();
      });
    }
  }

  Future<void> _loadCategoryMovies() async {
    try {
      if (isXtreamCode && _repository != null) {
        final vod = widget.contentItem.vodStream;
        final categoryId = vod?.categoryId;

        if (categoryId != null) {
          final movies = await _repository!.getMovies(categoryId: categoryId);
          if (movies != null && mounted) {
            setState(() {
              _categoryMovies = movies
                  .map((x) => ContentItem(
                        x.streamId,
                        x.name,
                        x.streamIcon,
                        ContentType.vod,
                        vodStream: x,
                        containerExtension: x.containerExtension,
                      ))
                  .toList();
            });
          }
        }
      } else if (isM3u) {
        final m3uItem = widget.contentItem.m3uItem;
        final categoryId = m3uItem?.categoryId;

        if (categoryId != null) {
          final items = await AppState.m3uRepository!.getM3uItemsByCategoryId(
            categoryId: categoryId,
            contentType: ContentType.vod,
          );
          if (items != null && mounted) {
            setState(() {
              _categoryMovies = items
                  .map((x) => ContentItem(
                        x.id,
                        x.name ?? 'NO NAME',
                        x.tvgLogo ?? '',
                        ContentType.vod,
                        m3uItem: x,
                      ))
                  .toList();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading category movies: $e');
    }
  }

  Future<void> _loadWatchHistory() async {
    final playlist = AppState.currentPlaylist;
    if (playlist == null) {
      if (!mounted) return;
      setState(() {
        _watchHistory = null;
        _isLoadingHistory = false;
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingHistory = true;
      });
    }

    try {
      final streamId = isXtreamCode
          ? widget.contentItem.id
          : widget.contentItem.m3uItem?.id ?? widget.contentItem.id;

      final history =
          await _watchHistoryService.getWatchHistory(playlist.id, streamId);

      if (!mounted) return;
      setState(() {
        _watchHistory = history;
        _isLoadingHistory = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _watchHistory = null;
        _isLoadingHistory = false;
      });
    }
  }

  Future<void> _loadVodInfo() async {
    if (!isXtreamCode || _repository == null) {
      if (!mounted) return;
      setState(() {
        _vodInfo = null;
        _isLoadingVodInfo = false;
      });
      return;
    }

    try {
      final info = await _repository!.getVodInfo(widget.contentItem.id);

      if (!mounted) return;
      setState(() {
        _vodInfo = info;
        _isLoadingVodInfo = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _vodInfo = null;
        _isLoadingVodInfo = false;
      });
    }
  }

  double? get _progress {
    final history = _watchHistory;
    if (history?.watchDuration == null || history?.totalDuration == null) {
      return null;
    }

    final total = history!.totalDuration!.inMilliseconds;
    if (total <= 0) return null;

    final value = history.watchDuration!.inMilliseconds / total;
    if (value <= 0) return null;

    return (value.clamp(0.0, 1.0)) as double;
  }

  String? get _posterUrl {
    if (_vodInfo != null) {
      final cover = _vodInfo!['cover_big'] ?? _vodInfo!['cover'];
      if (cover is String && cover.isNotEmpty) return cover;
    }
    if (widget.contentItem.coverPath?.isNotEmpty == true) {
      return widget.contentItem.coverPath;
    }
    if (widget.contentItem.imagePath.isNotEmpty) {
      return widget.contentItem.imagePath;
    }
    return widget.contentItem.vodStream?.streamIcon;
  }

  String? get _backdropUrl {
    if (_vodInfo != null) {
      final backdrop = _vodInfo!['backdrop_path'];
      if (backdrop is List && backdrop.isNotEmpty) {
        return backdrop.first.toString();
      } else if (backdrop is String && backdrop.isNotEmpty) {
        return backdrop;
      }
    }
    return null;
  }

  String? get _plotSummary {
    if (_vodInfo != null) {
      final plot = _vodInfo!['plot'];
      if (plot is String && plot.isNotEmpty) {
        return plot;
      }
    }
    return widget.contentItem.description?.trim();
  }

  String? get _directorInfo {
    if (_vodInfo != null) {
      final director = _vodInfo!['director'];
      if (director is String && director.isNotEmpty) {
        return director;
      }
    }
    return null;
  }

  String? get _castInfo {
    if (_vodInfo != null) {
      final cast = _vodInfo!['cast'];
      if (cast is String && cast.isNotEmpty) {
        return cast;
      }
    }
    return null;
  }

  int? get _duration {
    if (_vodInfo != null) {
      final duration = _vodInfo!['duration'];
      if (duration is int) {
        return duration;
      }
    }
    return widget.contentItem.duration?.inSeconds;
  }

  String? get _releaseYear {
    final raw = _vodInfo?['releasedate'] ?? _vodInfo?['release_date'];
    if (raw is String && raw.length >= 4) return raw.substring(0, 4);
    return null;
  }

  String? get _genre {
    final g = _vodInfo?['genre'] ?? widget.contentItem.vodStream?.genre;
    if (g is String && g.trim().isNotEmpty) {
      return g
          .split(RegExp(r'[,/|]'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .take(2)
          .join(', ');
    }
    return null;
  }

  double? get _rating {
    final raw = _vodInfo?['rating'] ?? widget.contentItem.vodStream?.rating;
    final v = double.tryParse(raw?.toString().replaceAll(',', '.') ?? '');
    return (v == null || v <= 0) ? null : v;
  }

  static String _humanDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h == 0) return '$m min';
    return '$h h ${m.toString().padLeft(2, '0')}';
  }

  Future<void> _loadFavorite() async {
    try {
      final fav = await _favorites.isFavorite(
        widget.contentItem.id,
        ContentType.vod,
      );
      final playlist = AppState.currentPlaylist;
      final inCustom = playlist == null
          ? false
          : await CustomListsService().containsAnywhere(
              playlist.id,
              widget.contentItem.id,
            );
      if (mounted) setState(() => _inList = fav || inCustom);
    } catch (_) {}
  }

  /// « Ma liste » ouvre le choix des listes (Ma liste, Films de Noël…).
  Future<void> _toggleList() async {
    await showListPicker(context, widget.contentItem);
    await _loadFavorite();
  }

  /// Autres versions du même film chez le fournisseur (4K, UHD…).
  Future<void> _loadVersions() async {
    final repo = _repository;
    if (repo == null) return;
    try {
      final info = TitleInfo.parse(widget.contentItem.name);
      final found = await repo.searchMovies(info.title);
      final same = found
          .where((m) => TitleInfo.parse(m.name).key == info.key)
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
      if (!same.any((v) => v.id == widget.contentItem.id)) {
        same.add(widget.contentItem);
      }
      same.sort(_compareVersions);
      if (mounted && same.length > 1) setState(() => _versions = same);
    } catch (e) {
      debugPrint('Error loading versions: $e');
    }
  }

  /// Version standard d'abord, puis par qualité croissante.
  static int _compareVersions(ContentItem a, ContentItem b) {
    int rank(ContentItem i) {
      final tags = TitleInfo.parse(i.name).tags.join(' ').toUpperCase();
      if (tags.isEmpty) return 0;
      if (tags.contains('UHD')) return 4;
      if (tags.contains('4K')) return 3;
      if (tags.contains('FULL HD') || tags.contains('HD')) return 1;
      return 2;
    }

    final r = rank(a).compareTo(rank(b));
    return r != 0 ? r : a.name.compareTo(b.name);
  }

  void _openVersion(ContentItem item) {
    if (item.id == widget.contentItem.id) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => MovieScreen(contentItem: item),
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    final resuming = !_isLoadingHistory &&
        progress != null &&
        progress > 0.01 &&
        progress < 0.98;
    final duration = _duration;
    final remaining = resuming && _watchHistory?.totalDuration != null
        ? _watchHistory!.totalDuration! - _watchHistory!.watchDuration!
        : null;
    final related = groupVersions(
      _categoryMovies.where((m) => m.id != widget.contentItem.id),
      (m) => m.name,
    ).take(20).toList();

    return DetailView(
      title: widget.contentItem.name,
      posterUrl: _posterUrl,
      backdropUrl: _backdropUrl,
      rating: _rating,
      meta: [
        if (_releaseYear != null) _releaseYear!,
        if (duration != null && duration > 0) _humanDuration(duration),
        if (_genre != null) _genre!,
      ],
      plot: _plotSummary,
      loading: _isLoadingVodInfo,
      credits: [
        if (_directorInfo != null) ('Réalisation', _directorInfo!),
        if (_castInfo != null) ('Avec', _castInfo!),
      ],
      playLabel: resuming ? 'Reprendre' : 'Lecture',
      onPlay: _openPlayer,
      progress: resuming ? progress : null,
      progressLabel: remaining == null
          ? null
          : 'Reste ${_humanDuration(remaining.inSeconds)}',
      versions: [
        for (final v in _versions) TitleInfo.parse(v.name).versionLabel,
      ],
      selectedVersion: _versions.indexWhere(
        (v) => v.id == widget.contentItem.id,
      ),
      onVersion: (i) => _openVersion(_versions[i]),
      inList: _inList,
      onToggleList: _toggleList,
      onTrailer: widget.contentItem.vodStream == null
          ? null
          : () => _openTrailer(context),
      related: related.isEmpty
          ? null
          : MediaRow<ContentItem>(
              title: 'Dans la même catégorie',
              items: related,
              itemBuilder: (context, item, width) => PosterCard(
                title: item.name,
                imageUrl: item.imagePath,
                width: width,
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => MovieScreen(contentItem: item),
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _openTrailer(BuildContext context) async {
    final vod = widget.contentItem.vodStream;
    if (vod == null) {
      return;
    }

    final trailerKey = vod.youtubeTrailer;
    final languageCode = Localizations.localeOf(context).languageCode;

    final String urlString;
    if (trailerKey != null && trailerKey.isNotEmpty) {
      urlString = 'https://www.youtube.com/watch?v=$trailerKey';
    } else {
      final query = Uri.encodeQueryComponent(
        '${cleanTitle(widget.contentItem.name)} trailer $languageCode',
      );
      urlString = 'https://www.youtube.com/results?search_query=$query';
    }

    final uri = Uri.parse(urlString);
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.loc.error_occurred_title)),
      );
    }
  }

  void _openPlayer() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => _MoviePlayerPage(
          contentItem: widget.contentItem,
          queue:
              _categoryMovies.isNotEmpty
                  ? _categoryMovies
                  : [widget.contentItem],
        ),
      ),
    );
  }
}

class _MoviePlayerPage extends StatefulWidget {
  final ContentItem contentItem;
  final List<ContentItem> queue;

  const _MoviePlayerPage({required this.contentItem, required this.queue});

  @override
  State<_MoviePlayerPage> createState() => _MoviePlayerPageState();
}

class _MoviePlayerPageState extends State<_MoviePlayerPage> {
  @override
  void initState() {
    super.initState();
    _hideSystemUI();
  }

  @override
  void dispose() {
    _showSystemUI();
    super.dispose();
  }

  void _hideSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  void _showSystemUI() {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SizedBox.expand(
          child: PlayerWidget(
            contentItem: widget.contentItem,
            queue: widget.queue,
          ),
        ),
      ),
    );
  }
}
