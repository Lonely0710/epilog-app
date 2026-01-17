import 'dart:developer';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../collections/data/repositories/collection_repository_impl.dart';
import '../widgets/rating_display_widget.dart';
import '../widgets/watch_status_bottom_sheet.dart';
import '../widgets/character_list_widget.dart';

/// Media detail page displaying full information about a movie/TV show/anime.
class MediaDetailPage extends StatefulWidget {
  final Media media;

  const MediaDetailPage({super.key, required this.media});

  @override
  State<MediaDetailPage> createState() => _MediaDetailPageState();
}

class _MediaDetailPageState extends State<MediaDetailPage> {
  final _repository = CollectionRepositoryImpl();
  late bool _isCollected;
  late String _watchStatus;
  late String _collectionId;

  @override
  void initState() {
    super.initState();
    _isCollected = widget.media.isCollected;
    _watchStatus = widget.media.watchingStatus ?? 'wish';
    _collectionId = widget.media.collectionId;
  }

  Future<void> _updateWatchStatus(String status) async {
    // Optimistic UI: Update state immediately
    final previousStatus = _watchStatus;
    final previousIsCollected = _isCollected;

    setState(() {
      _watchStatus = status;
      _isCollected = true;
    });

    // Show feedback immediately
    if (mounted) {
      String statusText = '想看';
      switch (status) {
        case 'watching':
          statusText = '在看';
          break;
        case 'watched':
          statusText = '看过';
          break;
        case 'on_hold':
          statusText = '搁置';
          break;
      }

      AppSnackBar.show(
        context,
        type: SnackBarType.success,
        message: '已标记为$statusText',
        customIcon: Icon(Icons.bookmark, color: AppColors.starActive, size: 24),
        customColor: AppColors.starActive,
      );
    }

    try {
      if (_collectionId.isNotEmpty) {
        await _repository.updateWatchStatus(_collectionId, status);
      } else {
        // If not collected yet, add it
        final id = await _repository.addToCollection(widget.media, status: status);
        if (mounted) {
          setState(() {
            _collectionId = id;
          });
        }
      }
    } catch (e) {
      log('Error updating status: $e');
      if (mounted) {
        // Revert State
        setState(() {
          _watchStatus = previousStatus;
          _isCollected = previousIsCollected;
        });
        AppSnackBar.showError(context, message: '更新失败: $e');
      }
    }
  }

