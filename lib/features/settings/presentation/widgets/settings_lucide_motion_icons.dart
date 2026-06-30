import 'dart:math' as math;
import 'package:flutter/material.dart';

enum SettingsMotionIconType {
  delete,
  cloudDownload,
  sun,
  settings,
  webhook,
}

class SettingsLucideMotionIcon extends StatefulWidget {
  final SettingsMotionIconType type;
  final Color color;
  final double size;
  final int animationTick;

  const SettingsLucideMotionIcon({
    super.key,
    required this.type,
    required this.color,
    required this.size,
    required this.animationTick,
  });

  @override
  State<SettingsLucideMotionIcon> createState() =>
      _SettingsLucideMotionIconState();
}

class _SettingsLucideMotionIconState extends State<SettingsLucideMotionIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    );
  }

  @override
  void didUpdateWidget(SettingsLucideMotionIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animationTick != widget.animationTick) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.forward(from: 0).then((_) {
            if (mounted) {
              _controller.reverse();
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          return CustomPaint(
            painter: _SettingsLucideMotionIconPainter(
              type: widget.type,
              color: widget.color,
              progress: _animation.value,
            ),
          );
        },
      ),
    );
  }
}

class _SettingsLucideMotionIconPainter extends CustomPainter {
  final SettingsMotionIconType type;
  final Color color;
  final double progress;

