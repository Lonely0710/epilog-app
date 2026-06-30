import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

enum SharedDialogButtonVariant { primary, secondary, destructive }

/// A standardized dialog button used across the app (Dialogs, Alerts).
///
/// [isPrimary] determines if it's a solid colored button (true) or an outlined/faded button (false).
/// [color] overrides the default primary color.
class SharedDialogButton extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  final bool isPrimary;
  final IconData? icon;
  final Color? color;
  final SharedDialogButtonVariant? variant;
  final bool isLoading;
  final bool isDisabled;

  const SharedDialogButton({
    super.key,
    required this.text,
    required this.onTap,
    this.isPrimary = true,
    this.icon,
    this.color,
    this.variant,
    this.isLoading = false,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveVariant = variant ??
        (isPrimary
            ? SharedDialogButtonVariant.primary
            : SharedDialogButtonVariant.secondary);
    final themeColor = color ??
        (effectiveVariant == SharedDialogButtonVariant.destructive
            ? AppTheme.error
            : effectiveVariant == SharedDialogButtonVariant.secondary
                ? (isDark
                    ? Colors.white.withValues(alpha: 0.68)
                    : const Color(0xFF86868B))
                : AppTheme.primary);
    final isFilled = effectiveVariant != SharedDialogButtonVariant.secondary;
    final enabled = !isDisabled && !isLoading && onTap != null;
    final foregroundColor = isFilled ? Colors.white : themeColor;
    final backgroundColor = enabled
        ? (isFilled
            ? themeColor
            : (isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.06)))
        : (isFilled
            ? themeColor.withValues(alpha: 0.45)
            : (isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04)));

    return Expanded(
      child: Semantics(
        button: true,
        enabled: enabled,
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          child: GestureDetector(
            onTap: enabled ? onTap : null,
            behavior: HitTestBehavior.opaque,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: enabled ? 1 : 0.72,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(25),
                  border: isFilled
                      ? null
                      : Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.white.withValues(alpha: 0.72),
                        ),
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: isLoading
                        ? SizedBox(
                            key: const ValueKey('loading'),
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: foregroundColor,
                            ),
                          )
                        : Row(
                            key: const ValueKey('content'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: foregroundColor,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
