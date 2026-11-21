import 'package:flutter/material.dart';

import 'poster_card.dart';

/// Tailles de vignettes selon la largeur de l'écran (téléphone / tablette).
class MediaSizes {
  final double screenWidth;

  const MediaSizes(this.screenWidth);

  factory MediaSizes.of(BuildContext context) =>
      MediaSizes(MediaQuery.sizeOf(context).width);

  bool get isTablet => screenWidth >= 600;

  double widthFor(PosterShape shape) {
    switch (shape) {
      case PosterShape.poster:
        return screenWidth >= 1000 ? 170 : (isTablet ? 148 : 112);
      case PosterShape.landscape:
        return isTablet ? 280 : 210;
      case PosterShape.channel:
        return isTablet ? 150 : 118;
    }
  }

  double get gutter => isTablet ? 24 : 16;
}

/// Rangée horizontale façon plateforme de streaming : titre + vignettes.
class MediaRow<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final PosterShape shape;
  final Widget Function(BuildContext context, T item, double width) itemBuilder;
  final VoidCallback? onSeeAll;

  const MediaRow({
    super.key,
    required this.title,
    required this.items,
    required this.itemBuilder,
    this.shape = PosterShape.poster,
    this.onSeeAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final sizes = MediaSizes.of(context);
    final width = sizes.widthFor(shape);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SectionHeader(title: title, onTap: onSeeAll, gutter: sizes.gutter),
          SizedBox(
            height: shape.heightFor(width),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: sizes.gutter),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => itemBuilder(context, items[i], width),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final double gutter;

  const SectionHeader({
    super.key,
    required this.title,
    this.onTap,
    this.gutter = 16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.fromLTRB(gutter, 4, gutter, 10),
        child: Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 2),
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