  _SettingsLucideMotionIconPainter({
    required this.type,
    required this.color,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.scale(scale);

    switch (type) {
      case SettingsMotionIconType.delete:
        _paintDelete(canvas, paint);
      case SettingsMotionIconType.cloudDownload:
        _paintCloudDownload(canvas, paint);
      case SettingsMotionIconType.sun:
        _paintSun(canvas, paint);
      case SettingsMotionIconType.settings:
        _paintSettings(canvas, paint);
      case SettingsMotionIconType.webhook:
        _paintWebhook(canvas, paint);
    }

    canvas.restore();
  }

  void _paintDelete(Canvas canvas, Paint paint) {
    final lidY = -1.1 * progress;
    final bodyTopY = 8 + progress;
    final lineOffsetY = 0.5 * progress;

    canvas.save();
    canvas.translate(0, lidY);
    canvas.drawLine(const Offset(3, 6), const Offset(21, 6), paint);
    _drawDeleteHandle(canvas, paint);
    canvas.restore();

    _drawDeleteBody(canvas, paint, bodyTopY);
    canvas.drawLine(
      Offset(10, 11 + lineOffsetY),
      Offset(10, 17 + lineOffsetY),
      paint,
    );
    canvas.drawLine(
      Offset(14, 11 + lineOffsetY),
      Offset(14, 17 + lineOffsetY),
      paint,
    );
  }

  void _paintCloudDownload(Canvas canvas, Paint paint) {
    _drawCloud(canvas, paint);

    final arrowY = 2 * (1 - _springOut(_pingPong(progress)));
    canvas.save();
    canvas.translate(0, arrowY);
    final arrowLeft = Path()
      ..moveTo(12, 13)
      ..lineTo(12, 21)
      ..lineTo(8, 17);
    final arrowRight = Path()
      ..moveTo(12, 21)
      ..lineTo(16, 17);
    canvas.drawPath(arrowLeft, paint);
    canvas.drawPath(arrowRight, paint);
    canvas.restore();
  }

  void _paintSun(Canvas canvas, Paint paint) {
    canvas.drawCircle(const Offset(12, 12), 4, paint);

    final visibleProgress = progress == 0 ? 1.0 : progress;
    final rays = <(Offset, Offset)>[
      (const Offset(12, 2), const Offset(12, 4)),
      (const Offset(19.07, 4.93), const Offset(17.66, 6.34)),
      (const Offset(20, 12), const Offset(22, 12)),
      (const Offset(17.66, 17.66), const Offset(19.07, 19.07)),
      (const Offset(12, 20), const Offset(12, 22)),
      (const Offset(6.34, 17.66), const Offset(4.93, 19.07)),
      (const Offset(2, 12), const Offset(4, 12)),
      (const Offset(4.93, 4.93), const Offset(6.34, 6.34)),
    ];

    for (var index = 0; index < rays.length; index++) {
      final delayed =
          ((visibleProgress - (index + 1) * 0.08) / 0.28).clamp(0.0, 1.0);
      final rayPaint = Paint()
        ..color = color.withValues(alpha: Curves.easeOut.transform(delayed))
        ..style = PaintingStyle.stroke
        ..strokeWidth = paint.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawLine(rays[index].$1, rays[index].$2, rayPaint);
    }
  }

  void _paintSettings(Canvas canvas, Paint paint) {
    canvas.drawCircle(const Offset(12, 12), 3.2, paint);

    const spokes = <(Offset, Offset)>[
      (Offset(12, 2), Offset(12, 5)),
      (Offset(18.2, 5.2), Offset(16.1, 7.3)),
      (Offset(22, 12), Offset(19, 12)),
      (Offset(18.2, 18.8), Offset(16.1, 16.7)),
      (Offset(12, 22), Offset(12, 19)),
      (Offset(5.8, 18.8), Offset(7.9, 16.7)),
      (Offset(2, 12), Offset(5, 12)),
      (Offset(5.8, 5.2), Offset(7.9, 7.3)),
    ];

    for (final spoke in spokes) {
      canvas.drawLine(spoke.$1, spoke.$2, paint);
    }
  }

  void _paintWebhook(Canvas canvas, Paint paint) {
    canvas.drawCircle(const Offset(7.5, 7.5), 3.2, paint);
    canvas.drawCircle(const Offset(7.5, 16.5), 3.2, paint);
    canvas.drawCircle(const Offset(16.5, 12), 3.2, paint);

    canvas.drawLine(const Offset(10.2, 9.2), const Offset(14.0, 10.9), paint);
    canvas.drawLine(const Offset(10.2, 14.8), const Offset(14.0, 13.1), paint);
    canvas.drawLine(const Offset(10.6, 10.2), const Offset(10.6, 13.8), paint);
  }

  void _drawDeleteHandle(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(8, 6)
      ..lineTo(8, 4)
      ..cubicTo(8, 3, 9, 2, 10, 2)
      ..lineTo(14, 2)
      ..cubicTo(15, 2, 16, 3, 16, 4)
      ..lineTo(16, 6);
    canvas.drawPath(path, paint);
  }

  void _drawDeleteBody(Canvas canvas, Paint paint, double topY) {
    final path = Path()
      ..moveTo(19, topY)
      ..lineTo(19, 20)
      ..cubicTo(19, 21, 18, 22, 17, 22)
      ..lineTo(7, 22)
      ..cubicTo(6, 22, 5, 21, 5, 20)
      ..lineTo(5, topY);
    canvas.drawPath(path, paint);
  }

  void _drawCloud(Canvas canvas, Paint paint) {
    final path = Path()
      ..moveTo(4.2, 15.1)
      ..cubicTo(2.9, 13.9, 2.3, 12.0, 2.9, 10.1)
      ..cubicTo(3.9, 6.9, 7.2, 4.9, 10.5, 5.4)
      ..cubicTo(12.8, 5.7, 14.7, 6.9, 15.71, 8)
      ..lineTo(17.5, 8)
      ..cubicTo(20.0, 8, 22.0, 10.0, 22.0, 12.5)
      ..cubicTo(22.0, 14.2, 21.2, 15.5, 20.0, 16.2);

    canvas.drawPath(path, paint);
  }

  double _pingPong(double value) {
    if (value <= 0.5) {
      return value * 2;
    }
    return (1 - value) * 2;
  }

  double _springOut(double value) {
    final clamped = value.clamp(0.0, 1.0);
    return 1 - math.pow(1 - clamped, 3).toDouble();
  }

  @override
  bool shouldRepaint(covariant _SettingsLucideMotionIconPainter oldDelegate) {
    return oldDelegate.type != type ||
        oldDelegate.color != color ||
        oldDelegate.progress != progress;
  }
}
