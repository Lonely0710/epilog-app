import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/domain/entities/media.dart';

/// Watch status bottom sheet (P3 style dragger).
/// Shows 4 watch status options from collections table:
/// - wish (想看)
/// - watching (在看)
/// - watched (看过)
/// - dropped (弃剧)
class WatchStatusBottomSheet extends StatelessWidget {
  final Media media;
  final String currentStatus;
  final ValueChanged<String> onStatusSelected;

  const WatchStatusBottomSheet({
    super.key,
    required this.media,
    required this.currentStatus,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = Theme.of(context).cardColor;
    final dividerColor = Theme.of(context).dividerColor;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 16),

          // Media header
          _buildMediaHeader(context, isDark),

          const SizedBox(height: 16),

          // Divider
          Divider(
            height: 1,
            color: dividerColor,
          ),

          // Status options
          _buildStatusOption(
            context,
            isDark: isDark,
            status: 'wish',
            icon: Icons.bookmark_outline,
            label: '想看',
            sublabel: 'Watch',
          ),
          _buildStatusOption(
            context,
            isDark: isDark,
            status: 'watching',
            icon: Icons.play_circle_outline_rounded,
            label: '在看',
            sublabel: 'Watching',
          ),
          _buildStatusOption(
            context,
            isDark: isDark,
            status: 'watched',
            icon: Icons.check_circle_outline_rounded,
            label: '看过',
            sublabel: 'Finished',
          ),
          _buildStatusOption(
            context,
            isDark: isDark,
            status: 'on_hold',
            icon: Icons.pause_circle_outline_rounded,
            label: '搁置',
            sublabel: 'On Hold',
          ),

          // Safe area padding
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildMediaHeader(BuildContext context, bool isDark) {
    final textPrimary = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondary = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final placeholderColor = isDark ? AppColors.surfaceDark : AppColors.placeholder;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Poster thumbnail
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 60,
              height: 80,
              child: media.posterUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: media.posterUrl,
                      fit: BoxFit.cover,
                      errorWidget: (context, url, error) => Container(
                        color: placeholderColor,
                        child: Icon(Icons.movie_outlined, color: textSecondary, size: 24),
                      ),
                    )
                  : Container(
                      color: placeholderColor,
                      child: Icon(Icons.movie_outlined, color: textSecondary, size: 24),
                    ),
            ),
          ),

          const SizedBox(width: 12),

          // Title and duration
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  media.titleZh.isNotEmpty ? media.titleZh : media.titleOriginal,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (media.duration.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    media.duration,
                    style: TextStyle(
                      color: textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Rating badge if available
          if (media.rating > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                media.rating.toString(),
                style: TextStyle(
                  color: isDark ? AppColors.gold : AppColors.goldDark,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusOption(
    BuildContext context, {
    required bool isDark,
    required String status,
    required IconData icon,
    required String label,
    required String sublabel,
  }) {
    final isSelected = currentStatus == status;
    final primaryColor = AppColors.starActive;
    final textPrimary = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondary = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return InkWell(
      onTap: () => onStatusSelected(status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : textSecondary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Row(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? primaryColor : textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    sublabel,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected ? primaryColor.withValues(alpha: 0.8) : textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: primaryColor,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
