import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class CircularRating extends StatelessWidget {
  final double rating; // 0.0 to 10.0
  final double size;
  final double strokeWidth;

  final Color? color;
  final Color? trackColor;

  const CircularRating({
    super.key,
    required this.rating,
    this.size = 40,
    this.strokeWidth = 3,
    this.color,
    this.trackColor,
  });

  Color _getRatingColor(double percentage) {
    if (color != null) return color!;
    return AppColors.getRatingColor(percentage);
  }

  Color _getTrackColor(double percentage) {
    if (trackColor != null) return trackColor!;
    return AppColors.getRatingBgColor(percentage);
  }

  @override
  Widget build(BuildContext context) {
    final percentage = (rating * 10).clamp(0, 100).toDouble();
    final color = _getRatingColor(percentage);
    final trackColor = _getTrackColor(percentage);
    final textTheme = Theme.of(context).textTheme;
    final ringSize = size - 6;
    final effectiveStrokeWidth =
        strokeWidth.clamp(2.0, ringSize * 0.1).toDouble();

    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: AppColors.ratingCircleBg,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: ringSize,
            height: ringSize,
            child: CircularProgressIndicator(
              value: 1.0,
              strokeWidth: effectiveStrokeWidth,
              color: trackColor,
            ),
          ),
          SizedBox(
            width: ringSize,
            height: ringSize,
            child: CircularProgressIndicator(
              value: percentage / 100,
              strokeWidth: effectiveStrokeWidth,
              color: color,
              strokeCap: StrokeCap.round,
            ),
          ),
          Transform.translate(
            offset: Offset(size * 0.03, -size * 0.01),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${percentage.round()}',
                  style: textTheme.labelMedium?.copyWith(
                        fontSize: size * 0.38,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textOnDark,
                        height: 1,
                        letterSpacing: 0,
                      ) ??
                      TextStyle(
                        fontSize: size * 0.38,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textOnDark,
                        height: 1,
                        letterSpacing: 0,
                      ),
                ),
                Padding(
                  padding: EdgeInsets.only(top: size * 0.02, left: size * 0.01),
                  child: Text(
                    '%',
                    style: textTheme.labelSmall?.copyWith(
                          fontSize: size * 0.18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textOnDark.withValues(alpha: 0.82),
                          height: 1,
                          letterSpacing: 0,
                        ) ??
                        TextStyle(
                          fontSize: size * 0.18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textOnDark.withValues(alpha: 0.82),
                          height: 1,
                          letterSpacing: 0,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
