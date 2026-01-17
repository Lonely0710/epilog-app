import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../../core/presentation/pages/web_browser_page.dart';

class TopRatedItem extends StatelessWidget {
  final Media media;
  final int rank;

  const TopRatedItem({
    super.key,
    required this.media,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        final url = media.sourceUrl.isNotEmpty
            ? media.sourceUrl
            : 'https://www.themoviedb.org/${media.mediaType}/${media.sourceId}';

        // Use TMDB site type or fall back to generic logic
        final args = WebBrowserPageArgs.fromSiteType(
          siteType: SiteType.tmdb,
          url: url,
        );
        context.push('/webview', extra: args);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                // Poster
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: media.posterUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: Icon(Icons.movie, color: Colors.grey)),
                    ),
                    errorWidget: (context, url, error) => Image.asset(
                      'assets/icons/ic_np_poster.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),

                // Rank Icon/Badge (Top Left)
                Positioned(
                  top: 0,
                  left: 0,
                  child: _buildRankBadge(),
                ),

                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: switch (rank) {
                        1 => const Color(0xFFFFC107),
                        2 => const Color(0xFFBDBDBD),
                        3 => const Color(0xFFCD7F32),
                        _ => AppTheme.primary,
                      },
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 10, color: Colors.white),
                        const SizedBox(width: 2),
                        Text(
                          media.ratingImdb > 0 ? media.ratingImdb.toStringAsFixed(1) : 'N/A',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: AppTheme.primaryFont),
                        ),
                      ],
                    ),
                  ),
                ),

                // Date Badge (Bottom Right)
                if (media.releaseDate.isNotEmpty)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF616161).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        media.releaseDate,
                        style: TextStyle(color: Colors.white, fontSize: 12, fontFamily: AppTheme.primaryFont),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            media.titleZh.isNotEmpty ? media.titleZh : media.titleOriginal,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildRankBadge() {
    if (rank <= 3) {
      return Image.asset(
        'assets/icons/ic_rk$rank.png',
        width: 30, // Adjust size as needed
        height: 30,
      );
    } else {
      return Container(
        width: 24,
        height: 24,
        decoration: const BoxDecoration(
          color: Color(0x80000000), // Semi-transparent black
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(8),
            bottomRight: Radius.circular(8),
          ),
        ),
        child: Center(
          child: Text(
            rank.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      );
    }
  }
}
