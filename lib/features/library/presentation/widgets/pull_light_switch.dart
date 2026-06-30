import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';

class PullLightSwitch extends StatefulWidget {
  final Offset anchorOffset;
  final ValueChanged<bool> onToggle;
  final bool isDark;

  const PullLightSwitch({
    super.key,
    required this.anchorOffset,
    required this.onToggle,
    required this.isDark,
  });

  @override
  State<PullLightSwitch> createState() => _PullLightSwitchState();
}

class _PullLightSwitchState extends State<PullLightSwitch>
    with TickerProviderStateMixin {
  AnimationController? _springController;
  AnimationController? _bounceController;

  // Physics state
  double _pullDistance = 0.0;
  double _bounceOffset = 0.0; // Inertia bounce offset

  final double _restLength = 30.0;
  final double _triggerDistance = 88.0;
  final double _maxStretch = 290.0;

  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    if (_isInitialized) return;

    // Initialize all controllers
    _springController = AnimationController(
      vsync: this,
      upperBound: 760,
    );

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1650),
    );

    // Add listeners
    _springController!.addListener(() {
      if (mounted) {
        setState(() {
          _pullDistance = _springController!.value;
        });
      }
    });

    _bounceController!.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    _isInitialized = true;
  }

  @override
  void dispose() {
    _springController?.dispose();
    _bounceController?.dispose();
    super.dispose();
  }

  void _onPanStart(DragStartDetails details) {
    _initializeControllers(); // Ensure initialized
    _springController?.stop();
    _bounceController?.stop();
    _bounceOffset = 0.0;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      // Vertical pull only - with smooth non-linear resistance
      double deltaY = details.delta.dy;

      // Use quadratic easing curve for smoother damping
      // The further pulled, the smoother resistance grows (won't suddenly become stiff)
      double pullRatio = (_pullDistance / _maxStretch).clamp(0.0, 1.0);
      // Smooth easing curve: 1 - (x^2) instead of linear decrease
      double resistance = 1.0 - (pullRatio * pullRatio * 0.62);

      // When pushing up (negative), less resistance for smoother feel
      if (deltaY < 0) {
        resistance = 1.0 + pullRatio * 0.08;
      }

      double newDistance = _pullDistance + deltaY * resistance;
      _pullDistance = newDistance.clamp(0.0, _maxStretch);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    // Check toggle trigger
    if (_pullDistance > _triggerDistance) {
      widget.onToggle(!widget.isDark);
      HapticFeedback.mediumImpact();
    }

    // Record release velocity
    final releaseVelocity = details.velocity.pixelsPerSecond.dy;
    final currentPull = _pullDistance;

    final verticalSimulation = SpringSimulation(
      SpringDescription(
        mass: 1.55,
        stiffness: 24.0,
        damping: 10.8,
      ),
      _pullDistance,
      0.0,
      releaseVelocity * 0.08,
    );

    _springController?.animateWith(verticalSimulation);

    // Start inertia bounce animation for the bulb
    if (currentPull > 15) {
      _startBounceAnimation(currentPull, releaseVelocity);
    }
  }

  // Start inertia bounce animation - bulb gently bounces up and down
  void _startBounceAnimation(double pullDistance, double velocity) {
    _bounceController?.stop();
    _bounceController?.reset();

    // Calculate bounce amplitude based on pull distance and velocity
    double bounceAmplitude = (pullDistance * 0.11) + (velocity.abs() * 0.006);
    bounceAmplitude = bounceAmplitude.clamp(5.0, 18.0);

    // Multi-phase bounce animation simulating inertia
    Animation<double> bounceAnim = TweenSequence<double>([
      // Phase 1: Quick rebound overshoots upward (negative = shorter rope)
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -bounceAmplitude)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 24,
      ),
      // Phase 2: Slow drop back down past rest position
      TweenSequenceItem(
        tween:
            Tween<double>(begin: -bounceAmplitude, end: bounceAmplitude * 0.62)
                .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 26,
      ),
      // Phase 3: Gentle bounce back up
      TweenSequenceItem(
        tween: Tween<double>(
                begin: bounceAmplitude * 0.62, end: -bounceAmplitude * 0.36)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 18,
      ),
      // Phase 4: Small bounce down
      TweenSequenceItem(
        tween: Tween<double>(
                begin: -bounceAmplitude * 0.36, end: bounceAmplitude * 0.16)
            .chain(CurveTween(curve: Curves.easeInOutSine)),
        weight: 14,
      ),
      // Phase 5: Settle to rest
      TweenSequenceItem(
        tween: Tween<double>(begin: bounceAmplitude * 0.16, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 18,
      ),
    ]).animate(_bounceController!);

    bounceAnim.addListener(() {
      if (mounted) {
        _bounceOffset = bounceAnim.value;
      }
    });

    _bounceController?.forward();
  }

  @override
  Widget build(BuildContext context) {
    // Calculate handle position - vertical only, no rotation
    // Apply bounce offset for inertia effect
    final easedPull = Curves.easeOutCubic.transform(
      (_pullDistance / _maxStretch).clamp(0.0, 1.0),
    );
    final currentLength =
        _restLength + (easedPull * _maxStretch * 0.96) + _bounceOffset;

    // Handle hangs straight down from anchor
    final handlePosition = widget.anchorOffset + Offset(0, currentLength);

    return Stack(
      children: [
        // Rope
        IgnorePointer(
          child: CustomPaint(
            size: Size.infinite,
            painter: RopePainter(
              anchor: widget.anchorOffset,
              tip: handlePosition,
              color: widget.isDark
                  ? AppColors.textOnDark.withValues(alpha: 0.5)
                  : AppColors.textPrimary.withValues(alpha: 0.8),
            ),
          ),
        ),

        // Handle - vertical drag only
        Positioned(
          left: handlePosition.dx - 22,
          top: handlePosition.dy,
          child: GestureDetector(
            onVerticalDragStart: _onVerticalDragStart,
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: _buildHandle(widget.isDark),
          ),
        ),
      ],
    );
  }

  // Wrapper methods for vertical-only drag gestures
  void _onVerticalDragStart(DragStartDetails details) {
    _onPanStart(details);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _onPanUpdate(details);
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    _onPanEnd(details);
  }

  Widget _buildHandle(bool isDark) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? AppColors.bulbOn : AppColors.bulbOff,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          if (isDark)
            BoxShadow(
              color: AppColors.bulbBorderOn.withValues(alpha: 0.5),
              blurRadius: 20,
              spreadRadius: 2,
            ),
        ],
        border: Border.all(
          color: isDark ? AppColors.bulbBorderOn : AppColors.bulbBorderOff,
          width: 2.0,
        ),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.lightbulb_rounded,
        color: isDark ? AppColors.bulbIconOn : AppColors.bulbIconOff,
        size: 24,
      ),
    );
  }
}

class RopePainter extends CustomPainter {
  final Offset anchor;
  final Offset tip;
  final Color color;

  RopePainter({
    required this.anchor,
    required this.tip,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw straight line for the taut rope
    canvas.drawLine(anchor, tip, paint);

    // Draw anchor dot
    canvas.drawCircle(anchor, 3.0, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant RopePainter oldDelegate) {
    return anchor != oldDelegate.anchor ||
        tip != oldDelegate.tip ||
        color != oldDelegate.color;
  }
}
