import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../../../../app/theme/app_colors.dart';

enum SnackBarType { success, error, warning, info }

class AppSnackBar {
  AppSnackBar._();

  static OverlayEntry? _currentEntry;
  static VoidCallback? _currentDismiss;

  /// Map system errors to user-friendly messages.
  static String _getFriendlyMessage(dynamic error, String? customMessage) {
    if (customMessage != null && customMessage.isNotEmpty) return customMessage;

    if (error != null) {
      final errorStr = error.toString().toLowerCase();
      if (errorStr.contains('invalid login credentials')) {
        return '邮箱或密码错误，请重试。';
      }
      if (errorStr.contains('user already exists')) {
        return '该邮箱已注册，请直接登录。';
      }
      if (errorStr.contains('email not confirmed')) {
        return '登录前请先确认您的邮箱。';
      }
      return error.message;
    }

    if (error != null) {
      final errorStr = error.toString().toLowerCase();
      if (errorStr.contains('network') || errorStr.contains('socket')) {
        return '网络连接错误，请检查您的网络。';
      }
      if (errorStr.contains('timeout')) {
        return '请求超时，请稍后再试。';
      }
      return error.toString();
    }

    return '发生了意外错误。';
  }

  /// Show a unified SnackBar.
  static void show(
    BuildContext context, {
    required SnackBarType type,
    dynamic error,
    String? message,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
    Widget? customIcon,
    Color? customColor,
    String? emphasizedText,
  }) {
    final finalMessage = _getFriendlyMessage(error, message);

    Color baseColor;
    IconData iconData;

    switch (type) {
      case SnackBarType.success:
        baseColor = AppColors.success;
        iconData = Icons.check_circle_rounded;
        break;
      case SnackBarType.error:
        baseColor = AppColors.error;
        iconData = Icons.cancel_rounded;
        break;
      case SnackBarType.warning:
        baseColor = AppColors.warning;
        iconData = Icons.warning_rounded;
        break;
      case SnackBarType.info:
        baseColor = AppColors.info;
        iconData = Icons.info_rounded;
        break;
    }

    if (customColor != null) {
      baseColor = customColor;
    }

    switch (type) {
      case SnackBarType.success:
        HapticFeedback.lightImpact();
        break;
      case SnackBarType.error:
      case SnackBarType.warning:
        HapticFeedback.mediumImpact();
        break;
      case SnackBarType.info:
        break;
    }

    _currentDismiss?.call();
    _currentEntry = null;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(finalMessage), duration: duration),
      );
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _AppSnackBanner(
        type: type,
        message: finalMessage,
        duration: duration,
        color: baseColor,
        icon: customIcon ?? Icon(iconData, color: baseColor, size: 22),
        emphasizedText: emphasizedText,
        actionLabel: actionLabel,
        onAction: onAction,
        onDismissReady: (dismiss) => _currentDismiss = dismiss,
        onDismissed: () {
          if (_currentEntry == entry) {
            _currentEntry = null;
            _currentDismiss = null;
          }
          if (entry.mounted) {
            entry.remove();
          }
        },
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  // Convenient wrappers
  static void showSuccess(BuildContext context, String message) {
    show(context, type: SnackBarType.success, message: message);
  }

  static void showError(BuildContext context,
      {dynamic error, String? message}) {
    show(context, type: SnackBarType.error, error: error, message: message);
  }

  static void showWarning(BuildContext context, String message) {
    show(context, type: SnackBarType.warning, message: message);
  }

  static void showInfo(BuildContext context, String message) {
    show(context, type: SnackBarType.info, message: message);
  }

  static void showNetworkError(BuildContext context, {VoidCallback? onRetry}) {
    show(
      context,
      type: SnackBarType.error,
      message: '网络连接异常，请检查网络',
      onAction: onRetry,
      actionLabel: '重试',
      duration: const Duration(seconds: 5),
    );
  }
}

class _AppSnackBanner extends StatefulWidget {
  final SnackBarType type;
  final String message;
  final Duration duration;
  final Color color;
  final Widget icon;
  final String? emphasizedText;
  final String? actionLabel;
  final VoidCallback? onAction;
  final ValueChanged<VoidCallback> onDismissReady;
  final VoidCallback onDismissed;

