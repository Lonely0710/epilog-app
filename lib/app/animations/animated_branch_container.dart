import 'package:flutter/material.dart';

/// A container that animates between branches using a "Fade Through" pattern
/// while preserving the state of the branches (by keeping them in the tree).
class AnimatedBranchContainer extends StatefulWidget {
  final int currentIndex;
  final List<Widget> children;
  final Set<int> instantSwitchIndices;

  const AnimatedBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
    this.instantSwitchIndices = const {},
  });

  @override
  State<AnimatedBranchContainer> createState() =>
      _AnimatedBranchContainerState();
}

class _AnimatedBranchContainerState extends State<AnimatedBranchContainer>
    with TickerProviderStateMixin {
  late List<AnimationController> _faders;

  @override
  void initState() {
    super.initState();
    _faders = List.generate(
      widget.children.length,
      (index) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300), // Fade Through duration
      ),
    );

    // Initial state: Only current index is visible
    for (var i = 0; i < _faders.length; i++) {
      if (i == widget.currentIndex) {
        _faders[i].value = 1.0;
      } else {
        _faders[i].value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _faders) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(AnimatedBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.currentIndex != oldWidget.currentIndex) {
      final shouldSwitchInstantly =
          widget.instantSwitchIndices.contains(oldWidget.currentIndex) ||
              widget.instantSwitchIndices.contains(widget.currentIndex);

      if (shouldSwitchInstantly) {
        for (var i = 0; i < _faders.length; i++) {
          _faders[i].value = i == widget.currentIndex ? 1.0 : 0.0;
        }
      } else {
        _faders[oldWidget.currentIndex].reverse();
        _faders[widget.currentIndex].forward();
      }
    }

    // Handle children count change if necessary (unlikely for fixed tabs)
    if (widget.children.length != _faders.length) {
      // Re-initialize if length changed (edge case)
      for (var controller in _faders) {
        controller.dispose();
      }
      _faders = List.generate(
        widget.children.length,
        (index) => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 300),
        ),
      );
      _faders[widget.currentIndex].value = 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.children.length, (index) {
        final child = widget.children[index];
        final controller = _faders[index];

        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            // Optimization: Maintain state but don't paint/process hits if invisible
            // We use Offstage to completely hide it when fully dismissed (controller.isDismissed)
            // But we must check if it's the target index to avoid race conditions.
            // Actually, keep it simple: IgnorePointer when opacity < 1?
            // Better: Offstage when opacity == 0, UNLESS it's the target index (forwarding)

            final bool isVisible = controller.value > 0;

            return Offstage(
              offstage: !isVisible,
              child: IgnorePointer(
                ignoring: controller.value <
                    1.0, // Only interactable when fully visible?
                // Fade Through spec: Incoming elements are not interactive until fully entered?
                // Usually standard interaction is fine once visible.
                // Let's safe guard: allow interaction if opacity > 0.5?
                // Standard IndexedStack behaviors: only top is interactive.
                // Here multiple might be visible during transition.
                // Let's stick to standard Opacity.
                child: FadeTransition(
                  opacity: controller,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                      CurvedAnimation(
                        parent: controller,
                        curve: Curves.easeOut,
                      ),
                    ),
                    child: child,
                  ),
                ),
              ),
            );
          },
          child: child,
        );
      }),
    );
  }
}
