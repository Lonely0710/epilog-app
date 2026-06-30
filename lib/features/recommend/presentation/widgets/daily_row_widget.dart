import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/presentation/pages/web_browser_page.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/presentation/widgets/shared_dialog_button.dart';

class DailyRowWidget extends StatelessWidget {
  final String dayKey;
  final List<Media> animeList;

  const DailyRowWidget({
    super.key,
    required this.dayKey,
    required this.animeList,
  });

  @override
  Widget build(BuildContext context) {
    final isToday = _isToday(dayKey);
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Header
          _buildDayHeader(context, isToday: isToday),

          const SizedBox(width: 8),

          // Anime List
          Expanded(
            child: SizedBox(
              height: 190,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: animeList.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final anime = animeList[index];
                  return _buildAnimeItem(context, anime);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeader(BuildContext context, {required bool isToday}) {
    String assetName;
    String label = '';
    String subLabel = ''; // e.g., 曜日
    switch (dayKey) {
      case 'Sun':
        assetName = 'ic_week_sun.png';
        label = '日';
        subLabel = '曜日';
        break;
      case 'Mon':
        assetName = 'ic_week_mon.png';
        label = '月';
        subLabel = '曜日';
        break;
      case 'Tue':
        assetName = 'ic_week_tue.png';
        label = '火';
        subLabel = '曜日';
        break;
      case 'Wed':
        assetName = 'ic_week_wed.png';
        label = '水';
        subLabel = '曜日';
        break;
      case 'Thu':
        assetName = 'ic_week_thu.png';
        label = '木';
        subLabel = '曜日';
        break;
      case 'Fri':
        assetName = 'ic_week_fri.png';
        label = '金';
        subLabel = '曜日';
        break;
      case 'Sat':
        assetName = 'ic_week_sat.png';
        label = '土';
        subLabel = '曜日';
        break;
      default:
        assetName = 'ic_week_sun.png';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Image Header
        Container(
          width: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/header/$assetName',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Stats Row with frosted glass background
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.surfaceDark.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowDark.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontFamily: 'HanSerifSC', // Use custom font
                  ),
                  children: [
                    TextSpan(
                      text: label,
                      style: TextStyle(
                        fontWeight: isToday ? FontWeight.w800 : FontWeight.w400,
                        fontSize: 13,
                        color: _getDayColor(dayKey),
                      ),
                    ),
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: subLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.color, // Base color for "共" and "部"
                    fontFamily: 'FangZheng', // Use custom font
                  ),
                  children: [
                    const TextSpan(text: '共 '),
                    TextSpan(
                      text: '${animeList.length}',
                      style: TextStyle(
                        fontSize: 12, // Larger font for number
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.color, // Darker color for number
                      ),
                    ),
                    const TextSpan(text: ' 部'),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Divider line
        Container(
          width: 120,
          height: 2,
          decoration: BoxDecoration(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
              boxShadow: [
                BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
                    blurRadius: 2,
                    offset: const Offset(0, 1))
              ]),
        )
      ],
    );
  }

  Color _getDayColor(String key) {
    switch (key) {
      case 'Sun':
        return AppColors.weekSun;
      case 'Mon':
        return AppColors.weekMon;
      case 'Tue':
        return AppColors.weekTue;
      case 'Wed':
        return AppColors.weekWed;
      case 'Thu':
        return AppColors.weekThu;
      case 'Fri':
        return AppColors.weekFri;
      case 'Sat':
        return AppColors.weekSat;
      default:
        return AppColors.textPrimary;
    }
  }

  bool _isToday(String key) {
    const orderedKeys = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final todayKey = orderedKeys[DateTime.now().weekday - 1];
    return key == todayKey;
  }

  Widget _buildAnimeItem(BuildContext context, Media anime) {
    return GestureDetector(
      onTap: () {
        _showBangumiDialog(context, anime);
      },
      child: Container(
        width: 120, // Slightly wider for better aspect ratio
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowDark.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              // Background Image
              Positioned.fill(
                child: CachedNetworkImage(
                  imageUrl: anime.posterUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: AppColors.surfaceVariant,
                    child: Center(
                        child: Icon(Icons.image,
                            size: 20, color: AppColors.textTertiary)),
                  ),
                  errorWidget: (context, url, error) => Image.asset(
                    'assets/icons/ic_np_poster.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // Gradient Overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 60,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(
                            alpha:
                                0.8), // Keep black for readability over image
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Text Content
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      anime.titleZh,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 1),
                            blurRadius: 2,
                            color: Colors.black,
                          ),
                        ],
                      ),
                    ),
                    if (anime.titleOriginal.isNotEmpty)
                      Text(
                        anime.titleOriginal,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.9),
                          shadows: [
                            Shadow(
                              offset: Offset(0, 1),
                              blurRadius: 2,
                              color: Colors.black,
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBangumiDialog(BuildContext context, Media anime) {
    showDialog(
      context: context,
      builder: (context) {
        final today = DateTime.now();
        final musumeIndex = today.weekday % 7;
        final alignX = -1.0 + (musumeIndex / 3.0);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final textColor =
            Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black;
        final title =
            anime.titleZh.isNotEmpty ? anime.titleZh : anime.titleOriginal;

        return AppDialog(
          title: '正在前往',
          contentAlignment: CrossAxisAlignment.center,
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Transform.translate(
                  offset: const Offset(0, -14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Center(
                        child: Image.asset(
                          'assets/images/bg_logo_riff.png',
                          height: 38,
                          fit: BoxFit.contain,
                          color: isDark ? null : AppColors.sourceBangumi,
                          colorBlendMode: isDark ? null : BlendMode.srcIn,
                          errorBuilder: (context, error, stackTrace) {
                            return Text(
                              'Bangumi',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: AppColors.sourceBangumi,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0,
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                          letterSpacing: 0,
                          fontFamily: 'FangZheng',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 50,
                height: 100,
                child: ClipRect(
                  child: Image.asset(
                    'assets/images/bg_musume.png',
                    fit: BoxFit.cover,
                    alignment: Alignment(alignX, 0.0),
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Icon(
                          Icons.person_rounded,
                          color: AppColors.textTertiary,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          secondaryAction: AppDialogAction(
            text: '留在本页',
            color: AppColors.textSecondary,
            variant: SharedDialogButtonVariant.secondary,
            onPressed: () => Navigator.pop(context),
          ),
          primaryAction: AppDialogAction(
            text: '确认',
            color: AppColors.sourceBangumi,
            variant: SharedDialogButtonVariant.primary,
            onPressed: () {
              Navigator.pop(context);
              _launchBangumi(context, anime);
            },
          ),
        );
      },
    );
  }

  void _launchBangumi(BuildContext context, Media anime) {
    // User requested specific URL format for Bangumi items
    final url = 'https://bangumi.tv/subject/${anime.sourceId}';

    final args = WebBrowserPageArgs.fromSiteType(
      siteType: SiteType.bangumi,
      url: url,
    );

    context.push('/webview', extra: args);
  }
}
