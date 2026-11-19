import 'dart:ui';

import 'package:flutter/material.dart';

import '../../utils/app_themes.dart';
import '../widgets/app_image.dart';
import '../widgets/poster_card.dart';

/// Fiche d'un film ou d'une série, façon plateforme de streaming.
/// Purement visuelle : toutes les données et actions viennent de l'appelant.
class DetailView extends StatelessWidget {
  final String title;
  final String? posterUrl;
  final String? backdropUrl;

  /// Petites infos sous le titre : année, durée, genre…
  final List<String> meta;
  final double? rating;
  final String? plot;

  /// Crédits : (« Réalisation », « … »), (« Avec », « … »).
  final List<(String, String)> credits;

  final String playLabel;
  final VoidCallback? onPlay;
  final double? progress;
  final String? progressLabel;

  final bool inList;
  final VoidCallback? onToggleList;
  final VoidCallback? onTrailer;

  /// Bloc en plus sous le résumé (épisodes d'une série).
  final Widget? extra;

  /// Rangée « Dans le même genre ».
  final Widget? related;

  final bool loading;

  const DetailView({
    super.key,
    required this.title,
    required this.playLabel,
    this.posterUrl,
    this.backdropUrl,
    this.meta = const [],
    this.rating,
    this.plot,
    this.credits = const [],
    this.onPlay,
    this.progress,
    this.progressLabel,
    this.inList = false,
    this.onToggleList,
    this.onTrailer,
    this.extra,
    this.related,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.width >= 700;
    final gutter = isTablet ? 32.0 : 16.0;

    final info = _InfoBlock(view: this, centered: false);
    final light = Theme.of(context).brightness == Brightness.light;
    const rounded = BorderRadius.vertical(bottom: Radius.circular(28));

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: ClipRRect(
                  borderRadius: light ? rounded : BorderRadius.zero,
                  child: isTablet
                      // Infos posées sur l'image : toujours en blanc.
                      ? Theme(
                          data: AppThemes.darkTheme,
                          child: _TabletHeader(
                            view: this,
                            gutter: gutter,
                            info: info,
                          ),
                        )
                      : _PhoneHeader(view: this),
                ),
              ),
              if (!isTablet)
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    light ? 16 : 4,
                    gutter,
                    0,
                  ),
                  sliver: SliverToBoxAdapter(child: info),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 18, gutter, 0),
                sliver: SliverToBoxAdapter(child: _Body(view: this)),
              ),
              if (extra != null)
                SliverPadding(
                  padding: const EdgeInsets.only(top: 20),
                  sliver: SliverToBoxAdapter(child: extra),
                ),
              if (related != null)
                SliverPadding(
                  padding: const EdgeInsets.only(top: 24),
                  sliver: SliverToBoxAdapter(child: related),
                ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 32 + MediaQuery.paddingOf(context).bottom,
                ),
              ),
            ],
          ),
          Positioned(
            top: MediaQuery.paddingOf(context).top + 8,
            left: 12,
            child: const _BackButton(),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: 'Retour',
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

/// Fond : image de décor, ou affiche floutée quand il n'y en a pas.
class _Backdrop extends StatelessWidget {
  final DetailView view;

  const _Backdrop({required this.view});

  @override
  Widget build(BuildContext context) {
    final backdrop = view.backdropUrl;
    if (backdrop != null && backdrop.isNotEmpty) {
      return AppImage(url: backdrop, fallback: (_) => _blurredPoster(context));
    }
    return _blurredPoster(context);
  }

  Widget _blurredPoster(BuildContext context) {
    return ClipRect(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: Transform.scale(
          scale: 1.3,
          child: AppImage(
            url: view.posterUrl,
            fallback: (_) => TitleArt(title: view.title),
          ),
        ),
      ),
    );
  }
}