  void _showWatchStatusSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WatchStatusBottomSheet(
        media: widget.media,
        currentStatus: _watchStatus,
        onStatusSelected: (status) {
          _updateWatchStatus(status);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showCategorySheet() {
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
              onTap: () => _addToCollectionWithCategory('movie', 'Movie Library', 'assets/icons/ic_popcorn.png'),
            ),
            _buildOption(
              context,
              iconWidget: Icon(Icons.tv, color: AppTheme.primary, size: 20),
              label: 'TV Show',
              onTap: () => _addToCollectionWithCategory('tv', 'TV Show', 'assets/icons/ic_popcorn.png'),
            ),
            _buildOption(
              context,
              iconWidget: Image.asset('assets/icons/ic_bilibili.png', width: 20, height: 20),
              label: 'Anime Wall',
              onTap: () => _addToCollectionWithCategory('anime', 'Anime Wall', 'assets/icons/ic_bilibili.png'),
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

  Future<void> _addToCollectionWithCategory(String mediaType, String categoryLabel, String iconPath) async {
    // Optimistic UI: Update state immediately
    setState(() {
      _isCollected = true;
      _watchStatus = 'wish';
    });

    // Show success feedback immediately
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
      final modifiedMedia = widget.media.copyWith(
        mediaType: mediaType,
      );

      final id = await _repository.addToCollection(modifiedMedia, status: 'wish');
      if (mounted) {
        setState(() {
          _collectionId = id;
        });
      }
    } catch (e) {
      if (mounted) {
        // Revert State
        setState(() {
          _isCollected = false;
          _watchStatus = 'wish'; // or reset to previous logic if complex
          _collectionId = '';
        });
        AppSnackBar.showError(context, message: '添加失败: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleRow(),
                  const SizedBox(height: 24),
                  RatingDisplayWidget(media: widget.media),
                  const SizedBox(height: 32),

                  // Synopsis
                  Text(
                    '简介',
                    style: TextStyle(
                      fontFamily: AppTheme.primaryFont,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildExpandableSynopsis(widget.media.summary),
                  const SizedBox(height: 32),

                  // Staff / Cast
                  if (widget.media.mediaType == 'anime') ...[
                    _buildAnimeStaffSection(),
                    CharacterListWidget(media: widget.media),
                  ] else ...[
                    if (widget.media.directors.isNotEmpty) ...[
                      _buildDirectorsSection(),
                      const SizedBox(height: 24),
                    ],
                    if (widget.media.actors.isNotEmpty) _buildActorsSection(),
                  ],
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods...

  Widget _buildSliverAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final buttonBg = isDark ? Colors.black.withValues(alpha: 0.5) : AppColors.surfaceElevated.withValues(alpha: 0.9);

    return SliverAppBar(
      expandedHeight: MediaQuery.of(context).size.width * 1.5,
      pinned: true,
      backgroundColor: bgColor,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: buttonBg,
          child: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: widget.media.posterUrl,
              child: CachedNetworkImage(
                imageUrl: widget.media.posterUrl,
                fit: BoxFit.cover,
                // Ensure image covers the space completely
                alignment: Alignment.topCenter,
                placeholder: (context, url) => Container(
                  color: AppColors.surfaceDeep,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
                errorWidget: (context, url, error) => Image.asset(
                  'assets/icons/ic_np_poster.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // Gradient Overlay - Extended slightly to prevent "leakage"
            Positioned(
              bottom: -1, // Overlap slightly
              left: 0,
              right: 0,
              height: 250, // Increased height for better gradient smooth
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      bgColor.withValues(alpha: 0.6),
                      bgColor.withValues(alpha: 0.9),
                      bgColor,
                    ],
                    stops: const [0.0, 0.5, 0.8, 1.0],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Text(
                widget.media.titleOriginal.isNotEmpty ? widget.media.titleOriginal : widget.media.titleZh,
                style: TextStyle(
                  fontFamily: AppTheme.primaryFont,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : textColor, // Brighter in dark mode
                  shadows: [
                    Shadow(
                      color: isDark ? Colors.black : AppColors.surfaceElevated,
                      blurRadius: 10,
                      offset: Offset(0, 2),
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

  Widget _buildTitleRow() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? episodeText;
    if (widget.media.mediaType == 'anime' || widget.media.mediaType == 'tv') {
      episodeText = widget.media.duration.isNotEmpty ? widget.media.duration : '??';
      if (RegExp(r'^\d+$').hasMatch(episodeText)) {
        episodeText = '$episodeText集';
      } else {
        episodeText = episodeText.replaceAll('共', '');
      }
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            widget.media.titleZh,
            style: TextStyle(
              fontFamily: AppTheme.primaryFont,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Movie Duration
        if (widget.media.mediaType == 'movie' && widget.media.duration.isNotEmpty)
          Row(
            children: [
              Icon(Icons.access_time, color: AppColors.textSecondary, size: 16),
              const SizedBox(width: 4),
              Text(
                widget.media.duration,
                style: TextStyle(
                  fontFamily: AppTheme.primaryFont,
                  fontSize: 14,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),

        // TV/Anime Episode Count
        if (episodeText != null)
          Row(
            children: [
              Icon(Icons.layers_outlined, color: isDark ? Colors.white : AppColors.textPrimary, size: 20),
              const SizedBox(width: 4),
              Text(
                episodeText,
                style: TextStyle(
                  fontFamily: AppTheme.primaryFont,
                  fontSize: 18,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),

        InkWell(
          onTap: () {
            if (_isCollected) {
              _showWatchStatusSheet();
            } else {
              _showCategorySheet();
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(8),
            child: Icon(
              _isCollected ? Icons.bookmark : Icons.bookmark_border,
              color: AppColors.starActive,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimeStaffSection() {
    // Parse staff string: "Director Name / Original Name / Script Name"
    final staffParts = widget.media.staff.split('/');
    final directorName = staffParts.isNotEmpty ? staffParts[0].trim() : '';
    final originalName = staffParts.length > 1 ? staffParts[1].trim() : '';
    final scriptName = staffParts.length > 2 ? staffParts[2].trim() : '';
    final charDesignName = staffParts.length > 3 ? staffParts[3].trim() : '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (directorName.isNotEmpty) ...[
          _buildStaffSectionTitle('导演', Icons.person_rounded, directorName),
          const SizedBox(height: 16),
        ],
        if (originalName.isNotEmpty) ...[
          _buildStaffSectionTitle('原作', Icons.book_rounded, originalName),
          const SizedBox(height: 16),
        ],
        if (scriptName.isNotEmpty) ...[
          _buildStaffSectionTitle('脚本', Icons.edit_rounded, scriptName),
          const SizedBox(height: 16),
        ],
        if (charDesignName.isNotEmpty) ...[
          _buildStaffSectionTitle('人物设定', Icons.brush_rounded, charDesignName),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildStaffSectionTitle(String title, IconData icon, String content) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Theme.of(context).dividerColor.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                content,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDirectorsSection() {
    return _buildSectionWithChips(
      '导演',
      Icons.person_rounded,
      widget.media.directors,
    );
  }

  Widget _buildActorsSection() {
    return _buildSectionWithChips(
      '主演',
      Icons.face_outlined,
      widget.media.actors,
    );
  }

  Widget _buildSectionWithChips(String title, IconData icon, List<String> items) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : AppColors.textPrimary;

    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 16,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: titleColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map((item) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : Theme.of(context).dividerColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Text(
                      item,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildExpandableSynopsis(String summary) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (summary.isEmpty) return const SizedBox.shrink();
    return Text(
      summary,
      style: TextStyle(
        fontFamily: AppTheme.primaryFont,
        fontSize: 15,
        height: 1.6,
        color: isDark ? Colors.white70 : AppColors.textSecondary,
      ),
      maxLines: 6,
      overflow: TextOverflow.ellipsis,
    );
  }
}
