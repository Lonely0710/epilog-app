import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/domain/entities/media.dart';
import 'watch_status_icon.dart';

/// Watch status bottom sheet (P3 style dragger).
/// Shows 4 watch status options from collections table:
/// - wish (想看)
/// - watching (在看)
/// - watched (看过)
/// - on_hold (搁置)
class WatchStatusBottomSheet extends StatelessWidget {
  final Media media;
  final String currentStatus;
  final ValueChanged<String> onStatusSelected;
  final VoidCallback? onRemoveCollection;

  const WatchStatusBottomSheet({
    super.key,
    required this.media,
    required this.currentStatus,
    required this.onStatusSelected,
    this.onRemoveCollection,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final materialColor = isDark
        ? const Color(0xFF1C1C1E).withValues(alpha: 0.92)
        : Colors.white.withValues(alpha: 0.94);
    final primaryText = theme.textTheme.bodyLarge?.color ??
        (isDark ? Colors.white : AppColors.textPrimary);
    final secondaryText =
        theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.62) ??
            (isDark
                ? Colors.white.withValues(alpha: 0.62)
                : AppColors.textSecondary.withValues(alpha: 0.72));

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: materialColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.04),
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              10,
              20,
              bottomPadding > 0 ? bottomPadding + 8 : 20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.20)
                        : Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Text(
                      '修改观看状态',
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        '选择当前进度',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildMediaHeader(context, isDark),
                const SizedBox(height: 12),
                _buildStatusGrid(context, isDark: isDark),
                if (onRemoveCollection != null) ...[
                  const SizedBox(height: 12),
                  _buildRemoveButton(context, isDark: isDark),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRemoveButton(
    BuildContext context, {
    required bool isDark,
  }) {
    final color = AppColors.error;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onRemoveCollection?.call();
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.16 : 0.08),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.34 : 0.22),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bookmark_remove_rounded, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                '取消收藏',
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaHeader(BuildContext context, bool isDark) {
    final textPrimary =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondary =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final placeholderColor =
        isDark ? AppColors.surfaceDark : AppColors.placeholder;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : AppColors.surface.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 52,
                height: 68,
                child: media.posterUrl.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: media.posterUrl,
                        fit: BoxFit.cover,
                        errorWidget: (context, url, error) => Container(
                          color: placeholderColor,
                          child: Icon(
                            Icons.movie_outlined,
                            color: textSecondary,
                            size: 22,
                          ),
                        ),
                      )
                    : Container(
                        color: placeholderColor,
                        child: Icon(
                          Icons.movie_outlined,
                          color: textSecondary,
                          size: 22,
                        ),
                      ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  media.titleZh.isNotEmpty
                      ? media.titleZh
                      : media.titleOriginal,
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
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
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (media.rating > 0)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: isDark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  media.rating.toString(),
                  style: TextStyle(
                    color: isDark ? AppColors.gold : AppColors.goldDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusGrid(
    BuildContext context, {
    required bool isDark,
  }) {
    const options = [
      ('wish', '想看'),
      ('watching', '在看'),
      ('watched', '看过'),
      ('on_hold', '搁置'),
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 2; row++) ...[
          Row(
            children: [
              for (var col = 0; col < 2; col++) ...[
                Expanded(
                  child: _buildStatusOption(
                    context,
                    isDark: isDark,
                    status: options[row * 2 + col].$1,
                    label: options[row * 2 + col].$2,
                  ),
                ),
                if (col == 0) const SizedBox(width: 12),
              ],
            ],
          ),
          if (row == 0) const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildStatusOption(
    BuildContext context, {
    required bool isDark,
    required String status,
    required String label,
  }) {
    final isSelected = currentStatus == status;
    final primaryColor = watchStatusColor(status);
    final textPrimary =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final pressedColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);
    final iconColor = isSelected
        ? primaryColor
        : (isDark
            ? Colors.white.withValues(alpha: 0.62)
            : AppColors.textSecondary.withValues(alpha: 0.82));
    final iconBackground = isSelected
        ? primaryColor.withValues(alpha: isDark ? 0.24 : 0.14)
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.textSecondary.withValues(alpha: 0.08));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onStatusSelected(status);
        },
        splashColor: Colors.transparent,
        highlightColor: pressedColor,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withValues(alpha: isDark ? 0.18 : 0.12)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : Colors.black.withValues(alpha: 0.018)),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? primaryColor.withValues(alpha: 0.86)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.04)),
              width: isSelected ? 1.4 : 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: iconBackground,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        watchStatusIconData(status),
                        color: iconColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        color: isSelected ? primaryColor : textPrimary,
                        letterSpacing: 0,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 10),
                      Icon(
                        Icons.check_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
