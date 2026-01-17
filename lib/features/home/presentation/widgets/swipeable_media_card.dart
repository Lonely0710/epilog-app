import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/domain/entities/media.dart';
import '../../../../app/theme/app_colors.dart';

class SwipeableMediaCard extends StatelessWidget {
  final Media media;

  const SwipeableMediaCard({
    super.key,
    required this.media,
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
                errorWidget: (context, url, error) => Container(color: Colors.grey[900]),
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
