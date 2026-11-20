import 'package:flutter/material.dart';

import '../../services/custom_lists_service.dart';
import '../../ui/lists/list_picker_sheet.dart';
import 'package:another_iptv_player/database/database.dart';
import 'package:another_iptv_player/models/api_configuration_model.dart';
import 'package:another_iptv_player/models/content_type.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/services/app_state.dart';
import 'package:another_iptv_player/repositories/iptv_repository.dart';
import 'package:another_iptv_player/l10n/localization_extension.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:another_iptv_player/services/watch_history_service.dart';
import '../../../controllers/favorites_controller.dart';
import 'episode_screen.dart';
import '../../ui/detail/detail_view.dart';
import '../../ui/detail/episodes_section.dart';

class SeriesScreen extends StatefulWidget {
  final ContentItem contentItem;

  const SeriesScreen({super.key, required this.contentItem});

  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  late IptvRepository _repository;
  late FavoritesController _favoritesController;
  late WatchHistoryService _watchHistoryService;

  SeriesInfosData? seriesInfo;
  List<SeasonsData> seasons = [];
  List<EpisodesData> episodes = [];
  bool isLoading = true;
  String? error;
  bool _isFavorite = false;

  // Last opened episode for this series (for Continue Watching button)
  EpisodesData? _lastOpenedEpisode;

  // Avancement de chaque épisode déjà commencé (id -> 0..1).
  final Map<String, double> _episodeProgress = {};

  @override
  void initState() {
    super.initState();
    _initializeRepository();
    _favoritesController = FavoritesController();
    _watchHistoryService = WatchHistoryService();
    _loadSeriesDetails();
    _checkFavoriteStatus();
  }

  void _initializeRepository() {
    _repository = IptvRepository(
      ApiConfig(
        baseUrl: AppState.currentPlaylist!.url!,
        username: AppState.currentPlaylist!.username!,
        password: AppState.currentPlaylist!.password!,
      ),
      AppState.currentPlaylist!.id,
    );
  }

  Future<void> _loadSeriesDetails() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final seriesId = widget.contentItem.id;

      final seriesResponse = await _repository.getSeriesInfo(seriesId);

