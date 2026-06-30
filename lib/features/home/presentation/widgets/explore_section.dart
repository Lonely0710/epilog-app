import 'dart:math';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/widget_previews.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/presentation/pages/web_browser_page.dart';

@Preview()
Widget previewExploreSection() => const ExploreSection();

class ExploreSection extends StatelessWidget {
  const ExploreSection({super.key});

  void _openRandomWebsite(BuildContext context) {
    final random = Random();
    final sites = SiteType.values.where((s) => s != SiteType.other).toList();
    final randomSite = sites[random.nextInt(sites.length)];

    final randomId = _generateRandomId(randomSite, random);
    String? mediaType;
    if (randomSite == SiteType.tmdb) {
      mediaType = random.nextBool() ? 'movie' : 'tv';
    }

    final fullUrl = _buildFullUrl(randomSite, randomId, mediaType);

    context.push(
      '/webview',
      extra: WebBrowserPageArgs.fromSiteType(
        siteType: randomSite,
        url: fullUrl,
      ),
    );
  }

  String _generateRandomId(SiteType site, Random random) {
    switch (site) {
      case SiteType.douban:
        // 10000000 - 99999999
        return (random.nextInt(90000000) + 10000000).toString();
      case SiteType.tmdb:
        // 1000 - 901000
        return (random.nextInt(900000) + 1000).toString();
      case SiteType.bangumi:
        // 1 - 300000
        return (random.nextInt(300000) + 1).toString();
      case SiteType.maoyan:
        // Maoyan IDs vary, simple random range for exploration demo
        return (random.nextInt(1500000) + 1).toString();
      case SiteType.other:
        return '';
    }
  }

  String _buildFullUrl(SiteType site, String id, String? mediaType) {
    switch (site) {
      case SiteType.douban:
        return 'https://movie.douban.com/subject/$id';
      case SiteType.tmdb:
        if (mediaType == null || id.isEmpty) {
          return 'https://www.themoviedb.org';
        }
        return 'https://www.themoviedb.org/$mediaType/$id';
      case SiteType.bangumi:
        return 'https://bangumi.tv/subject/$id';
      case SiteType.maoyan:
        return 'https://m.maoyan.com/movie/$id';
      case SiteType.other:
        return 'https://www.bing.com';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.public,
              size: 40,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '开始浏览',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击上方快速链接或使用搜索栏开始探索影视世界',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 200,
            child: ElevatedButton.icon(
              onPressed: () => _openRandomWebsite(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                elevation: 4,
                shadowColor: AppTheme.primary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                textStyle: const TextStyle(
                  inherit: false,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.1,
                  color: Colors.white,
                ),
              ),
              icon: const Icon(Icons.send, size: 18),
              label: const Text('随便逛逛'),
            ),
          ),
        ],
      ),
    );
  }
}
