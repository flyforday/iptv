import 'package:flutter/material.dart';

import '../../models/category_view_model.dart';
import '../../models/playlist_content_model.dart';
import '../../utils/title_cleaner.dart';
import '../widgets/media_row.dart';
import '../widgets/poster_card.dart';

/// Onglet Films / Séries / TV : une rangée par catégorie.
class CatalogView extends StatelessWidget {
  final List<CategoryViewModel> categories;
  final PosterShape shape;
  final void Function(ContentItem item) onOpen;
  final void Function(CategoryViewModel category) onSeeAll;
  final String emptyMessage;

  const CatalogView({
    super.key,
    required this.categories,
    required this.onOpen,
    required this.onSeeAll,
    this.shape = PosterShape.poster,
    this.emptyMessage = 'Rien à afficher pour le moment.',
  });

  @override
  Widget build(BuildContext context) {
    if (categories.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyMessage,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final category = categories[i];
        return MediaRow<ContentItem>(
          title: cleanTitle(category.category.categoryName),
          items: shape == PosterShape.channel
              ? category.contentItems
              : groupVersions(category.contentItems, (i) => i.name),
          shape: shape,
          onSeeAll: () => onSeeAll(category),
          itemBuilder: (context, item, width) => PosterCard(
            title: item.name,
            imageUrl: item.imagePath,
            width: width,
            shape: shape,
            onTap: () => onOpen(item),
          ),
        );
      },
    );
  }
}
