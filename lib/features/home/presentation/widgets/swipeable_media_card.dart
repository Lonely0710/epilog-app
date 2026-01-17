import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../../app/theme/app_colors.dart';

class SwipeableMediaCard extends StatelessWidget {
  final Media media;
  final int percentX;
  final int percentY;

  const SwipeableMediaCard({
    super.key,
    required this.media,
    this.percentX = 0,
    this.percentY = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            if (media.posterUrl.isNotEmpty)
              CachedNetworkImage(
                imageUrl: media.posterUrl,
                fit: BoxFit.cover,
                errorWidget: (context, url, error) => Image.asset(
                  'assets/icons/ic_np_poster.png',
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(color: AppColors.primary),

            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.8),
                  ],
                  stops: const [0.5, 0.7, 1.0],
                ),
              ),
            ),

            // Maoyan Release Date Seal
            if (media.sourceType == 'maoyan' && media.releaseDate.isNotEmpty)
              Positioned(
                top: 12,
                left: 12,
                child: _buildReleaseDateSeal(media.releaseDate),
              ),

            // Swipe Indicators
            _buildSwipeIndicators(),

            // Text Content
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _getSourceBgColor(media.sourceType),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: _buildSourceIcon(media.sourceType),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    media.titleZh,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(blurRadius: 8, color: Colors.black, offset: Offset(0, 2)),
                      ],
                    ),
                  ),
                  if (media.rating > 0) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          media.rating.toStringAsFixed(1),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                  if (media.summary.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      media.summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwipeIndicators() {
    // Opacity calculation based on swipe percentage
    // We assume 100 is fully swiped? Or maybe closer to 50 is enough to show fully.
    // Let's use a threshold to start showing, and cap at 1.0.

    // Check direction priority: vertical takes precedence if Y > X?
    // Usually horizontal swipes are distinct from vertical.

    // Right Swipe (Add to Wishlist)
    if (percentX > 0 && percentX.abs() > percentY.abs()) {
      final opacity = (percentX / 100).clamp(0.0, 1.0);
      if (opacity < 0.1) return const SizedBox.shrink();

      return Positioned(
        top: 24,
        left: 24, // Show on Left side/Top when swiping Right
        child: Opacity(
          opacity: opacity,
          child: _buildIndicator(
            icon: Icons.check_circle,
            color: Colors.white,
            backgroundColor: AppColors.starActive,
            text: '加入想看',
          ),
        ),
      );
    }

    // Left Swipe (Not Interested - Left Edge)
    if (percentX < 0 && percentX.abs() > percentY.abs()) {
      final opacity = (percentX.abs() / 100).clamp(0.0, 1.0);
      if (opacity < 0.1) return const SizedBox.shrink();

      return Positioned(
        top: 24,
        right: 24, // Show on Right side when swiping Left
        child: Opacity(
          opacity: opacity,
          child: _buildIndicator(
            icon: Icons.cancel,
            color: Colors.white,
            backgroundColor: Colors.grey,
            text: '不感兴趣',
          ),
        ),
      );
    }

    // Up Swipe (Not Interested - Top Edge?? Or Bottom?)
    // If we swipe UP, the card moves UP. Indicator usually visually at the BOTTOM (revealed) or TOP?
    // User said "closest to the sliding area edge".
    // Swipe Up -> Top edge involves.
    if (percentY < 0 && percentY.abs() > percentX.abs()) {
      final opacity = (percentY.abs() / 100).clamp(0.0, 1.0);
      if (opacity < 0.1) return const SizedBox.shrink();

      return Positioned(
        bottom: 120, // Positioned near bottom to be visible relative to swipe? Or center?
        left: 0,
        right: 0,
        child: Center(
          child: Opacity(
            opacity: opacity,
            child: _buildIndicator(
              icon: Icons.cancel,
              color: Colors.white,
              backgroundColor: Colors.grey,
              text: '不感兴趣',
            ),
          ),
        ),
      );
    }

    // Down Swipe (Not Interested)
    if (percentY > 0 && percentY.abs() > percentX.abs()) {
      final opacity = (percentY.abs() / 100).clamp(0.0, 1.0);
      if (opacity < 0.1) return const SizedBox.shrink();

      return Positioned(
        top: 60,
        left: 0,
        right: 0,
        child: Center(
          child: Opacity(
            opacity: opacity,
            child: _buildIndicator(
              icon: Icons.cancel,
              color: Colors.white,
              backgroundColor: Colors.grey,
              text: '不感兴趣',
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildIndicator({
    required IconData icon,
    required Color color,
    required Color backgroundColor,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSourceBgColor(String type) {
    switch (type) {
      case 'tmdb':
        return AppColors.sourceTmdb;
      case 'maoyan':
        return Colors.white; // White background for Maoyan icon
      case 'bgm':
        return AppColors.sourceBangumi.withValues(alpha: 0.9);
      default:
        return AppColors.primary.withValues(alpha: 0.8);
    }
  }

  Widget _buildSourceIcon(String type) {
    String iconPath;
    double size = 20;

    switch (type) {
      case 'tmdb':
        iconPath = 'assets/icons/ic_tmdb.png';
        break;
      case 'maoyan':
        iconPath = 'assets/icons/ic_maoyan.png';
        break;
      case 'bgm':
        iconPath = 'assets/icons/ic_bangumi_fill.png';
        break;
      default:
        // Fallback to text for unknown sources
        return Text(
          type.toUpperCase(),
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
        );
    }

    return Image.asset(
      iconPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  Widget _buildReleaseDateSeal(String releaseDate) {
    // Validate date format
    if (releaseDate.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // SVG Seal Icon - Horizontally flipped
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.rotationY(3.14159), // Flip horizontally (π radians)
            child: SvgPicture.asset(
              'assets/icons/ic_seal_date.svg',
              width: 130,
              height: 130,
              colorFilter: ColorFilter.mode(
                Colors.white.withValues(alpha: 0.7),
                BlendMode.srcIn,
              ),
            ),
          ),
          // Date Text Overlay
          Transform.rotate(
            angle: -0.55,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              constraints: const BoxConstraints(maxWidth: 85), // Constrain width
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  releaseDate,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.2,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
