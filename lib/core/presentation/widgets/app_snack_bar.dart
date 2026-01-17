import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../app/theme/app_colors.dart';

enum SnackBarType { success, error, warning, info }

class AppSnackBar {
  AppSnackBar._();

  /// Map system errors to user-friendly messages.
  static String _getFriendlyMessage(dynamic error, String? customMessage) {
    if (customMessage != null && customMessage.isNotEmpty) return customMessage;

    if (error is AuthException) {
      if (error.message.contains('Invalid login credentials')) {
        return '邮箱或密码错误，请重试。';
      }
      if (error.message.contains('User already exists')) {
        return '该邮箱已注册，请直接登录。';
      }
      if (error.message.contains('Email not confirmed')) {
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
  }) {
    final finalMessage = _getFriendlyMessage(error, message);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Define colors and icons based on type
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

    // Override if custom color provided
    if (customColor != null) {
      baseColor = customColor;
    }

    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final bgColor = Color.alphaBlend(baseColor.withValues(alpha: isDark ? 0.15 : 0.05), surfaceColor);
    final borderColor = baseColor.withValues(alpha: 0.5);
    final textColor = isDark ? Colors.white : Colors.black87;

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              customIcon ?? Icon(iconData, color: baseColor, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  finalMessage,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    onAction();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: baseColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: baseColor.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Text(
                      actionLabel,
                      style: TextStyle(
                        color: baseColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(Icons.close, color: baseColor.withValues(alpha: 0.5), size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                },
              ),
            ],
          ),
        ),
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        padding: EdgeInsets.zero,
        // Remove default action since we added a custom one inside the container
      ),
    );
  }

  // Convenient wrappers
  static void showSuccess(BuildContext context, String message) {
    show(context, type: SnackBarType.success, message: message);
  }

  static void showError(BuildContext context, {dynamic error, String? message}) {
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
