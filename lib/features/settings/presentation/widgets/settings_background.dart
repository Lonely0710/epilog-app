import 'package:flutter/material.dart';
import 'package:lava_lamp_effect/lava_lamp_effect.dart';
import '../../../../app/theme/app_theme.dart';

class SettingsBackground extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const SettingsBackground({
    super.key,
    required this.child,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final primaryAlpha = isDark ? 0.13 : 0.16;
    final accentAlpha = isDark ? 0.16 : 0.22;

    final baseColor =
        backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;

    return ColoredBox(
      color: baseColor,
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
                child: disableAnimations
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            center: const Alignment(-0.35, -0.25),
                            radius: 1.15,
                            colors: [
                              AppTheme.primary.withValues(alpha: primaryAlpha),
                              Colors.yellow.withValues(alpha: accentAlpha),
                              Colors.transparent,
                            ],
                            stops: const [0, 0.42, 1],
                          ),
                        ),
                      )
                    : Stack(
                        children: [
                          LavaLampEffect(
                            size: screenSize,
                            color: AppTheme.primary
                                .withValues(alpha: primaryAlpha),
                            lavaCount: 2,
                            speed: 1,
                          ),
                          LavaLampEffect(
                            size: screenSize,
                            color: Colors.yellow.withValues(alpha: accentAlpha),
                            lavaCount: 2,
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
