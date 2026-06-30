import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../app/theme/app_theme.dart';

class SuccessDialog extends StatefulWidget {
  final VoidCallback onDismiss;

  const SuccessDialog({super.key, required this.onDismiss});

  @override
  State<SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<SuccessDialog>
    with SingleTickerProviderStateMixin {
  late Timer _timer;
  late AnimationController _controller;

  // Particle data
  final List<_Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    // Auto dismiss after 3 seconds
    _timer = Timer(const Duration(seconds: 3), widget.onDismiss);

    // Animation for particles
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Generate random particles
    for (int i = 0; i < 8; i++) {
      _particles.add(_Particle(
        angle: _random.nextDouble() * 2 * pi,
        distance: 50.0 + _random.nextDouble() * 30.0,
        size: 4.0 + _random.nextDouble() * 6.0,
        speed: 0.5 + _random.nextDouble() * 0.5,
      ));
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBgColor = isDark ? const Color(0xFF1A2A3A) : Colors.white;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24.0),
      ),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: dialogBgColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10.0,
              offset: Offset(0.0, 10.0),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            // Header with Particles
            SizedBox(
              height: 140,
              width: 140,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Animated Particles
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: _particles.map((p) {
                          // Calculate position based on time
                          final t =
                              (_controller.value * p.speed) % 1.0; // Loop 0..1
                          final currentDist = p.distance * (0.8 + 0.4 * t);
                          final opacity = 1.0 - t; // Fade out

                          final dx = cos(p.angle) * currentDist;
                          final dy = sin(p.angle) * currentDist;

                          return Positioned(
                            left: 70 + dx - p.size / 2, // 70 is center (140/2)
                            top: 70 + dy - p.size / 2,
                            child: Opacity(
                              opacity: opacity,
                              child: Container(
                                width: p.size,
                                height: p.size,
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(
                                      alpha: 0.4 + 0.6 * _random.nextDouble()),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                  // Main Icon Circle
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFD0BCFF), // Light Purple
                          AppTheme.primary, // Dark Purple
                        ],
                      ),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Title
            const Text(
              "恭喜！",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            // Body
            const Text(
              "您的账号已准备就绪，几秒后将自动跳转到首页。",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            // Loading Indicator
            const SizedBox(
              height: 48,
              width: 48,
              child: CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 4,
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double distance;
  final double size;
  final double speed;

  _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.speed,
  });
}
