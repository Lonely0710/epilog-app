import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/domain/entities/media.dart';
import 'package:drama_tracker_flutter/features/search/presentation/widgets/circular_rating.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/presentation/pages/web_browser_page.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../features/collections/data/repositories/collection_repository_impl.dart';

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
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    return _ScaleButton(
      onTap: () {
        // Determine URL based on source
        String url = result.sourceUrl;
        if (url.isEmpty) {
          if (result.sourceType == 'douban') {
            url = 'https://movie.douban.com/subject/${result.sourceId}';
          } else if (result.sourceType == 'bgm') {
            url = 'https://chii.in/subject/${result.sourceId}';
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          fontFamily: AppTheme.primaryFont,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${result.releaseDate}   ${_formatDuration(result)}',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w300,
                            fontFamily: AppTheme.primaryFont,
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
                                CircularRating(rating: result.ratingImdb, size: 28),
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
                                CircularRating(rating: result.ratingMaoyan, size: 28),
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
                                CircularRating(rating: result.ratingDouban, size: 28),
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
                                CircularRating(rating: result.ratingBangumi, size: 28),
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
                  if (result.mediaType == 'anime') ...[
                    // Anime Style (Single Line)
                    Row(
                      children: [
                        const Icon(Icons.face_outlined, size: 16, color: Color(0xFF6B7280)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            result.staff.isNotEmpty ? result.staff : '暂无制作信息',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  ] else ...[
                    // Movie/TV Style (Two Lines)
                    // Directors
                    Row(
                      children: [
                        const Icon(Icons.videocam_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            result.directors.isNotEmpty
                                ? result.directors.join(' / ')
                                : (result.staff.isNotEmpty ? result.staff : '暂无导演信息'),
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // If we are in the else block and there are no actors, showing the star here might be good?
                        // But we plan to show actors line below.
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Actors
                    Row(
                      children: [
                        const Icon(Icons.face_outlined, size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            result.actors.isNotEmpty ? result.actors.join(' / ') : '暂无演员信息',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
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
    Color tagColor;

    // Determine tag text and color based on media type and source
    if (media.mediaType == 'movie') {
      // Movie (including anime movies) -> MOVIE tag
      tagText = 'MOVIE';
      tagColor = AppTheme.primary;
    } else if (media.mediaType == 'tv') {
      // TV series -> TV tag
      tagText = 'TV';
      tagColor = AppTheme.primary;
    } else if (media.mediaType == 'anime' || media.sourceType == 'bgm') {
      // Anime series -> ANIME tag with pink background
      tagText = 'ANIME';
      tagColor = const Color.fromARGB(255, 227, 70, 122); // Pink color for anime
    } else {
      // Default to source type indicator
      tagText = media.sourceType.toUpperCase();
      tagColor = AppTheme.primary;
    }

    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tagColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        tagText,
        style: const TextStyle(
          color: AppColors.textOnPrimary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _CollectionStar extends StatefulWidget {
  final Media media;
  const _CollectionStar({required this.media});

  @override
  State<_CollectionStar> createState() => _CollectionStarState();
}

class _CollectionStarState extends State<_CollectionStar> {
  bool _isCollected = false;
  String? _collectionId;
  final _repo = CollectionRepositoryImpl();

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    try {
      final id = await _repo.checkCollectionStatus(widget.media.sourceId, widget.media.sourceType);
      if (mounted && id != null) {
        setState(() {
          _isCollected = true;
          _collectionId = id;
        });
      }
    } catch (e) {
      // Ignore errors for status check
    }
  }

  @override
  Widget build(BuildContext context) {
    // 使用 RawGestureDetector 配合 EagerGestureRecognizer 立即赢得手势竞技场
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        _EagerTapGestureRecognizer: GestureRecognizerFactoryWithHandlers<_EagerTapGestureRecognizer>(
          () => _EagerTapGestureRecognizer(),
          (_EagerTapGestureRecognizer instance) {
            instance.onTap = _handleTap;
          },
        ),
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        width: 86,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: _isCollected ? AppTheme.primary : AppTheme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: _isCollected ? Colors.transparent : AppTheme.primary.withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: _isCollected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isCollected ? '已想看' : '想看',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _isCollected ? Colors.white : AppTheme.primary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              _isCollected ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
              color: _isCollected ? Colors.white : AppTheme.primary,
              size: 18,
            ),
          ],
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
        setState(() {
          _isCollected = false;
          _collectionId = null;
        });

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
            });
            AppSnackBar.showError(context, message: '移除失败: $e');
          }
        }
      }
      return;
    }

    // Show Bottom Sheet for Add
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                '加入资料库',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            _buildOption(
              context,
              iconWidget: Icon(Icons.movie_creation_outlined, color: AppTheme.primary, size: 20),
              label: 'Movie Library',
              onTap: () => _addToCollection('movie', 'Movie Library', 'assets/icons/ic_popcorn.png'),
            ),
            _buildOption(
              context,
              iconWidget: Icon(Icons.tv, color: AppTheme.primary, size: 20),
              label: 'TV Show',
              onTap: () => _addToCollection('tv', 'TV Show', 'assets/icons/ic_popcorn.png'),
            ),
            _buildOption(
              context,
              iconWidget: Image.asset('assets/icons/ic_bilibili.png', width: 20, height: 20),
              label: 'Anime Wall',
              onTap: () => _addToCollection('anime', 'Anime Wall', 'assets/icons/ic_bilibili.png'),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required Widget iconWidget,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: iconWidget,
      ),
      title: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textTertiary),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Future<void> _addToCollection(String mediaType, String categoryLabel, String iconPath) async {
    // Optimistic UI: Update state immediately
    setState(() {
      _isCollected = true;
    });

    // Show success feedback immediately (Optional: could wait for real success, but this feels faster)
    AppSnackBar.show(
      context,
      type: SnackBarType.success,
      message: '已加入$categoryLabel想看',
      customIcon: Image.asset(
        iconPath,
        width: 24,
        height: 24,
        fit: BoxFit.contain,
      ),
      customColor: AppTheme.primary,
    );

    try {
      // modify media type
      final modifiedMedia = widget.media.copyWith(
        mediaType: mediaType,
      );

      final newId = await _repo.addToCollection(modifiedMedia, status: 'wish');
      if (mounted) {
        setState(() {
          _collectionId = newId;
        });
      }
    } catch (e) {
      if (mounted) {
        // Revert State
        setState(() {
          _isCollected = false;
          _collectionId = null;
        });
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
                        ? (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05))
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