      if (seriesResponse != null) {
        setState(() {
          seriesInfo = seriesResponse.seriesInfo;
          seasons = seriesResponse.seasons;
          episodes = seriesResponse.episodes;
          isLoading = false;
        });

        // After episodes are loaded, fetch last opened episode from history
        await _loadLastOpenedEpisodeFromHistory();
      } else {
        setState(() {
          error = context.loc.preparing_series_exception_1;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = context.loc.preparing_series_exception_2(e.toString());
        isLoading = false;
      });
    }
  }

  Future<void> _loadLastOpenedEpisodeFromHistory() async {
    if (episodes.isEmpty) return;

    final playlistId = AppState.currentPlaylist!.id;

    // Get all series-type history entries for this playlist
    final allSeriesHistory = await _watchHistoryService
        .getWatchHistoryByContentType(ContentType.series, playlistId);

    if (!mounted || allSeriesHistory.isEmpty) return;

    // Build a map episodeId -> EpisodesData for fast lookup
    final Map<String, EpisodesData> byId = {
      for (final ep in episodes) ep.episodeId.toString(): ep,
    };

    for (final h in allSeriesHistory) {
      final w = h.watchDuration?.inMilliseconds;
      final t = h.totalDuration?.inMilliseconds;
      if (byId.containsKey(h.streamId) && w != null && t != null && t > 0) {
        _episodeProgress.putIfAbsent(h.streamId, () => w / t);
      }
    }

    // Find the most recent history entry whose streamId is one of this series' episode ids
    EpisodesData? matched;
    for (final history in allSeriesHistory) {
      final ep = byId[history.streamId];
      if (ep != null) {
        matched = ep;
        break;
      }
    }

    if (matched != null && mounted) {
      setState(() {
        _lastOpenedEpisode = matched;
      });
    }
  }

  Future<void> _checkFavoriteStatus() async {
    final isFavorite = await _favoritesController.isFavorite(
      widget.contentItem.id,
      widget.contentItem.contentType,
    );
    final playlist = AppState.currentPlaylist;
    final inCustom = playlist == null
        ? false
        : await CustomListsService().containsAnywhere(
            playlist.id,
            widget.contentItem.id,
          );

    if (mounted) {
      setState(() {
        _isFavorite = isFavorite || inCustom;
      });
    }
  }

  /// « Ma liste » ouvre le choix des listes (Ma liste, Films de Noël…).
  Future<void> _toggleFavorite() async {
    await showListPicker(context, widget.contentItem);
    await _checkFavoriteStatus();
  }

  // Centralized navigation for episodes (used by list + Continue button)
  void _openEpisodeFromSeries(EpisodesData episode) {
    // Update in-memory last opened so button text updates immediately
    setState(() {
      _lastOpenedEpisode = episode;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EpisodeScreen(
          seriesInfo: seriesInfo,
          seasons: seasons,
          episodes: episodes,
          contentItem: ContentItem(
            episode.episodeId,
            episode.title,
            episode.movieImage ?? "",
            ContentType.series,
            containerExtension: episode.containerExtension,
            season: episode.season,
          ),
        ),
      ),
    );
  }

  double? _rating() {
    final v = double.tryParse(
      (seriesInfo?.rating ?? widget.contentItem.seriesStream?.rating ?? '')
          .replaceAll(',', '.'),
    );
    return (v == null || v <= 0) ? null : v;
  }

  String? _backdrop() {
    final raw = seriesInfo?.backdropPath;
    if (raw != null && raw.isNotEmpty) {
      final match = RegExp(r'https?://[^"\]\s,]+').firstMatch(raw);
      if (match != null) return match.group(0);
    }
    final list = widget.contentItem.seriesStream?.backdropPath;
    if (list != null && list.isNotEmpty && list.first.isNotEmpty) {
      return list.first;
    }
    return null;
  }

  static String? _durationLabel(EpisodesData e) {
    final secs = e.durationSecs;
    if (secs != null && secs > 0) {
      final m = (secs / 60).round();
      return m >= 60 ? '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')}' : '$m min';
    }
    final d = e.duration;
    if (d != null && d.isNotEmpty && d != '00:00:00') return d;
    return null;
  }

  EpisodesData? get _nextToPlay {
    if (_lastOpenedEpisode != null) return _lastOpenedEpisode;
    if (episodes.isEmpty) return null;
    final sorted = [...episodes]
      ..sort((a, b) {
        final s = a.season.compareTo(b.season);
        return s != 0 ? s : a.episodeNum.compareTo(b.episodeNum);
      });
    return sorted.first;
  }

  @override
  Widget build(BuildContext context) {
    final info = seriesInfo;
    final next = _nextToPlay;
    final genre = (info?.genre ?? widget.contentItem.seriesStream?.genre)
        ?.split(RegExp(r'[,/|]'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(2)
        .join(', ');
    final date = info?.releaseDate ?? widget.contentItem.seriesStream?.releaseDate;
    final seasonCount = episodes.map((e) => e.season).toSet().length;
    final poster = (info?.cover?.isNotEmpty == true)
        ? info!.cover
        : widget.contentItem.imagePath;

    String playLabel = 'Lecture';
    if (next != null) {
      final code = 'S${next.season} É${next.episodeNum}';
      playLabel = _lastOpenedEpisode != null ? 'Reprendre $code' : 'Lecture $code';
    }

    return DetailView(
      title: info?.name ?? widget.contentItem.name,
      posterUrl: poster,
      backdropUrl: _backdrop(),
      rating: _rating(),
      meta: [
        if (date != null && date.length >= 4) date.substring(0, 4),
        if (seasonCount > 0) seasonCount > 1 ? '$seasonCount saisons' : '1 saison',
        if (genre != null && genre.isNotEmpty) genre,
      ],
      plot: info?.plot ?? widget.contentItem.seriesStream?.plot,
      loading: isLoading,
      credits: [
        if (info?.director?.isNotEmpty == true) ('Réalisation', info!.director!),
        if (info?.cast?.isNotEmpty == true) ('Avec', info!.cast!),
      ],
      playLabel: playLabel,
      onPlay: next == null ? null : () => _openEpisodeFromSeries(next),
      inList: _isFavorite,
      onToggleList: _toggleFavorite,
      onTrailer: () => _openSeriesTrailer(info?.youtubeTrailer),
      extra: error != null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(error!),
            )
          : EpisodesSection(
              initialSeason: _lastOpenedEpisode?.season,
              fallbackImage: _backdrop() ?? poster,
              episodes: [
                for (final e in episodes)
                  EpisodeEntry(
                    id: e.episodeId,
                    season: e.season,
                    number: e.episodeNum,
                    title: e.title,
                    imageUrl: (e.movieImage?.isNotEmpty == true) ? e.movieImage : null,
                    durationLabel: _durationLabel(e),
                    plot: e.plot,
                    progress: _episodeProgress[e.episodeId],
                  ),
              ],
              onTap: (entry) {
                final ep = episodes.firstWhere((e) => e.episodeId == entry.id);
                _openEpisodeFromSeries(ep);
              },
            ),
    );
  }

  Future<void> _openSeriesTrailer(String? key) async {
    final String url;
    if (key != null && key.isNotEmpty) {
      url = 'https://www.youtube.com/watch?v=$key';
    } else {
      final q = Uri.encodeQueryComponent('${widget.contentItem.name} bande annonce');
      url = 'https://www.youtube.com/results?search_query=$q';
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
