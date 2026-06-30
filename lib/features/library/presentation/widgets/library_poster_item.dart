import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../detail/presentation/widgets/watch_status_icon.dart';

/// Individual poster item for the library grid.
/// Displays a rounded movie/anime poster with subtle silver edge border.
class LibraryPosterItem extends StatelessWidget {
  final Media media;
  final VoidCallback? onTap;
  final Object? heroTag;
  final bool showWatchStatus;

  const LibraryPosterItem({
    super.key,
    required this.media,
    this.onTap,
    this.heroTag,
    this.showWatchStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    final watchStatus = media.watchingStatus ?? 'wish';
    final statusColor =
        media.isCollected ? watchStatusColor(watchStatus) : AppTheme.primary;
    final statusIcon = media.isCollected
        ? watchStatusIconData(watchStatus)
        : watchStatusIconData('wish', filled: false);

    final posterCard = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Subtle silver edge border
        border: Border.all(
          color: AppColors.silverEdgeBorder,
          width: 0.8,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Main poster image
            media.posterUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: media.posterUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.surfaceDeep,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.textOnDark.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => _buildErrorWidget(),
                  )
                : _buildErrorWidget(),
            // Subtle gradient overlay for premium feel
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      AppColors.shadowDark.withValues(alpha: 0.1),
                    ],
                    stops: const [0.7, 1.0],
                  ),
                ),
              ),
            ),
            // Inner edge highlight for glass effect
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.subtleGlow.withValues(alpha: 0.08),
                    width: 1,
                  ),
                ),
              ),
            ),
            if (showWatchStatus)
              Positioned(
                left: 8,
                bottom: 8,
                child: _WatchStatusBadge(
                  icon: statusIcon,
                  color: statusColor,
                  isCollected: media.isCollected,
                ),
              ),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: heroTag == null
          ? posterCard
          : Hero(
              tag: heroTag!,
              flightShuttleBuilder: (
                flightContext,
                animation,
                flightDirection,
                fromHeroContext,
                toHeroContext,
              ) {
                final curvedAnimation = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOutCubic,
                  reverseCurve: Curves.easeInOutCubic,
                );

                return FadeTransition(
                  opacity: Tween<double>(begin: 0.94, end: 1.0)
                      .animate(curvedAnimation),
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.985, end: 1.0)
                        .animate(curvedAnimation),
                    child: posterCard,
                  ),
                );
              },
              child: posterCard,
            ),
    );
  }

  Widget _buildErrorWidget() {
    return Image.asset(
      'assets/icons/ic_np_poster.png',
      fit: BoxFit.cover,
    );
  }
}

class _WatchStatusBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isCollected;

  const _WatchStatusBadge({
    required this.icon,
    required this.color,
    required this.isCollected,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF223142).withValues(alpha: 0.88)
            : Colors.white.withValues(alpha: 0.62),
        shape: BoxShape.circle,
        border: Border.all(
          color: isCollected ? color : AppTheme.primary.withValues(alpha: 0.65),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}
