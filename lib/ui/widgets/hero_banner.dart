import 'package:flutter/material.dart';

import '../../utils/app_themes.dart';
import 'app_image.dart';
import 'poster_card.dart';

/// Grande affiche « à la une » en haut de l'accueil.
class HeroBanner extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String? tagline;
  final VoidCallback onPlay;
  final VoidCallback onInfo;
  final VoidCallback? onToggleList;
  final bool inList;

  const HeroBanner({
    super.key,
    required this.title,
    required this.imageUrl,
    required this.onPlay,
    required this.onInfo,
    this.tagline,
    this.onToggleList,
    this.inList = false,
  });

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    // L'affiche reste toujours sombre (texte blanc sur l'image) ; en mode
    // clair elle se termine par des coins arrondis au lieu d'un fondu gris.
    return Theme(
      data: AppThemes.darkTheme,
      child: Builder(builder: (context) => _build(context, light)),
    );
  }

  Widget _build(BuildContext context, bool light) {
    final theme = Theme.of(context);
    final size = MediaQuery.sizeOf(context);
    final isTablet = size.width >= 600;
    final height = isTablet
        ? (size.height * 0.55).clamp(380.0, 560.0)
        : (size.width * 1.32).clamp(420.0, 600.0);
    final bg = theme.scaffoldBackgroundColor;
    final radius = light
        ? const BorderRadius.vertical(bottom: Radius.circular(28))
        : BorderRadius.zero;

    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            AppImage(
              url: imageUrl,
              fallback: (context) => TitleArt(title: title),
            ),
            // Fondu vers le fond de l'écran en bas, léger assombrissement en haut
            // pour garder la barre du haut lisible.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.transparent,
                    bg.withValues(alpha: light ? 0.55 : 0.65),
                    bg.withValues(alpha: light ? 0.92 : 1),
                  ],
                  stops: const [0, 0.25, 0.68, 1],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: isTablet
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      textAlign: isTablet ? TextAlign.start : TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                        shadows: const [
                          Shadow(blurRadius: 18, color: Color(0x66000000)),
                        ],
                      ),
                    ),
                    if (tagline != null && tagline!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        tagline!,
                        textAlign: isTablet
                            ? TextAlign.start
                            : TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.85,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onToggleList != null) ...[
                          _RoundAction(
                            icon: inList
                                ? Icons.check_rounded
                                : Icons.add_rounded,
                            label: 'Ma liste',
                            onTap: onToggleList!,
                          ),
                          const SizedBox(width: 18),
                        ],
                        FilledButton.icon(
                          onPressed: onPlay,
                          icon: const Icon(Icons.play_arrow_rounded, size: 26),
                          label: const Text('Lecture'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.fromLTRB(18, 0, 26, 0),
                          ),
                        ),
                        const SizedBox(width: 18),
                        _RoundAction(
                          icon: Icons.info_outline_rounded,
                          label: 'Infos',
                          onTap: onInfo,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _RoundAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: theme.colorScheme.onSurface),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
