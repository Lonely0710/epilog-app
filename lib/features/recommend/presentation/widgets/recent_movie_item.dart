import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../../core/presentation/pages/web_browser_page.dart';
import '../../../settings/presentation/widgets/settings_user_info.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = Theme.of(context).textTheme.bodyMedium?.color ??
        AppColors.textSecondary;
    final originalTitleColor = secondaryTextColor.withValues(
      alpha: isDark ? 0.62 : 0.72,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
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
          padding: const EdgeInsets.all(10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Poster
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 100,
                  height: 155,
                  child: Stack(
                    children: [
                      CachedNetworkImage(
                        imageUrl: movie.posterUrl,
                        fit: BoxFit.cover,
                        width: 100,
                        height: 155,
                        placeholder: (context, url) => Container(
                          color: AppColors.surfaceVariant,
                          child: Center(
                            child: Icon(Icons.image,
                                color: AppColors.textTertiary),
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
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Color(0xFFFFD54F),
                                  Color(0xFFFFA726),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(8),
                              ),
                            ),
                            child: Text(
                              movie.rating.toString(),
                              style: TextStyle(
                                  color: AppColors.textOnPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold),
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
                              ),
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
                    if (movie.titleOriginal.isNotEmpty &&
                        movie.titleOriginal != movie.titleZh)
                      Text(
                        movie.titleOriginal,
                        style: TextStyle(
                          fontSize: 12,
                          color: originalTitleColor,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                    const SizedBox(height: 6),

                    // Duration
                    if (movie.duration.isNotEmpty && movie.duration != '0分钟')
                      _DurationHighlight(duration: movie.duration),

                    const SizedBox(height: 6),

                    // Directors
                    if (movie.directors.isNotEmpty) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.videocam_outlined,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              movie.directors.join(' / '),
                              style: TextStyle(
                                fontSize: 13,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],

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
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                    const SizedBox(height: 6),

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

class _DurationHighlight extends StatelessWidget {
  final String duration;

  const _DurationHighlight({required this.duration});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlightColor = isDark
        ? Colors.amber.withValues(alpha: 0.5)
        : Theme.of(context).primaryColor.withValues(alpha: 0.22);
    final textColor =
        Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Baseline(
          baseline: 13,
          baselineType: TextBaseline.alphabetic,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 1,
                right: -5,
                bottom: 1,
                height: 9,
                child: CustomPaint(
                  painter: HighlighterPainter(color: highlightColor),
                ),
              ),
              Text(
                duration,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