class _Fade extends StatelessWidget {
  const _Fade();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // En mode clair, on fond vers un voile sombre (et non vers le blanc, qui
    // donne un gris délavé) ; l'en-tête se termine par des coins arrondis.
    final bg = theme.brightness == Brightness.light
        ? const Color(0xFF0B0B0F).withValues(alpha: 0.72)
        : theme.scaffoldBackgroundColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.35),
            Colors.transparent,
            bg.withValues(alpha: 0.7),
            bg,
          ],
          stops: const [0, 0.3, 0.8, 1],
        ),
      ),
    );
  }
}

class _PhoneHeader extends StatelessWidget {
  final DetailView view;

  const _PhoneHeader({required this.view});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final hasBackdrop = view.backdropUrl?.isNotEmpty == true;
    final top = MediaQuery.paddingOf(context).top;
    final height = hasBackdrop ? width * 9 / 16 + top + 40 : 300.0 + top;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _Backdrop(view: view),
          const _Fade(),
          if (!hasBackdrop)
            Positioned(
              top: top + 24,
              left: 0,
              right: 0,
              bottom: 8,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 2 / 3,
                  child: _PosterBox(view: view),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabletHeader extends StatelessWidget {
  final DetailView view;
  final double gutter;
  final Widget info;

  const _TabletHeader({
    required this.view,
    required this.gutter,
    required this.info,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        Positioned.fill(child: _Backdrop(view: view)),
        const Positioned.fill(child: _Fade()),
        Padding(
          padding: EdgeInsets.fromLTRB(gutter, top + 72, gutter, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(width: 210, height: 315, child: _PosterBox(view: view)),
              const SizedBox(width: 28),
              Expanded(
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: info,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PosterBox extends StatelessWidget {
  final DetailView view;

  const _PosterBox({required this.view});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: AppImage(
          url: view.posterUrl,
          fallback: (_) => TitleArt(title: view.title),
        ),
      ),
    );
  }
}

/// Titre, infos, bouton Lecture et actions.
class _InfoBlock extends StatelessWidget {
  final DetailView view;
  final bool centered;

  const _InfoBlock({required this.view, required this.centered});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final p = view.progress;
    final showProgress = p != null && p > 0.01 && p < 0.98;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          view.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (view.rating != null && view.rating! > 0)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.star_rounded,
                    size: 18,
                    color: AppColors.pink,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    view.rating!.toStringAsFixed(1).replaceAll('.', ','),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            for (final m in view.meta)
              Text(
                m,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: view.onPlay,
            icon: const Icon(Icons.play_arrow_rounded, size: 30),
            label: Text(view.playLabel),
          ),
        ),
        if (showProgress) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(value: p, minHeight: 4),
                ),
              ),
              if (view.progressLabel != null) ...[
                const SizedBox(width: 10),
                Text(
                  view.progressLabel!,
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ],
            ],
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            if (view.onToggleList != null)
              _ActionButton(
                icon: view.inList ? Icons.check_rounded : Icons.add_rounded,
                label: 'Ma liste',
                onTap: view.onToggleList!,
                active: view.inList,
              ),
            if (view.onTrailer != null)
              _ActionButton(
                icon: Icons.movie_creation_outlined,
                label: 'Bande-annonce',
                onTap: view.onTrailer!,
              ),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 26,
                color: active ? AppColors.pink : theme.colorScheme.onSurface,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Résumé et crédits.
class _Body extends StatelessWidget {
  final DetailView view;

  const _Body({required this.view});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final plot = view.plot?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (view.loading && (plot == null || plot.isEmpty))
          const LinearProgressIndicator(minHeight: 2),
        if (plot != null && plot.isNotEmpty) _ExpandableText(text: plot),
        if (view.credits.isNotEmpty) ...[
          const SizedBox(height: 14),
          for (final (label, value) in view.credits)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$label : ',
                      style: TextStyle(color: muted),
                    ),
                    TextSpan(text: value),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
              ),
            ),
        ],
      ],
    );
  }
}

class _ExpandableText extends StatefulWidget {
  final String text;

  const _ExpandableText({required this.text});

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.topCenter,
        child: Text(
          widget.text,
          maxLines: _open ? null : 4,
          overflow: _open ? TextOverflow.visible : TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
        ),
      ),
    );
  }
}
