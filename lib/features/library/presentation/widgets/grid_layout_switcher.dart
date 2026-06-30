import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class GridLayoutSwitcher extends StatelessWidget {
  final bool isCompactMode;
  final VoidCallback onToggle;
  final double size;
  final String? tooltip;

  const GridLayoutSwitcher({
    super.key,
    required this.isCompactMode,
    required this.onToggle,
    this.size = 48,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip ?? (isCompactMode ? '切换为大海报' : '切换为紧凑网格'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(size / 2),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceVariant.withValues(alpha: 0.78)
                  : Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(size / 2),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.18)
                    : Colors.white.withValues(alpha: 0.74),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.13),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return ScaleTransition(scale: animation, child: child);
              },
              child: Icon(
                isCompactMode
                    ? Icons.grid_view_rounded
                    : Icons.view_module_rounded,
                key: ValueKey(isCompactMode),
                color: isDark ? Colors.white : AppColors.textPrimary,
                size: size * 0.48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
