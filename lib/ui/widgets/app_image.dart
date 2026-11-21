import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Construit une image distante. Remplaçable dans les tests (captures
/// d'écran) pour afficher des images locales sans réseau.
typedef AppImageBuilder =
    Widget Function(
      BuildContext context,
      String url,
      BoxFit fit,
      Widget Function(BuildContext) fallback,
    );

class AppImage extends StatelessWidget {
  final String? url;
  final BoxFit fit;
  final WidgetBuilder fallback;
  final int? cacheWidth;

  const AppImage({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.cacheWidth,
  });

  /// Point d'injection pour les tests.
  static AppImageBuilder? debugBuilder;

  @override
  Widget build(BuildContext context) {
    final u = url?.trim() ?? '';
    if (u.isEmpty || !(u.startsWith('http://') || u.startsWith('https://'))) {
      return fallback(context);
    }
    final override = debugBuilder;
    if (override != null) return override(context, u, fit, fallback);
    return CachedNetworkImage(
      imageUrl: u,
      fit: fit,
      memCacheWidth: cacheWidth,
      fadeInDuration: const Duration(milliseconds: 180),
      placeholder: (context, _) => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      errorWidget: (context, _, __) => fallback(context),
    );
  }
}
