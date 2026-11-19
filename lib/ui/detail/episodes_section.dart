import 'package:flutter/material.dart';

import '../../utils/app_themes.dart';
import '../widgets/app_image.dart';
import '../widgets/poster_card.dart';

class EpisodeEntry {
  final String id;
  final int season;
  final int number;
  final String title;
  final String? imageUrl;
  final String? durationLabel;
  final String? plot;
  final double? progress;

  const EpisodeEntry({
    required this.id,
    required this.season,
    required this.number,
    required this.title,
    this.imageUrl,
    this.durationLabel,
    this.plot,
    this.progress,
  });
}

/// Choix de la saison + liste des épisodes.
class EpisodesSection extends StatefulWidget {
  final List<EpisodeEntry> episodes;
  final int? initialSeason;
  final String? fallbackImage;
  final void Function(EpisodeEntry episode) onTap;

  const EpisodesSection({
    super.key,
    required this.episodes,
    required this.onTap,
    this.initialSeason,
    this.fallbackImage,
  });

  @override
  State<EpisodesSection> createState() => _EpisodesSectionState();
}

class _EpisodesSectionState extends State<EpisodesSection> {
  int? _season;

  List<int> get _seasons {
    final s = widget.episodes.map((e) => e.season).toSet().toList()..sort();
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seasons = _seasons;
    if (seasons.isEmpty) return const SizedBox.shrink();
    final current = (_season != null && seasons.contains(_season))
        ? _season!
        : (widget.initialSeason != null &&
                  seasons.contains(widget.initialSeason))
              ? widget.initialSeason!
              : seasons.first;
    final list =
        widget.episodes.where((e) => e.season == current).toList()
          ..sort((a, b) => a.number.compareTo(b.number));
    final gutter = MediaQuery.sizeOf(context).width >= 700 ? 32.0 : 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          child: Text(
            'Épisodes',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
        const SizedBox(height: 10),
        if (seasons.length > 1)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: gutter),
              itemCount: seasons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final s = seasons[i];
                final selected = s == current;
                return ChoiceChip(
                  label: Text('Saison $s'),
                  selected: selected,
                  onSelected: (_) => setState(() => _season = s),
                  labelStyle: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : theme.colorScheme.onSurface,
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 12),
        for (final e in list)
          _EpisodeTile(
            episode: e,
            gutter: gutter,
            fallbackImage: widget.fallbackImage,
            onTap: () => widget.onTap(e),
          ),
      ],
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final EpisodeEntry episode;
  final double gutter;
  final String? fallbackImage;
  final VoidCallback onTap;

  const _EpisodeTile({
    required this.episode,
    required this.gutter,
    required this.onTap,
    this.fallbackImage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final p = episode.progress;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 132,
                  height: 74,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppImage(
                          url: episode.imageUrl ?? fallbackImage,
                          fallback: (_) =>
                              TitleArt(title: 'Épisode ${episode.number}'),
                        ),
                        Center(
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.2),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                        if (p != null && p > 0)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: SizedBox(
                              height: 3,
                              child: Stack(
                                children: [
                                  Container(
                                    color: Colors.white.withValues(alpha: 0.3),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: p.clamp(0.0, 1.0),
                                    child: Container(color: AppColors.pink),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${episode.number}. ${episode.title}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (episode.durationLabel != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          episode.durationLabel!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (episode.plot != null && episode.plot!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                episode.plot!.trim(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: muted,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
