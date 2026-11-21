import 'package:flutter/material.dart';
import 'package:another_iptv_player/models/playlist_content_model.dart';
import 'package:another_iptv_player/models/content_type.dart';

import '../ui/widgets/poster_card.dart';

/// Vignette d'un contenu (grilles et rangées de l'app d'origine), au même
/// style que le reste de Lemaire TV.
class ContentCard extends StatelessWidget {
  final ContentItem content;
  final double width;
  final VoidCallback? onTap;
  final bool isSelected;

  const ContentCard({
    super.key,
    required this.content,
    required this.width,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth.isFinite ? box.maxWidth : width;
        return Align(
          alignment: Alignment.topCenter,
          child: PosterCard(
            title: content.name,
            imageUrl: content.imagePath,
            width: w,
            shape: content.contentType == ContentType.liveStream
                ? PosterShape.channel
                : PosterShape.poster,
            selected: isSelected,
            onTap: onTap,
          ),
        );
      },
    );
  }
}
