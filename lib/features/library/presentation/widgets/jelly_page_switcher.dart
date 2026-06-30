import 'package:flutter/material.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart';

class JellyPageSwitcher extends StatefulWidget {
  final bool isAnimeWall;
  final VoidCallback onToggle;
  final double size;
  final String? tooltip;

  const JellyPageSwitcher({
    super.key,
    required this.isAnimeWall,
    required this.onToggle,
    this.size = 48,
    this.tooltip,
  });

  @override
  State<JellyPageSwitcher> createState() => _JellyPageSwitcherState();
}

class _JellyPageSwitcherState extends State<JellyPageSwitcher> {
  final LucideAnimatedIconController _iconController =
      LucideAnimatedIconController();

  void _handleTap() {
    _iconController.animate();
    widget.onToggle();
  }

  @override
  void dispose() {
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        widget.isAnimeWall ? const Color(0xFFF4A817) : const Color(0xFFCD2525);

    return Tooltip(
      message: widget.tooltip ?? (widget.isAnimeWall ? '切换到影视资料库' : '切换到动漫墙'),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleTap,
          borderRadius: BorderRadius.circular(widget.size / 2),
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: backgroundColor.withValues(alpha: isDark ? 0.92 : 0.88),
              borderRadius: BorderRadius.circular(widget.size / 2),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.34),
              ),
              boxShadow: [
                BoxShadow(
                  color: backgroundColor.withValues(alpha: 0.28),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) {
                return RotationTransition(
                  turns:
                      Tween<double>(begin: 0.75, end: 1.0).animate(animation),
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: LucideAnimatedIcon(
                key: ValueKey(widget.isAnimeWall),
                icon: contrast,
                color: Colors.white,
                size: widget.size * 0.48,
                trigger: AnimationTrigger.manual,
                controller: _iconController,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
