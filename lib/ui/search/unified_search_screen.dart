import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/content_type.dart';
import '../../models/playlist_content_model.dart';
import '../../services/app_state.dart';
import '../../utils/navigate_by_content_type.dart';
import '../../services/movie_versions.dart';
import '../../utils/title_cleaner.dart';
import '../widgets/media_row.dart';
import '../widgets/poster_card.dart';

/// Une seule recherche pour les films, les séries et les chaînes.
class UnifiedSearchScreen extends StatefulWidget {
  const UnifiedSearchScreen({super.key});

  @override
  State<UnifiedSearchScreen> createState() => _UnifiedSearchScreenState();
}

class _UnifiedSearchScreenState extends State<UnifiedSearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  List<ContentItem> _movies = [];
  List<ContentItem> _series = [];
  List<ContentItem> _channels = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _search(value.trim());
    });
  }

  Future<void> _search(String q) async {
    final repo = AppState.xtreamCodeRepository;
    if (repo == null) return;
    setState(() {
      _query = q;
      _loading = q.length >= 2;
    });
    if (q.length < 2) {
      setState(() {
        _movies = [];
        _series = [];
        _channels = [];
      });
      return;
    }
    final results = await Future.wait([
      repo.searchMovies(q),
      repo.searchSeries(q),
      repo.searchLiveStreams(q),
    ]);
    if (!mounted || q != _query) return;
    // Même titre ≠ même film : on ne fusionne que si le fournisseur le confirme.
    final movies = await MovieVersions.group<dynamic>(
      repo,
      (results[0] as List).take(120).toList(),
      idOf: (m) => m.streamId as String,
      nameOf: (m) => m.name as String,
    );
    if (!mounted || q != _query) return;
    setState(() {
      _loading = false;
      _movies = movies
          .take(60)
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
      _series = groupVersions(
        (results[1] as List),
        (s) => s.name as String,
        identityOf: (s) => yearOf(s.releaseDate as String?),
      )
          .take(60)
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
      _channels = (results[2] as List)
          .take(60)
          .map(
            (l) => ContentItem(
              l.streamId,
              l.name,
              l.streamIcon,
              ContentType.liveStream,
              liveStream: l,
            ),
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = _movies.isEmpty && _series.isEmpty && _channels.isEmpty;

    Widget body;
    if (_query.length < 2) {
      body = _Hint(
        icon: Icons.search_rounded,
        text: 'Cherche un film, une série ou une chaîne.',
      );
    } else if (_loading && empty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (empty) {
      body = _Hint(
        icon: Icons.sentiment_dissatisfied_rounded,
        text: 'Aucun résultat pour « $_query ».',
      );
    } else {
      body = ListView(
        padding: const EdgeInsets.only(top: 12, bottom: 24),
        children: [
          _row('Films', _movies, PosterShape.poster),
          _row('Séries', _series, PosterShape.poster),
          _row('Chaînes', _channels, PosterShape.channel),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TextField(
            controller: _controller,
            autofocus: true,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            onSubmitted: (v) => _search(v.trim()),
            style: theme.textTheme.bodyLarge,
            decoration: InputDecoration(
              hintText: 'Titre, chaîne…',
              prefixIcon: const Icon(Icons.search_rounded),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _controller.clear();
                        _search('');
                      },
                    ),
            ),
          ),
        ),
      ),
      body: body,
    );
  }

  Widget _row(String title, List<ContentItem> items, PosterShape shape) {
    return MediaRow<ContentItem>(
      title: '$title (${items.length})',
      items: items,
      shape: shape,
      itemBuilder: (context, item, width) => PosterCard(
        title: item.name,
        imageUrl: item.imagePath,
        width: width,
        shape: shape,
        onTap: () => navigateByContentType(context, item),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Hint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
