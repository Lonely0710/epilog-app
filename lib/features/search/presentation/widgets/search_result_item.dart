import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/domain/entities/media.dart';
import 'package:drama_tracker_flutter/features/search/presentation/widgets/circular_rating.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/presentation/pages/web_browser_page.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../features/collections/domain/repositories/collection_repository.dart';
import '../../../../features/collections/presentation/widgets/collection_category_sheet.dart';
import '../../../../features/detail/presentation/widgets/watch_status_icon.dart';
import '../../../../core/services/media_providers/tmdb_service.dart';

class SearchResultItem extends StatelessWidget {
  final Media result;
  final String searchType;

  const SearchResultItem({
    super.key,
    required this.result,
    this.searchType = 'anime',
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textTheme = Theme.of(context).textTheme;
    return _ScaleButton(
      onTap: () {
        // Determine URL based on source
        String url = result.sourceUrl;
        if (url.isEmpty) {
          if (result.sourceType == 'douban') {
            url = 'https://movie.douban.com/subject/${result.sourceId}';
          } else if (result.sourceType == 'bgm') {
            url = 'https://bangumi.tv/subject/${result.sourceId}';
          } else if (result.sourceType == 'maoyan') {
            url = 'https://m.maoyan.com/movie/${result.sourceId}';
          } else if (result.sourceType == 'tmdb') {
            url =
                'https://www.themoviedb.org/${result.mediaType}/${result.sourceId}';
          }
        }

        context.push(
          '/webview',
          extra: WebBrowserPageArgs.fromSiteType(
            siteType: _mapSourceToSiteType(result.sourceType),
            url: url,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: CachedNetworkImage(
                    imageUrl: result.posterUrl,
                    width: 80,
                    height: 115,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 80,
                      height: 115,
                      color: AppColors.placeholder,
                    ),
                    errorWidget: (context, url, error) => Image.asset(
                      'assets/icons/ic_np_poster.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 12),
                _CollectionStar(media: result),
              ],
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Row: Title + Original Title
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Flexible(
                        child: Text(
                          result.titleZh,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          result.titleOriginal,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Summary
                  if (result.summary.isNotEmpty) ...[
                    Text(
                      result.summary,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                  ] else ...[
                    const SizedBox(height: 6),
                  ],

                  // Year & Duration Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        result.year,
                        style: textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${result.releaseDate}   ${_formatDuration(result)}',
                          style: textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Media Tag - Always show for all types
                      _buildMediaTag(result),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Rating Row with Site Button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Scrollable Ratings
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            children: [
                              // TMDb Rating
                              if (result.ratingImdb > 0) ...[
                                Image.asset(
                                  'assets/icons/ic_tmdb.png',
                                  width: 16,
                                  height: 16,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 4),
                                CircularRating(
                                    rating: result.ratingImdb, size: 28),
                                const SizedBox(width: 12),
                              ],

                              // Maoyan Rating
                              if (result.ratingMaoyan > 0) ...[
                                Image.asset(
                                  'assets/icons/ic_maoyan.png',
                                  width: 18,
                                  height: 18,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 4),
                                CircularRating(
                                    rating: result.ratingMaoyan, size: 28),
                                const SizedBox(width: 12),
                              ],

                              // Douban Rating
                              if (result.ratingDouban > 0) ...[
                                Image.asset(
                                  'assets/icons/ic_douban_green.png',
                                  width: 18,
                                  height: 18,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 4),
                                CircularRating(
                                    rating: result.ratingDouban, size: 28),
                                const SizedBox(width: 12),
                              ],

                              // Bangumi Rating
                              if (result.ratingBangumi > 0) ...[
                                Image.asset(
                                  'assets/icons/ic_bangumi.png',
                                  width: 18,
                                  height: 18,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 4),
                                CircularRating(
                                    rating: result.ratingBangumi, size: 28),
                                const SizedBox(width: 12),
                              ],

                              // N/A if no ratings
                              if (result.ratingImdb <= 0 &&
                                  result.ratingMaoyan <= 0 &&
                                  result.ratingDouban <= 0 &&
                                  result.ratingBangumi <= 0) ...[
                                Image.asset(
                                  _getIconPath(result.sourceType),
                                  width: 18,
                                  height: 18,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'N/A',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Link button moved to below poster
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Staff Information
                  for (final line in _previewInfoLines(result).take(2)) ...[
                    _SearchInfoLine(line: line),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getIconPath(String sourceType) {
    switch (sourceType) {
      case 'douban':
        return 'assets/icons/ic_douban_green.png';
      case 'tmdb':
        return 'assets/icons/ic_tmdb.png';
      case 'bgm':
        return 'assets/icons/ic_bangumi.png';
      case 'maoyan':
        return 'assets/icons/ic_maoyan.png';
      default:
        return 'assets/icons/ic_bangumi.png';
    }
  }

  SiteType _mapSourceToSiteType(String sourceType) {
    if (sourceType == 'douban') return SiteType.douban;
    if (sourceType == 'bgm') return SiteType.bangumi;
    if (sourceType == 'tmdb') return SiteType.tmdb;
    if (sourceType == 'maoyan') return SiteType.maoyan;
    return SiteType.other;
  }

  /// Format duration based on media type
  /// - Movies: Show time in minutes (e.g., "97分钟")
  /// - TV/Anime series: Show episodes (e.g., "12集", "24话")
  String _formatDuration(Media media) {
    final duration = media.duration;
    if (duration.isEmpty || duration == '未知') return '未知';

    // If it's a movie, prefer showing time in minutes
    if (media.mediaType == 'movie') {
      // If duration already has minutes, return as is
      if (duration.contains('分钟') || duration.contains('分')) {
        return duration;
      }
      // If it shows episodes but we know it's a movie, just return duration
      return duration;
    }

    // For TV/Anime, prefer showing episodes
    // Duration already formatted correctly from backend
    return duration;
  }

  /// Build media type tag widget
  /// - ANIME: Pink background for anime series
  /// - MOVIE: Primary color for movies (including anime movies)
  /// - TV: Primary color for TV shows
  Widget _buildMediaTag(Media media) {
    String tagText;
    List<Color> tagGradient;

    // Determine tag text and color based on media type and source
    if (_isAnimeMedia(media)) {
      // Anime series -> ANIME tag with pink background
      tagText = 'ANIME';
      tagGradient = AppColors.gradientAnime;
    } else if (media.mediaType == 'movie') {
      // Movie -> MOVIE tag
      tagText = 'MOVIE';
      tagGradient = const [
        Color(0xFF8EA7FF),
        Color(0xFF4F46E5),
      ];
    } else if (media.mediaType == 'tv') {
      // TV series -> TV tag
      tagText = 'TV';
      tagGradient = const [
        Color(0xFF8EA7FF),
        Color(0xFF4F46E5),
      ];
    } else {
      // Default to source type indicator
      tagText = media.sourceType.toUpperCase();
      tagGradient = AppColors.gradientMovies;
    }

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: tagGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tagText,
        style: const TextStyle(
          color: AppColors.textOnPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          fontFamily: 'LibreBaskerville',
          letterSpacing: 0.6,
          height: 1,
        ),
      ),
    );
  }
}

class SearchGalleryResultItem extends StatelessWidget {
  final Media result;
  final String searchType;

  const SearchGalleryResultItem({
    super.key,
    required this.result,
    this.searchType = 'anime',
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor =
        isDark ? Colors.white.withValues(alpha: 0.72) : AppColors.textSecondary;

    return _ScaleButton(
      onTap: () => _openMedia(context, result),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: result.posterUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: AppColors.placeholder,
                        ),
                        errorWidget: (context, url, error) => Image.asset(
                          'assets/icons/ic_np_poster.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _MediaTag(media: result),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: _CollectionStar(media: result, compact: true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              result.titleZh,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 7),
            _CompactRatingRow(media: result),
            const SizedBox(height: 7),
            Row(
              children: [
                Text(
                  result.year,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatDuration(result),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: secondaryTextColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchInfoLine extends StatelessWidget {
  final _MediaInfoLine line;

  const _SearchInfoLine({required this.line});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(line.icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '${line.label}: ${line.value}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _RatingEntry {
  final String iconPath;
  final double rating;

  const _RatingEntry({
    required this.iconPath,
    required this.rating,
  });
}

class _CompactRatingRow extends StatelessWidget {
  final Media media;

  const _CompactRatingRow({required this.media});

  List<_RatingEntry> get _entries {
    return [
      if (media.ratingImdb > 0)
        _RatingEntry(
            iconPath: 'assets/icons/ic_tmdb.png', rating: media.ratingImdb),
      if (media.ratingMaoyan > 0)
        _RatingEntry(
            iconPath: 'assets/icons/ic_maoyan.png', rating: media.ratingMaoyan),
      if (media.ratingDouban > 0)
        _RatingEntry(
            iconPath: 'assets/icons/ic_douban_green.png',
            rating: media.ratingDouban),
      if (media.ratingBangumi > 0)
        _RatingEntry(
            iconPath: 'assets/icons/ic_bangumi.png',
            rating: media.ratingBangumi),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;

    if (entries.isEmpty) {
      return Row(
        children: [
          Image.asset(
            _getIconPath(media.sourceType),
            width: 16,
            height: 16,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 4),
          const Text(
            'N/A',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        for (final entry in entries.take(2)) ...[
          _CompactRating(entry: entry),
          const SizedBox(width: 8),
        ],
        _RatingOverflowButton(media: media, entries: entries),
      ],
    );
  }
}

class _CompactRating extends StatelessWidget {
  final _RatingEntry entry;

  const _CompactRating({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          entry.iconPath,
          width: 17,
          height: 17,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 4),
        CircularRating(rating: entry.rating, size: 26),
      ],
    );
  }
}

class _RatingOverflowButton extends StatelessWidget {
  final Media media;
  final List<_RatingEntry> entries;

  const _RatingOverflowButton({
    required this.media,
    required this.entries,
  });

  void _showAllRatings(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final topLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final anchor =
        topLeft + Offset(renderBox.size.width / 2, renderBox.size.height);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => _RatingInfoBubbleOverlay(
        media: media,
        entries: entries,
        anchor: anchor,
        overlaySize: overlay.size,
        onDismiss: () => overlayEntry.remove(),
      ),
    );
    Overlay.of(context).insert(overlayEntry);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fillColor = isDark
        ? Colors.white.withValues(alpha: 0.10)
        : AppColors.ratingCircleBg;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.white.withValues(alpha: 0.10);
    final dotColor = isDark
        ? Colors.white.withValues(alpha: 0.88)
        : Colors.white.withValues(alpha: 0.94);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showAllRatings(context),
      child: SizedBox(
        width: 30,
        height: 30,
        child: Center(
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fillColor,
              shape: BoxShape.circle,
              border: Border.all(color: borderColor, width: 1),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.24),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Text(
              '...',
              style: TextStyle(
                color: dotColor,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                height: 0.8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RatingInfoBubbleOverlay extends StatelessWidget {
  final Media media;
  final List<_RatingEntry> entries;
  final Offset anchor;
  final Size overlaySize;
  final VoidCallback onDismiss;

  const _RatingInfoBubbleOverlay({
    required this.media,
    required this.entries,
    required this.anchor,
    required this.overlaySize,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleWidth = (overlaySize.width - 32).clamp(260.0, 318.0).toDouble();
    const tailHeight = 12.0;
    const bubbleRadius = 22.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    final secondaryColor = isDark
        ? Colors.white.withValues(alpha: 0.82)
        : AppColors.textPrimary.withValues(alpha: 0.78);
    final left = (anchor.dx - bubbleWidth / 2)
        .clamp(12.0, overlaySize.width - bubbleWidth - 12.0);
    final tailCenterX = (anchor.dx - left).clamp(24.0, bubbleWidth - 24.0);
    final maxBubbleHeight =
        (overlaySize.height * 0.42).clamp(180.0, 340.0).toDouble();
    const screenPadding = 12.0;
    final spaceBelow = overlaySize.height - anchor.dy - screenPadding;
    final spaceAbove = anchor.dy - screenPadding;
    final showAbove = spaceBelow < maxBubbleHeight + tailHeight + 12 &&
        spaceAbove > spaceBelow;
    final top = showAbove
        ? (anchor.dy - maxBubbleHeight - tailHeight)
            .clamp(screenPadding,
                overlaySize.height - maxBubbleHeight - screenPadding)
            .toDouble()
        : (anchor.dy + tailHeight)
            .clamp(screenPadding,
                overlaySize.height - maxBubbleHeight - screenPadding)
            .toDouble();
    final tailTop = showAbove ? maxBubbleHeight - 1 : -tailHeight + 1;

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onDismiss,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: bubbleWidth,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(bubbleRadius),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: maxBubbleHeight,
                          ),
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                          decoration: BoxDecoration(
                            color: Color.alphaBlend(
                              AppTheme.primary.withValues(
                                alpha: isDark ? 0.08 : 0.025,
                              ),
                              (isDark ? const Color(0xFF1C1C1E) : Colors.white)
                                  .withValues(alpha: isDark ? 0.72 : 0.74),
                            ),
                            borderRadius: BorderRadius.circular(bubbleRadius),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.18)
                                  : Colors.white.withValues(alpha: 0.76),
                              width: 1.1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.28 : 0.12,
                                ),
                                blurRadius: 26,
                                spreadRadius: -10,
                                offset: const Offset(0, 14),
                              ),
                            ],
                          ),
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _BubbleTitleBlock(
                                  media: media,
                                  textColor: textColor,
                                  secondaryColor: secondaryColor,
                                ),
                                const SizedBox(height: 14),
                                Center(
                                  child: Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 12,
                                    runSpacing: 8,
                                    children: [
                                      for (final entry in entries)
                                        _BubbleRating(entry: entry),
                                    ],
                                  ),
                                ),
                                _BubbleInfoSection(
                                  media: media,
                                  textColor: secondaryColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: tailCenterX - 12,
                      top: tailTop,
                      child: CustomPaint(
                        size: const Size(24, tailHeight),
                        painter: _BubbleTailPainter(
                          color: isDark
                              ? const Color(0xFF1C1C1E).withValues(alpha: 0.72)
                              : const Color(0xFFF7F8FA).withValues(alpha: 0.86),
                          pointsUp: !showAbove,
                        ),
                      ),
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

class _BubbleRating extends StatelessWidget {
  final _RatingEntry entry;

  const _BubbleRating({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(entry.iconPath, width: 24, height: 24, fit: BoxFit.contain),
        const SizedBox(width: 7),
        CircularRating(rating: entry.rating, size: 36),
      ],
    );
  }
}

class _BubbleInfoSection extends StatelessWidget {
  final Media media;
  final Color textColor;

  const _BubbleInfoSection({
    required this.media,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return _BubbleInfoLines(
      lines: _bubbleInfoLines(media),
      textColor: textColor,
    );
  }
}

class _BubbleInfoLines extends StatelessWidget {
  final List<_MediaInfoLine> lines;
  final Color textColor;

  const _BubbleInfoLines({
    required this.lines,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 14),
        for (final line in lines) ...[
          _BubbleInfoLine(
            icon: line.icon,
            label: line.label,
            value: line.value,
            textColor: textColor,
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _BubbleTitleBlock extends StatelessWidget {
  final Media media;
  final Color textColor;
  final Color secondaryColor;

  const _BubbleTitleBlock({
    required this.media,
    required this.textColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final originalName = media.titleOriginal.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          media.titleZh,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor,
            fontFamily: 'JingHuaSC',
            fontSize: 20,
            fontWeight: FontWeight.w800,
            height: 1.08,
            letterSpacing: 0,
          ),
        ),
        if (originalName.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            originalName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: _originalNameStyle(originalName, secondaryColor),
          ),
        ],
      ],
    );
  }

  TextStyle _originalNameStyle(String value, Color color) {
    final hasChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(value);
    final hasEnglish = RegExp(r'[A-Za-z]').hasMatch(value);
    final hasJapanese = RegExp(r'[\u3040-\u30ff\u31f0-\u31ff]').hasMatch(value);
    final hasJapanesePunctuation = RegExp(r'[・ー「」『』、。]').hasMatch(value);
    final isEnglishOnly = hasEnglish &&
        !RegExp(r'[\u3040-\u30ff\u31f0-\u31ff\u4e00-\u9fff]').hasMatch(value);
    final useJapaneseFont =
        hasJapanese || hasJapanesePunctuation || (hasChinese && hasEnglish);

    if (useJapaneseFont) {
      return TextStyle(
        color: color.withValues(alpha: 0.84),
        fontFamily: 'AOTFStdHeavy',
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 1.18,
        letterSpacing: 0,
      );
    }

    if (isEnglishOnly) {
      return GoogleFonts.ebGaramond(
        color: color.withValues(alpha: 0.86),
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.08,
        letterSpacing: 0,
      );
    }

    return TextStyle(
      color: color.withValues(alpha: 0.82),
      fontSize: 13,
      fontWeight: FontWeight.w600,
      height: 1.18,
      letterSpacing: 0,
    );
  }
}

class _BubbleInfoLine extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textColor;

  const _BubbleInfoLine({
    required this.icon,
    required this.label,
    required this.value,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 15, color: textColor),
        ),
        const SizedBox(width: 6),
        SizedBox(
          width: 34,
          child: Text(
            '$label:',
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color color;
  final bool pointsUp;

  const _BubbleTailPainter({
    required this.color,
    this.pointsUp = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    if (pointsUp) {
      path
        ..moveTo(0, size.height)
        ..lineTo(size.width / 2, 0)
        ..lineTo(size.width, size.height)
        ..close();
    } else {
      path
        ..moveTo(0, 0)
        ..lineTo(size.width / 2, size.height)
        ..lineTo(size.width, 0)
        ..close();
    }

    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) {
    return color != oldDelegate.color || pointsUp != oldDelegate.pointsUp;
  }
}

void _openMedia(BuildContext context, Media result) {
  String url = result.sourceUrl;
  if (url.isEmpty) {
    if (result.sourceType == 'douban') {
      url = 'https://movie.douban.com/subject/${result.sourceId}';
    } else if (result.sourceType == 'bgm') {
      url = 'https://bangumi.tv/subject/${result.sourceId}';
    } else if (result.sourceType == 'maoyan') {
      url = 'https://m.maoyan.com/movie/${result.sourceId}';
    } else if (result.sourceType == 'tmdb') {
      url = 'https://www.themoviedb.org/${result.mediaType}/${result.sourceId}';
    }
  }

  context.push(
    '/webview',
    extra: WebBrowserPageArgs.fromSiteType(
      siteType: _mapSourceToSiteType(result.sourceType),
      url: url,
    ),
  );
}

String _getIconPath(String sourceType) {
  switch (sourceType) {
    case 'douban':
      return 'assets/icons/ic_douban_green.png';
    case 'tmdb':
      return 'assets/icons/ic_tmdb.png';
    case 'bgm':
      return 'assets/icons/ic_bangumi.png';
    case 'maoyan':
      return 'assets/icons/ic_maoyan.png';
    default:
      return 'assets/icons/ic_bangumi.png';
  }
}

SiteType _mapSourceToSiteType(String sourceType) {
  if (sourceType == 'douban') return SiteType.douban;
  if (sourceType == 'bgm') return SiteType.bangumi;
  if (sourceType == 'tmdb') return SiteType.tmdb;
  if (sourceType == 'maoyan') return SiteType.maoyan;
  return SiteType.other;
}

String _formatDuration(Media media) {
  final duration = media.duration;
  if (duration.isEmpty || duration == '未知') return '未知';

  if (media.mediaType == 'movie') {
    if (duration.contains('分钟') || duration.contains('分')) {
      return duration;
    }
    return duration;
  }

  return duration;
}

bool _isAnimeMedia(Media media) {
  return media.mediaType == 'anime' || media.sourceType == 'bgm';
}

class _MediaInfoLine {
  final IconData icon;
  final String label;
  final String value;

  const _MediaInfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });
}

List<_MediaInfoLine> _animeInfoLines(Media media) {
  return [
    if (_staffRole(media.staff, '原作').isNotEmpty)
      _MediaInfoLine(
        icon: Icons.menu_book_outlined,
        label: '原作',
        value: _staffRole(media.staff, '原作'),
      ),
    if (media.directors.isNotEmpty)
      _MediaInfoLine(
        icon: Icons.videocam_outlined,
        label: '导演',
        value: _cleanPeopleText(media.directors.join(' / ')),
      ),
    if (_staffRole(media.staff, '脚本').isNotEmpty)
      _MediaInfoLine(
        icon: Icons.edit_note_outlined,
        label: '脚本',
        value: _staffRole(media.staff, '脚本'),
      ),
    if (media.actors.isNotEmpty)
      _MediaInfoLine(
        icon: Icons.mic_none_outlined,
        label: '声优',
        value: _cleanPeopleText(media.actors.join(' / ')),
      ),
  ];
}

List<_MediaInfoLine> _previewInfoLines(Media media) {
  return _bubbleInfoLines(media);
}

List<_MediaInfoLine> _bubbleInfoLines(Media media) {
  if (_isAnimeMedia(media)) return _animeInfoLines(media);
  return [
    if (media.directors.isNotEmpty || media.staff.isNotEmpty)
      _MediaInfoLine(
        icon: Icons.videocam_outlined,
        label: '导演',
        value: media.directors.isNotEmpty
            ? _cleanPeopleText(media.directors.join(' / '))
            : media.staff,
      ),
    if (media.actors.isNotEmpty)
      _MediaInfoLine(
        icon: Icons.face_outlined,
        label: '演员',
        value: _cleanPeopleText(media.actors.join(' / ')),
      ),
  ];
}

String _staffRole(String staff, String role) {
  if (staff.trim().isEmpty) return '';
  final escapedRole = RegExp.escape(role);
  const knownRoles = ['脚本', '人物设定', '音乐', '动画制作', '原作'];
  final nextRole = knownRoles.map(RegExp.escape).join('|');
  final pattern =
      '(?:^|\\s/\\s)\\s*$escapedRole[:：]\\s*(.+?)(?=\\s/\\s(?:$nextRole)[:：]|'
      r'$)';
  final match = RegExp(pattern).firstMatch(staff);
  return _cleanPeopleText(match?.group(1)?.trim() ?? '');
}

String _cleanPeopleText(String value) {
  return value
      .replaceAll(RegExp(r'\b(导演|原作|脚本|人物设定|音乐|动画制作)[:：]\s*'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _MediaTag extends StatelessWidget {
  final Media media;

  const _MediaTag({required this.media});

  @override
  Widget build(BuildContext context) {
    String tagText;
    List<Color> tagGradient;

    if (_isAnimeMedia(media)) {
      tagText = 'ANIME';
      tagGradient = AppColors.gradientAnime;
    } else if (media.mediaType == 'movie') {
      tagText = 'MOVIE';
      tagGradient = const [
        Color(0xFF8EA7FF),
        Color(0xFF4F46E5),
      ];
    } else if (media.mediaType == 'tv') {
      tagText = 'TV';
      tagGradient = const [
        Color(0xFF8EA7FF),
        Color(0xFF4F46E5),
      ];
    } else {
      tagText = media.sourceType.toUpperCase();
      tagGradient = AppColors.gradientMovies;
    }

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: tagGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        tagText,
        style: const TextStyle(
          color: AppColors.textOnPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          fontFamily: 'LibreBaskerville',
          letterSpacing: 0.6,
          height: 1,
        ),
      ),
    );
  }
}

class _CollectionStar extends StatefulWidget {
  final Media media;
  final bool compact;

  const _CollectionStar({
    required this.media,
    this.compact = false,
  });

  @override
  State<_CollectionStar> createState() => _CollectionStarState();
}

class _CollectionStarState extends State<_CollectionStar> {
  static final Map<String, CollectionStatusSnapshot?> _statusCache = {};

  bool _isCollected = false;
  String? _collectionId;
  String _watchStatus = 'wish';
  final _repo = CollectionRepository();
  late final StreamSubscription<void> _collectionSubscription;

  String get _cacheKey =>
      '${widget.media.sourceType}:${widget.media.sourceId}:${widget.media.mediaType}';

  @override
  void initState() {
    super.initState();
    _hydrateFromMediaOrCache();
    _collectionSubscription = _repo.onCollectionChanged.listen((_) {
      _checkStatus();
    });
    _checkStatus();
  }

  @override
  void didUpdateWidget(covariant _CollectionStar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.media.sourceId != widget.media.sourceId ||
        oldWidget.media.sourceType != widget.media.sourceType ||
        oldWidget.media.mediaType != widget.media.mediaType) {
      _hydrateFromMediaOrCache();
      _checkStatus();
    }
  }

  @override
  void dispose() {
    _collectionSubscription.cancel();
    super.dispose();
  }

  void _hydrateFromMediaOrCache() {
    final cached = _statusCache[_cacheKey];
    if (cached != null) {
      _isCollected = true;
      _collectionId = cached.collectionId;
      _watchStatus = cached.status;
      return;
    }

    _isCollected =
        widget.media.isCollected || widget.media.collectionId.isNotEmpty;
    _collectionId =
        widget.media.collectionId.isEmpty ? null : widget.media.collectionId;
    _watchStatus = widget.media.watchingStatus ?? 'wish';
  }

  Future<void> _checkStatus() async {
    final requestedKey = _cacheKey;
    try {
      final info = await _repo.checkCollectionInfo(
          widget.media.sourceId, widget.media.sourceType);
      if (!mounted || requestedKey != _cacheKey) return;

      _statusCache[requestedKey] = info;

      setState(() {
        _isCollected = info != null;
        _collectionId = info?.collectionId;
        _watchStatus = info?.status ?? 'wish';
      });
    } catch (e) {
      // Ignore errors for status check
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor =
        _isCollected ? watchStatusColor(_watchStatus) : AppTheme.primary;
    final statusLabel =
        _isCollected ? '已${watchStatusLabel(_watchStatus)}' : '想看';
    final statusIcon = _isCollected
        ? watchStatusIconData(_watchStatus)
        : watchStatusIconData('wish', filled: false);

    if (widget.compact) {
      return _buildCompactButton(statusColor, statusIcon);
    }

    // 使用 RawGestureDetector 配合 EagerGestureRecognizer 立即赢得手势竞技场
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        _EagerTapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_EagerTapGestureRecognizer>(
          () => _EagerTapGestureRecognizer(),
          (_EagerTapGestureRecognizer instance) {
            instance.onTap = _handleTap;
          },
        ),
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 5),
        decoration: BoxDecoration(
          color: _isCollected
              ? Colors.transparent
              : AppTheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: _isCollected
                ? statusColor
                : AppTheme.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: null, // Remove shadow for cleaner outline look
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              statusLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: statusColor,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              statusIcon,
              color: statusColor,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactButton(Color statusColor, IconData statusIcon) {
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        _EagerTapGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<_EagerTapGestureRecognizer>(
          () => _EagerTapGestureRecognizer(),
          (_EagerTapGestureRecognizer instance) {
            instance.onTap = _handleTap;
          },
        ),
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF223142).withValues(alpha: 0.88)
              : Colors.white.withValues(alpha: 0.62),
          shape: BoxShape.circle,
          border: Border.all(
            color: _isCollected
                ? statusColor
                : AppTheme.primary.withValues(alpha: 0.65),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          statusIcon,
          color: statusColor,
          size: 20,
        ),
      ),
    );
  }

  Future<void> _handleTap() async {
    HapticFeedback.mediumImpact(); // Tactile feedback
    if (_isCollected) {
      // Toggle Remove
      if (_collectionId != null) {
        // Optimistic UI: Update state immediately
        final previousId = _collectionId;
        final previousStatus = _watchStatus;
        setState(() {
          _isCollected = false;
          _collectionId = null;
          _watchStatus = 'wish';
        });
        _statusCache[_cacheKey] = null;

        try {
          await _repo.removeFromCollection(previousId!);
          if (mounted) {
            AppSnackBar.showInfo(context, '已从收藏中移除');
          }
        } catch (e) {
          // Revert on failure
          if (mounted) {
            setState(() {
              _isCollected = true; // Revert to collected
              _collectionId = previousId;
              _watchStatus = previousStatus;
            });
            _statusCache[_cacheKey] = CollectionStatusSnapshot(
              collectionId: previousId!,
              status: previousStatus,
            );
            AppSnackBar.showError(context, message: '移除失败: $e');
          }
        }
      }
      return;
    }

    showCollectionCategorySheet(
      context: context,
      onSelected: (action) {
        _addToCollection(
          action.mediaType,
          action.successLabel,
          action.iconPath,
        );
      },
    );
  }

  Future<void> _addToCollection(
      String mediaType, String categoryLabel, String iconPath) async {
    // Optimistic UI: Update state immediately
    setState(() {
      _isCollected = true;
      _watchStatus = 'wish';
    });
    _statusCache[_cacheKey] = null;

    // Show success feedback immediately (Optional: could wait for real success, but this feels faster)
    AppSnackBar.show(
      context,
      type: SnackBarType.success,
      message: '已加入$categoryLabel想看',
      customIcon: SvgPicture.asset(
        iconPath,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(AppTheme.primary, BlendMode.srcIn),
      ),
      customColor: AppTheme.primary,
    );

    try {
      // Determine preferred source type based on collection category:
      // - movie/tv: prefer TMDB as source
      // - anime: prefer Bangumi (bgm) as source
      String preferredSourceType;
      String preferredSourceId;
      String preferredSourceUrl;

      if (mediaType == 'anime') {
        if (widget.media.sourceType == 'bgm') {
          preferredSourceType = 'bgm';
          preferredSourceId = widget.media.sourceId;
          preferredSourceUrl = widget.media.sourceUrl;
        } else {
          preferredSourceType = widget.media.sourceType;
          preferredSourceId = widget.media.sourceId;
          preferredSourceUrl = widget.media.sourceUrl;
        }
      } else {
        if (widget.media.sourceType == 'tmdb') {
          preferredSourceType = 'tmdb';
          preferredSourceId = widget.media.sourceId;
          preferredSourceUrl = widget.media.sourceUrl;
        } else {
          preferredSourceType = widget.media.sourceType;
          preferredSourceId = widget.media.sourceId;
          preferredSourceUrl = widget.media.sourceUrl;
        }
      }

      // Modify media with preferred source type
      Media modifiedMedia = widget.media.copyWith(
        mediaType: mediaType,
        sourceType: preferredSourceType,
        sourceId: preferredSourceId,
        sourceUrl: preferredSourceUrl,
      );

      // For TMDb items (movie/tv), fetch fresh details to get complete data including number_of_episodes
      if (preferredSourceType == 'tmdb' &&
          (mediaType == 'movie' || mediaType == 'tv')) {
        try {
          final fullMedia = await TmdbService().getMediaDetail(
            widget.media.sourceId,
            mediaType,
          );
          if (fullMedia != null) {
            // Merge the fresh data with our modified media type settings
            modifiedMedia = fullMedia.copyWith(
              mediaType: mediaType,
              sourceType: preferredSourceType,
              sourceId: preferredSourceId,
              sourceUrl: preferredSourceUrl,
            );
          }
        } catch (e) {
          // If detail fetch fails, continue with original data
          debugPrint('Failed to fetch TMDb details: $e');
        }
      }

      final newId = await _repo.addToCollection(modifiedMedia, status: 'wish');
      if (mounted) {
        setState(() {
          _collectionId = newId;
        });
      }
      _statusCache[_cacheKey] = CollectionStatusSnapshot(
        collectionId: newId,
        status: 'wish',
      );
    } catch (e) {
      if (mounted) {
        // Revert State
        setState(() {
          _isCollected = false;
          _collectionId = null;
          _watchStatus = 'wish';
        });
        _statusCache[_cacheKey] = null;
        AppSnackBar.showError(context, message: '添加失败: $e');
      }
    }
  }
}

class _ScaleButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _ScaleButton({required this.onTap, required this.child});

  @override
  State<_ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<_ScaleButton> {
  bool _isPressed = false;

  @override
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedScale(
      scale: _isPressed ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeInOut,
      child: GestureDetector(
        // 使用 deferToChild 让子组件优先处理手势
        behavior: HitTestBehavior.deferToChild,
        onTapDown: (_) => setState(() => _isPressed = true),
        onTap: () {
          setState(() => _isPressed = false);
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: Stack(
          children: [
            widget.child,
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  decoration: BoxDecoration(
                    color: _isPressed
                        ? (isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.05))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EagerTapGestureRecognizer extends TapGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}
