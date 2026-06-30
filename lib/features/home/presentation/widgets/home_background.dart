import 'package:flutter/material.dart';
import 'package:lava_lamp_effect/lava_lamp_effect.dart';
import '../../../../app/theme/app_theme.dart';

class HomeBackground extends StatelessWidget {
  final Widget child;

  const HomeBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D1B2A) : Colors.white;
    final screenSize = MediaQuery.sizeOf(context);

    return ColoredBox(
      color: bgColor,
      child: Stack(
        children: [
          Positioned.fill(
            child: OverflowBox(
              minWidth: screenSize.width,
              maxWidth: screenSize.width,
              minHeight: screenSize.height,
              maxHeight: screenSize.height,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: screenSize.width,
                height: screenSize.height,
                child: Stack(
                  children: [
                    LavaLampEffect(
                      size: screenSize,
                      color: AppTheme.primary
                          .withValues(alpha: isDark ? 0.4 : 0.3),
                      lavaCount: 3,
                      speed: 1,
                    ),
                    LavaLampEffect(
                      size: screenSize,
                      color: isDark
                          ? Colors.cyan.withValues(alpha: 0.25)
                          : Colors.lightBlue.withValues(alpha: 0.2),
                      lavaCount: 3,
                      speed: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          _KeyboardAwarePadding(child: child),
        ],
      ),
    );
  }
}

class _KeyboardAwarePadding extends StatelessWidget {
  final Widget child;

  const _KeyboardAwarePadding({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: child,
    );
  }
}
