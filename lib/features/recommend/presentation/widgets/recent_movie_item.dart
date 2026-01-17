import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../../core/presentation/pages/web_browser_page.dart';

class RecentMovieItem extends StatelessWidget {
  final Media movie;
  final VoidCallback? onTap;

  const RecentMovieItem({
    super.key,
    required this.movie,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          if (onTap != null) {
            onTap!();
          } else {
            // Default navigation if no callback provided
            _navigateToWeb(context);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 100,
                  height: 140,
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: movie.posterUrl,
                        fit: BoxFit.cover,
                        width: 100,
                        height: 140,
                        placeholder: (context, url) => Container(
                          color: AppColors.surfaceVariant,
                          child: Center(
                            child: Icon(Icons.image, color: AppColors.textTertiary),
                          ),
                        ),
                        errorWidget: (context, url, error) => Image.asset(
                          'assets/icons/ic_np_poster.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Rating Badge
                      if (movie.rating > 0)
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                              ),
                            ),
                            child: Text(
                              movie.rating.toString(),
                              style: TextStyle(
                                  color: AppColors.textOnPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: AppTheme.primaryFont),
                            ),
                          ),
                        ),

                      // Release Date Bar at bottom of poster
                      if (movie.releaseDate.isNotEmpty)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            color: AppColors.shadowDark.withValues(alpha: 0.7),
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              movie.releaseDate,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: AppTheme.primaryFont),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      movie.titleZh,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (movie.titleOriginal.isNotEmpty && movie.titleOriginal != movie.titleZh)
                      Text(
                        movie.titleOriginal,
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontWeight: FontWeight.bold,
                            fontFamily: AppTheme.primaryFont),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 8),

                    // Genres & Duration
                    Row(
                      children: [
                        if (movie.genres.isNotEmpty)
                          ...movie.genres.take(3).map((genre) => Padding(
                                padding: const EdgeInsets.only(right: 4),
                                child: Text(
                                  genre,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )),
                        if (movie.duration.isNotEmpty && movie.duration != '0分钟')
                          Text(
                            movie.duration,
                            style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).textTheme.bodySmall?.color,
                                fontWeight: FontWeight.bold,
                                fontFamily: AppTheme.primaryFont),
                          ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Staff / Actors
                    if (movie.actors.isNotEmpty)
                      Row(
                        children: [
                          const Icon(
                            Icons.face_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              movie.actors.join(' / '),
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 8),

                    // Summary
                    if (movie.summary.isNotEmpty)
                      Text(
                        movie.summary,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToWeb(BuildContext context) {
    String url = movie.sourceUrl;
    // Fallback logic if needed, but Media usually has sourceUrl
    if (url.isEmpty) {
      url = 'https://m.maoyan.com/movie/${movie.sourceId}';
    }

    context.push(
      '/webview',
      extra: WebBrowserPageArgs.fromSiteType(
        siteType: SiteType.maoyan, // Assuming Maoyan for RecentMovies
        url: url,
      ),
    );
  }
}
