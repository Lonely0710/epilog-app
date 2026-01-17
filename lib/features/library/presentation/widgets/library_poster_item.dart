import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../../app/theme/app_colors.dart';

/// Individual poster item for the library grid.
/// Displays a rounded movie/anime poster with subtle silver edge border.
class LibraryPosterItem extends StatelessWidget {
  final Media media;
  final VoidCallback? onTap;

  const LibraryPosterItem({
    super.key,
    required this.media,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.textOnDark.withValues(alpha: 0.3)),
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
            ],
          ),
        ),
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
