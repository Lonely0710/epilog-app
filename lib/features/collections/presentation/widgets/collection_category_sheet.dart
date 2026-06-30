import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';

class CollectionCategoryAction {
  final String mediaType;
  final String label;
  final String successLabel;
  final String iconPath;

  const CollectionCategoryAction({
    required this.mediaType,
    required this.label,
    required this.successLabel,
    required this.iconPath,
  });
}

Future<void> showCollectionCategorySheet({
  required BuildContext context,
  required ValueChanged<CollectionCategoryAction> onSelected,
  bool useRootNavigator = false,
}) {
  final actions = <CollectionCategoryAction>[
    CollectionCategoryAction(
      mediaType: 'movie',
      label: '电影库',
      successLabel: '电影库',
      iconPath: 'assets/icons/popcorn-bold.svg',
    ),
    CollectionCategoryAction(
      mediaType: 'tv',
      label: '电视剧',
      successLabel: '电视剧',
      iconPath: 'assets/icons/monitor-play-bold.svg',
    ),
    CollectionCategoryAction(
      mediaType: 'anime',
      label: '动漫墙',
      successLabel: '动漫墙',
      iconPath: 'assets/icons/cactus-bold.svg',
    ),
  ];

  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: useRootNavigator,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.32),
    isScrollControlled: false,
    builder: (sheetContext) {
      return _CollectionCategorySheet(
        actions: actions,
        onSelected: (action) {
          HapticFeedback.selectionClick();
          Navigator.pop(sheetContext);
          onSelected(action);
        },
      );
    },
  );
}

class _CollectionCategorySheet extends StatelessWidget {
  final List<CollectionCategoryAction> actions;
  final ValueChanged<CollectionCategoryAction> onSelected;

  const _CollectionCategorySheet({
    required this.actions,
    required this.onSelected,
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
                      '加入资料库',
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
                        '选择想加入的分类',
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
                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.015),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final action in actions)
                        _CollectionCategoryRow(
                          action: action,
                          onTap: () => onSelected(action),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CollectionCategoryRow extends StatefulWidget {
  final CollectionCategoryAction action;
  final VoidCallback onTap;

  const _CollectionCategoryRow({
    required this.action,
    required this.onTap,
  });

  @override
  State<_CollectionCategoryRow> createState() => _CollectionCategoryRowState();
}

class _CollectionCategoryRowState extends State<_CollectionCategoryRow> {
  void _handleTap() {
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = theme.textTheme.bodyLarge?.color ??
        (isDark ? Colors.white : AppColors.textPrimary);
    final pressedColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);
    final iconColor = isDark
        ? AppTheme.primary.withValues(alpha: 0.92)
        : AppTheme.primary.withValues(alpha: 0.86);
    final iconBackground = isDark
        ? AppTheme.primary.withValues(alpha: 0.20)
        : AppTheme.primary.withValues(alpha: 0.10);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleTap,
        splashColor: Colors.transparent,
        highlightColor: pressedColor,
        borderRadius: BorderRadius.circular(18),
        child: SizedBox(
          height: 66,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: SvgPicture.asset(
                    widget.action.iconPath,
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(
                      iconColor,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.action.label,
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.28)
                      : AppColors.textTertiary,
                  size: 22,
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
