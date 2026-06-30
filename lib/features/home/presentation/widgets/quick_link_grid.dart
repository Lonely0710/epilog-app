import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/widget_previews.dart';
import 'dart:ui' as ui;
import '../../../../app/theme/app_theme.dart';
import '../../../../core/presentation/pages/web_browser_page.dart';

@Preview()
Widget previewQuickLinkGrid() => const QuickLinkGrid();

class QuickLinkGrid extends StatelessWidget {
  const QuickLinkGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: QuickLinkCard(
                  title: '豆瓣电影',
                  subtitle: '热门电影推荐',
                  assetPath: 'assets/icons/ic_douban_green.png',
                  iconBackgroundColor: Colors.green.withValues(alpha: 0.1),
                  onTap: () => context.push(
                    '/webview',
                    extra: WebBrowserPageArgs.fromSiteType(
                      siteType: SiteType.douban,
                      url: 'https://m.douban.com',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: QuickLinkCard(
                  title: 'TMDb',
                  subtitle: '全球影视资讯',
                  assetPath: 'assets/icons/ic_tmdb.png',
                  iconBackgroundColor:
                      const Color(0xFF0D253F).withValues(alpha: 0.1),
                  onTap: () => context.push(
                    '/webview',
                    extra: WebBrowserPageArgs.fromSiteType(
                      siteType: SiteType.tmdb,
                      url: 'https://www.themoviedb.org',
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: QuickLinkCard(
                  title: 'Bangumi',
                  subtitle: '番剧更新',
                  assetPath: 'assets/icons/ic_bangumi.png',
                  iconBackgroundColor: Colors.pinkAccent.withValues(alpha: 0.1),
                  onTap: () => context.push(
                    '/webview',
                    extra: WebBrowserPageArgs.fromSiteType(
                      siteType: SiteType.bangumi,
                      url: 'https://bangumi.tv',
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: QuickLinkCard(
                  title: '我的收藏',
                  subtitle: '查看收藏记录',
                  iconData: Icons.bookmark,
                  iconColor: Colors.amber,
                  iconBackgroundColor:
                      const Color(0xFF0D253F).withValues(alpha: 0.05), // Indigo
                  onTap: () => context.go('/library'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class QuickLinkCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? assetPath;
  final IconData? iconData;
  final Color? iconColor;
  final Color iconBackgroundColor;
  final VoidCallback? onTap;

  const QuickLinkCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.iconBackgroundColor,
    this.assetPath,
    this.iconData,
    this.iconColor,
    this.onTap,
  }) : assert(assetPath != null || iconData != null,
            'Either assetPath or iconData must be provided');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
    final textSecondary =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : AppTheme.textPrimary.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppTheme.background.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.5),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: iconBackgroundColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: assetPath != null
                        ? Image.asset(assetPath!, fit: BoxFit.contain)
                        : Icon(iconData, color: iconColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
