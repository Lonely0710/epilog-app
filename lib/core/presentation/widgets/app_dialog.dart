import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import 'shared_dialog_button.dart';

const double _kAppDialogRadius = 24;

class AppDialogAction {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final SharedDialogButtonVariant variant;
  final bool isLoading;
  final bool isDisabled;

  const AppDialogAction({
    required this.text,
    required this.onPressed,
    this.icon,
    this.color,
    this.variant = SharedDialogButtonVariant.primary,
    this.isLoading = false,
    this.isDisabled = false,
  });
}

class AppDialog extends StatelessWidget {
  @Deprecated('iOS-style alerts should not show decorative icons.')
  final IconData? icon;
  final String title;
  final Widget content;
  final AppDialogAction? primaryAction;
  final AppDialogAction? secondaryAction;
  final bool showCloseButton;
  final CrossAxisAlignment contentAlignment;

  const AppDialog({
    super.key,
    required this.title,
    required this.content,
    this.icon,
    this.primaryAction,
    this.secondaryAction,
    this.showCloseButton = false,
    this.contentAlignment = CrossAxisAlignment.center,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final backgroundColor =
        isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF7F7F7);
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary;
    final brandTint = colorScheme.primary;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(_kAppDialogRadius),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_kAppDialogRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Stack(
            children: [
              Container(
                constraints: const BoxConstraints(maxWidth: 398),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    brandTint.withValues(alpha: isDark ? 0.08 : 0.04),
                    backgroundColor.withValues(alpha: isDark ? 0.90 : 0.92),
                  ),
                  borderRadius: BorderRadius.circular(_kAppDialogRadius),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.10)
                        : Colors.white.withValues(alpha: 0.85),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withValues(alpha: isDark ? 0.36 : 0.16),
                      blurRadius: 34,
                      offset: const Offset(0, 16),
                    ),
                    BoxShadow(
                      color: brandTint.withValues(alpha: isDark ? 0.14 : 0.08),
                      blurRadius: 28,
                      spreadRadius: -18,
                      offset: const Offset(0, 10),
                    ),
                    if (!isDark)
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.72),
                        blurRadius: 0,
                        offset: const Offset(0, 1),
                      ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _DialogHeader(title: title, textColor: textColor),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * 0.58,
                      ),
                      child: SingleChildScrollView(
                        child: Align(
                          alignment: _alignmentFromCrossAxis(contentAlignment),
                          child: content,
                        ),
                      ),
                    ),
                    if (primaryAction != null || secondaryAction != null) ...[
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          if (secondaryAction != null) ...[
                            _ActionButton(action: secondaryAction!),
                            if (primaryAction != null)
                              const SizedBox(width: 10),
                          ],
                          if (primaryAction != null)
                            _ActionButton(action: primaryAction!),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (showCloseButton)
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white54 : AppTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Alignment _alignmentFromCrossAxis(CrossAxisAlignment alignment) {
    return switch (alignment) {
      CrossAxisAlignment.start => Alignment.centerLeft,
      CrossAxisAlignment.end => Alignment.centerRight,
      CrossAxisAlignment.stretch => Alignment.center,
      CrossAxisAlignment.baseline => Alignment.centerLeft,
      CrossAxisAlignment.center => Alignment.center,
    };
  }
}

class _DialogHeader extends StatelessWidget {
  final String title;
  final Color textColor;

  const _DialogHeader({
    required this.title,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Text(
        title,
        textAlign: TextAlign.start,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textColor,
          height: 1.25,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final AppDialogAction action;

  const _ActionButton({required this.action});

  @override
  Widget build(BuildContext context) {
    return SharedDialogButton(
      text: action.text,
      onTap: action.onPressed,
      icon: action.icon,
      color: action.color,
      variant: action.variant,
      isLoading: action.isLoading,
      isDisabled: action.isDisabled,
    );
  }
}
