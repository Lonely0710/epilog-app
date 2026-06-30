import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';

/// A reusable widget for displaying empty or error states.
/// Uses the app's theme colors for consistency.
class EmptyStateWidget extends StatefulWidget {
  const EmptyStateWidget({
    super.key,
    this.message = '暂无内容',
    this.icon,
    this.lottieAsset,
    this.svgAsset,
    this.actionLabel = '刷新',
    this.onAction,
  });

  /// Main message to display.
  final String message;

  /// Optional icon to display above the message
  final IconData? icon;

  /// Optional Lottie animation asset path (takes precedence over icon)
  final String? lottieAsset;

  /// Optional SVG asset path (takes precedence over icon, but after Lottie)
  final String? svgAsset;

  /// Label for the action button (default: "刷新")
  final String actionLabel;

  /// Callback for the action button. If null, no button is shown.
  final VoidCallback? onAction;

  @override
  State<EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<EmptyStateWidget> {
  static const _defaultSvgAssets = [
    'assets/images/empty_loading.svg',
    'assets/images/search_empty.svg',
  ];

  late final String _randomSvgAsset =
      _defaultSvgAssets[Random().nextInt(_defaultSvgAssets.length)];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final svgAsset = widget.svgAsset ?? _randomSvgAsset;
    final action = widget.onAction;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.lottieAsset != null)
              Lottie.asset(
                widget.lottieAsset!,
                width: 150,
                height: 150,
                repeat: true,
              )
            else
              SvgPicture.asset(
                svgAsset,
                width: 150,
                height: 150,
              ),
            const SizedBox(height: 24),
            Text(
              widget.message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: action,
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: theme.colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(
                  widget.actionLabel,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
