import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../widgets/settings_background.dart';

class SupportAboutPage extends StatelessWidget {
  const SupportAboutPage({super.key});

  Future<void> _launchUrl(BuildContext context, String urlString) async {
    final url = Uri.parse(urlString);
    final mode = url.scheme == 'mailto'
        ? LaunchMode.platformDefault
        : LaunchMode.externalApplication;

    try {
      if (!await launchUrl(url, mode: mode)) {
        throw 'Could not launch $urlString';
      }
    } catch (_) {
      if (!context.mounted) return;
      if (url.scheme == 'mailto') {
        await Clipboard.setData(ClipboardData(text: url.path));
        if (context.mounted) {
          AppSnackBar.showSuccess(context, '邮箱已复制到剪贴板');
        }
      } else {
        AppSnackBar.showError(context, message: '无法打开链接: $urlString');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? AppTheme.textPrimary;
    final secondaryColor = isDark
        ? Colors.white.withValues(alpha: 0.56)
        : AppColors.textSecondary.withValues(alpha: 0.78);
    final pageBackground =
        isDark ? const Color(0xFF0D1D2A) : const Color(0xFFF6F6F7);

    return Scaffold(
      backgroundColor: pageBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 64,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 26,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '问题反馈',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      body: ColoredBox(
        color: pageBackground,
        child: SettingsBackground(
          child: SafeArea(
            top: false,
            bottom: false,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    MediaQuery.paddingOf(context).top + kToolbarHeight + 18,
                    16,
                    MediaQuery.paddingOf(context).bottom + 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight -
                          MediaQuery.paddingOf(context).top -
                          kToolbarHeight -
                          42,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GlassPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Epilog',
                                style: TextStyle(
                                  fontFamily: 'Pacifico',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w400,
                                  color: textColor,
                                  height: 1.1,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                '一个用来整理光影记忆、珍藏感动瞬间的私人角落。',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.5,
                                  color: secondaryColor,
                                  letterSpacing: 0,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                '作为一名海报控和影迷，Epilog 的诞生源于对电影艺术的热爱。愿它能陪你记录每一段精彩的旅程。',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.55,
                                  color: secondaryColor,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _GlassPanel(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            children: [
                              _ContactActionRow(
                                label: 'GitHub',
                                subtitle: '查看项目与反馈问题',
                                asset: 'assets/icons/ic_staff_github.png',
                                onTap: () => _launchUrl(
                                  context,
                                  'https://github.com/Lonely0710',
                                ),
                              ),
                              _DividerLine(),
                              _ContactActionRow(
                                label: '邮箱',
                                subtitle: '联系开发者',
                                asset: 'assets/icons/ic_staff_gmail.png',
                                onTap: () => _launchUrl(
                                  context,
                                  'mailto:lingsou43@gmail.com',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _GlassPanel(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 15,
                          ),
                          child: Row(
                            children: [
                              LucideAnimatedIcon(
                                icon: file_text,
                                color: AppTheme.primary,
                                size: 24,
                                trigger: AnimationTrigger.onHover,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  '当前版本',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                ),
                              ),
                              Text(
                                'v1.0.0',
                                style: TextStyle(
                                  fontFamily: 'CourierPrime',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: secondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(18),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = BorderRadius.circular(22);

    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.68),
            borderRadius: radius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.48),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ContactActionRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final String asset;
  final VoidCallback onTap;

  const _ContactActionRow({
    required this.label,
    required this.subtitle,
    required this.asset,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? AppTheme.textPrimary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryColor = isDark
        ? Colors.white.withValues(alpha: 0.56)
        : AppColors.textSecondary.withValues(alpha: 0.78);

    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          splashColor: AppTheme.primary.withValues(alpha: 0.08),
          highlightColor: AppTheme.primary.withValues(alpha: 0.04),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Image.asset(asset, width: 38, height: 38),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: secondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: secondaryColor.withValues(alpha: 0.48),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DividerLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 66,
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.05),
    );
  }
}