  const _AppSnackBanner({
    required this.type,
    required this.message,
    required this.duration,
    required this.color,
    required this.icon,
    required this.onDismissReady,
    required this.onDismissed,
    this.emphasizedText,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<_AppSnackBanner> createState() => _AppSnackBannerState();
}

class _AppSnackBannerState extends State<_AppSnackBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;
  Timer? _timer;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _opacity = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    widget.onDismissReady(_dismiss);
    _controller.forward();
    _timer = Timer(widget.duration, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_dismissed) return;
    _dismissed = true;
    _timer?.cancel();
    if (mounted) {
      await _controller.reverse();
    }
    widget.onDismissed();
  }

  void _handleAction() {
    widget.onAction?.call();
    _dismiss();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    final glassBase = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final backgroundColor = Color.alphaBlend(
      colorScheme.primary.withValues(alpha: isDark ? 0.08 : 0.025),
      glassBase.withValues(alpha: isDark ? 0.58 : 0.34),
    );
    final textColor = isDark ? Colors.white : AppColors.textPrimary;
    const bottomNavVisualHeight = 114.0;
    final bottom = mediaQuery.padding.bottom + bottomNavVisualHeight;

    return Positioned(
      bottom: bottom,
      left: 16,
      right: 16,
      child: SafeArea(
        top: false,
        bottom: false,
        child: SlideTransition(
          position: _offset,
          child: FadeTransition(
            opacity: _opacity,
            child: Dismissible(
              key: UniqueKey(),
              direction: DismissDirection.horizontal,
              onDismissed: (_) => _dismiss(),
              child: Material(
                color: Colors.transparent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: backgroundColor,
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.18)
                                    : Colors.white.withValues(alpha: 0.34),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.30 : 0.10,
                                  ),
                                  blurRadius: 24,
                                  spreadRadius: -12,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: const [0, 0.42, 1],
                                colors: [
                                  Colors.white.withValues(
                                    alpha: isDark ? 0.12 : 0.20,
                                  ),
                                  Colors.white.withValues(
                                    alpha: isDark ? 0.02 : 0.04,
                                  ),
                                  Colors.white.withValues(
                                    alpha: isDark ? 0.08 : 0.12,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        LiquidGlassLayer(
                          settings: LiquidGlassSettings(
                            refractiveIndex: 1.19,
                            thickness: isDark ? 22 : 26,
                            blur: isDark ? 9 : 11,
                            saturation: isDark ? 1.16 : 1.26,
                            chromaticAberration: 0.012,
                            lightAngle: -0.7853981633974483,
                            lightIntensity: isDark ? 0.68 : 0.88,
                            ambientStrength: isDark ? 0.10 : 0.16,
                            glassColor: Colors.white.withValues(
                              alpha: isDark ? 0.04 : 0.02,
                            ),
                          ),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: widget.color.withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Semantics(
                                      label: _statusLabel,
                                      child: widget.icon,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _SnackMessageText(
                                    message: widget.message,
                                    emphasizedText: widget.emphasizedText,
                                    textColor: textColor,
                                  ),
                                ),
                                if (widget.onAction != null &&
                                    widget.actionLabel != null) ...[
                                  const SizedBox(width: 12),
                                  TextButton(
                                    onPressed: _handleAction,
                                    style: TextButton.styleFrom(
                                      foregroundColor: widget.color,
                                      minimumSize: const Size(44, 36),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: Text(
                                      widget.actionLabel!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
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

  String get _statusLabel {
    switch (widget.type) {
      case SnackBarType.success:
        return '成功';
      case SnackBarType.error:
        return '错误';
      case SnackBarType.warning:
        return '警告';
      case SnackBarType.info:
        return '提示';
    }
  }
}

class _SnackMessageText extends StatelessWidget {
  final String message;
  final String? emphasizedText;
  final Color textColor;

  const _SnackMessageText({
    required this.message,
    required this.emphasizedText,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      color: textColor,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      height: 1.25,
      letterSpacing: 0,
    );
    final target = emphasizedText;
    final index =
        target == null || target.isEmpty ? -1 : message.indexOf(target);

    if (index < 0 || target == null) {
      return Text(
        message,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: baseStyle,
      );
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: message.substring(0, index)),
          TextSpan(
            text: target,
            style: baseStyle.copyWith(fontWeight: FontWeight.w900),
          ),
          TextSpan(text: message.substring(index + target.length)),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: baseStyle,
    );
  }
}
