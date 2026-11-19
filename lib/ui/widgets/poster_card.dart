import 'package:flutter/material.dart';

import '../../utils/app_themes.dart';
import 'app_image.dart';

/// Forme d'une vignette.
enum PosterShape {
  /// Affiche verticale 2:3 (films, séries).
  poster,

  /// Vignette 16:9 avec titre dessous (Continuer à regarder).
  landscape,

  /// Logo de chaîne sur fond neutre, nom dessous.
  channel,
}

extension PosterShapeSize on PosterShape {
  /// Hauteur totale occupée par une vignette de largeur [width].
  double heightFor(double width) {
    switch (this) {
      case PosterShape.poster:
        return width * 1.5;
      case PosterShape.landscape:
        return width * 9 / 16 + 48;
      case PosterShape.channel:
        return width * 0.62 + 30;
    }
  }
}

class PosterCard extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final double width;
  final PosterShape shape;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Avancement de lecture entre 0 et 1 (barre rose), ou null.
  final double? progress;

  /// Texte secondaire (ex. « Reste 12 min »).
  final String? subtitle;
  final bool selected;

  const PosterCard({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.width,
    this.shape = PosterShape.poster,
    this.onTap,
    this.onLongPress,
    this.progress,
    this.subtitle,
    this.selected = false,
  });

  static const _radius = 10.0;

  @override
  Widget build(BuildContext context) {
    switch (shape) {
      case PosterShape.poster:
        return _poster(context);
      case PosterShape.landscape:
        return _landscape(context);
      case PosterShape.channel:
        return _channel(context);
    }
  }

  Widget _tap({required Widget child, required BorderRadius radius}) {
    return Material(
      color: Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, onLongPress: onLongPress, child: child),
    );
  }

  Widget _frame(BuildContext context, Widget child) {
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_radius),
        border: selected
            ? Border.all(color: AppColors.pink, width: 2.5)
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_radius),
        child: child,
      ),
    );
  }

  Widget _poster(BuildContext context) {
    return SizedBox(
      width: width,
      height: PosterShape.poster.heightFor(width),
      child: _frame(
        context,
        Stack(
          fit: StackFit.expand,
          children: [
            AppImage(
              url: imageUrl,
              cacheWidth: (width * 2.5).round(),
              fallback: (context) => TitleArt(title: title),
            ),
            if (progress != null) _progressBar(alignBottom: true),
            Positioned.fill(
              child: _tap(
                radius: BorderRadius.circular(_radius),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _landscape(BuildContext context) {
    final theme = Theme.of(context);
    final imageHeight = width * 9 / 16;
    return SizedBox(
      width: width,
      child: _tap(
        radius: BorderRadius.circular(_radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: imageHeight,
              width: width,
              child: _frame(
                context,
                Stack(
                  fit: StackFit.expand,
                  children: [
                    AppImage(
                      url: imageUrl,
                      cacheWidth: (width * 2.5).round(),
                      fallback: (context) => TitleArt(title: title),
                    ),
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x99000000)],
                          stops: [0.45, 1],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                      ),
                    ),
                    if (progress != null) _progressBar(alignBottom: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _channel(BuildContext context) {
    final theme = Theme.of(context);
    final boxHeight = width * 0.62;
    return SizedBox(
      width: width,
      child: _tap(
        radius: BorderRadius.circular(_radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: boxHeight,
              width: width,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(_radius),
                border: Border.all(
                  color: selected
                      ? AppColors.pink
                      : theme.colorScheme.outlineVariant,
                  width: selected ? 2.5 : 1,
                ),
              ),
              padding: const EdgeInsets.all(14),
              child: AppImage(
                url: imageUrl,
                fit: BoxFit.contain,
                cacheWidth: (width * 2.5).round(),
                fallback: (context) => Center(
                  child: Text(
                    _initials(title),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.pink,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _progressBar({required bool alignBottom}) {
    final value = (progress ?? 0).clamp(0.0, 1.0);
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: 4,
        child: Stack(
          children: [
            Container(color: Colors.white.withValues(alpha: 0.30)),
            FractionallySizedBox(
              widthFactor: value,
              child: Container(color: AppColors.pink),
            ),
          ],
        ),
      ),
    );
  }

  static String _initials(String name) {
    final words = name
        .replaceAll(RegExp(r'[^A-Za-zÀ-ÿ0-9 ]'), ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 'TV';
    if (words.length == 1) {
      return words.first.substring(0, words.first.length.clamp(1, 3)).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }
}

/// Affiche de remplacement quand le fournisseur n'a pas d'image :
/// dégradé de couleur stable par titre + titre en gros.
class TitleArt extends StatelessWidget {
  final String title;

  const TitleArt({super.key, required this.title});

  static const _palettes = [
    [Color(0xFFFF2E7E), Color(0xFF6A1B9A)],
    [Color(0xFF7B2FF7), Color(0xFF1A1A40)],
    [Color(0xFFFF6B6B), Color(0xFF4A1029)],
    [Color(0xFF00B4D8), Color(0xFF1B263B)],
    [Color(0xFFF77F00), Color(0xFF6A040F)],
    [Color(0xFF2EC4B6), Color(0xFF14213D)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _palettes[title.hashCode.abs() % _palettes.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Text(
            title,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              height: 1.15,
              letterSpacing: -0.2,
            ),
          ),
        ),
      ),
    );
  }
}
