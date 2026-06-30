import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../presentation/widgets/shared_app_bar.dart';

/// InheritedWidget to provide nav visibility control to child widgets
class NavVisibilityController extends InheritedWidget {
  final VoidCallback toggleNavVisibility;
  final void Function(bool) setNavVisibility;
  final bool isNavVisible;
  final int currentIndex;

  const NavVisibilityController({
    super.key,
    required this.toggleNavVisibility,
    required this.setNavVisibility,
    required this.isNavVisible,
    required this.currentIndex,
    required super.child,
  });

  static NavVisibilityController? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<NavVisibilityController>();
  }

  @override
  bool updateShouldNotify(NavVisibilityController oldWidget) {
    return isNavVisible != oldWidget.isNavVisible ||
        currentIndex != oldWidget.currentIndex;
  }
}

class ScaffoldWithNavBar extends StatefulWidget {
  const ScaffoldWithNavBar({required this.navigationShell, Key? key})
      : super(key: key ?? const ValueKey<String>('ScaffoldWithNavBar'));

  final StatefulNavigationShell navigationShell;

  @override
  State<ScaffoldWithNavBar> createState() => _ScaffoldWithNavBarState();
}

class _ScaffoldWithNavBarState extends State<ScaffoldWithNavBar>
    with TickerProviderStateMixin {
  bool _isNavVisible = true;
  late AnimationController _visibilityController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Animation controller for tab switching
  late AnimationController _tabAnimationController;
  late Animation<double> _tabAnimation;
  int _previousIndex = 0;

  late AnimationController _appBarVisibilityController;
  late Animation<double> _appBarVisibilityAnimation;

  // Drag state
  double? _dragValue;

  // Store the fractional position when drag ends to use as animation start
  double? _dragEndPosition;

  @override
  void initState() {
    super.initState();
    _visibilityController = AnimationController(
      // Slightly longer duration for smoother nav bar transitions
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _visibilityController,
      // Use emphasized curve for smoother fade
      curve: Curves.easeInOutCubicEmphasized,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, 1),
    ).animate(CurvedAnimation(
      parent: _visibilityController,
      // Use emphasized curve for smoother slide
      curve: Curves.easeInOutCubicEmphasized,
    ));

    // Tab animation controller
    _tabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _tabAnimation = CurvedAnimation(
      parent: _tabAnimationController,
      curve: Curves.fastOutSlowIn,
    );
    _tabAnimationController.value = 1.0; // Start completed

    _appBarVisibilityController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
      value: widget.navigationShell.currentIndex == 2 ? 0.0 : 1.0,
    );
    _appBarVisibilityAnimation = CurvedAnimation(
      parent: _appBarVisibilityController,
      curve: Curves.fastOutSlowIn,
    );

    // Start with nav visible
    _visibilityController.value = 0;
    _previousIndex = widget.navigationShell.currentIndex;
  }

  @override
  void dispose() {
    _visibilityController.dispose();
    _tabAnimationController.dispose();
    _appBarVisibilityController.dispose();
    super.dispose();
  }

  void _toggleNavVisibility() {
    setState(() {
      _isNavVisible = !_isNavVisible;
    });
    if (_isNavVisible) {
      _visibilityController.reverse();
    } else {
      _visibilityController.forward();
    }
  }

  void _setNavVisibility(bool visible) {
    if (visible != _isNavVisible) {
      setState(() {
        _isNavVisible = visible;
      });
      if (visible) {
        _visibilityController.reverse();
      } else {
        _visibilityController.forward();
      }
    }
  }

  // Library is now at index 2 (after swapping with Recommend)
  bool get _isLibraryPage => widget.navigationShell.currentIndex == 2;

  @override
  void didUpdateWidget(covariant ScaffoldWithNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Animate tab change
    if (oldWidget.navigationShell.currentIndex !=
        widget.navigationShell.currentIndex) {
      if (_isLibraryPage) {
        _appBarVisibilityController.reverse();
      } else {
        _appBarVisibilityController.forward();
      }

      // If we have a stored drag end position, animate from there
      // The _dragEndPosition will be cleared in AnimatedBuilder after animation completes
      if (_dragEndPosition != null) {
        // Start the animation from 0, the AnimatedBuilder will use _dragEndPosition
        _tabAnimationController.forward(from: 0);
      } else if (_dragValue == null) {
        _previousIndex = oldWidget.navigationShell.currentIndex;
        _tabAnimationController.forward(from: 0);
      } else {
        // If we were dragging, the movement was manual. Ensure we are settled.
        _previousIndex = oldWidget.navigationShell.currentIndex;
        _tabAnimationController.value = 1.0;
      }
    }

    // When navigating away from Library, ensure nav is visible
    if (!_isLibraryPage && !_isNavVisible) {
      _setNavVisibility(true);
    }
    // When entering Library, ensure nav is visible initially (reset state)
    // User will manually trigger full screen via light cord interactions
    if (_isLibraryPage &&
        oldWidget.navigationShell.currentIndex != 2 &&
        !_isNavVisible) {
      _setNavVisibility(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return AnimatedBuilder(
      animation: _appBarVisibilityAnimation,
      builder: (context, child) {
        final appBarVisibleValue =
            _isLibraryPage ? 0.0 : _appBarVisibilityAnimation.value;
        final appBarHeight = kToolbarHeight * appBarVisibleValue;

        return NavVisibilityController(
          toggleNavVisibility: _toggleNavVisibility,
          setNavVisibility: _setNavVisibility,
          isNavVisible: _isNavVisible,
          currentIndex: widget.navigationShell.currentIndex,
          child: Scaffold(
            appBar: PreferredSize(
              preferredSize: Size.fromHeight(appBarHeight),
              child: ClipRect(
                child: Align(
                  heightFactor: appBarVisibleValue,
                  alignment: Alignment.topCenter,
                  child: IgnorePointer(
                    ignoring: appBarVisibleValue < 1,
                    child: Opacity(
                      opacity: appBarVisibleValue,
                      child: _isLibraryPage
                          ? const SizedBox.shrink()
                          : SharedAppBar(
                              title: _getTitle(
                                  widget.navigationShell.currentIndex),
                              showAvatar:
                                  widget.navigationShell.currentIndex == 0 ||
                                      widget.navigationShell.currentIndex == 1,
                            ),
                    ),
                  ),
                ),
              ),
            ),
            body: MediaQuery.removePadding(
              context: context,
              removeBottom: true,
              child: widget.navigationShell,
            ),
            // Animated bottom navigation for immersive mode
            bottomNavigationBar: SlideTransition(
              position: _slideAnimation,
              child: FadeTransition(
                opacity: ReverseAnimation(_fadeAnimation),
                child: _buildBottomNavBar(context, bottomPadding),
              ),
            ),
            extendBody: true,
          ),
        );
      },
    );
  }

  Widget _buildBottomNavBar(BuildContext context, double bottomPadding) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = widget.navigationShell.currentIndex;
    const itemsCount = 4;
    const barHeight = 66.0;
    const barRadius = 33.0;
    const selectedPillInset = 5.0;
    const selectedPillHorizontalInset = 5.0;
    const selectedPillRadius = barRadius - selectedPillInset;

    return Padding(
      padding: EdgeInsets.only(
        left: 28,
        right: 28,
        bottom: bottomPadding + 12,
      ),
      child: Container(
        height: barHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(barRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.32 : 0.10),
              blurRadius: isDark ? 26 : 30,
              spreadRadius: -12,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: LiquidGlassLayer(
          settings: LiquidGlassSettings(
            refractiveIndex: 1.24,
            thickness: isDark ? 34 : 40,
            blur: isDark ? 10 : 12,
            saturation: isDark ? 1.18 : 1.38,
            chromaticAberration: 0.012,
            lightAngle: -math.pi / 4,
            lightIntensity: isDark ? 0.74 : 0.92,
            ambientStrength: isDark ? 0.16 : 0.26,
            glassColor: Colors.white.withValues(alpha: isDark ? 0.05 : 0.10),
          ),
          child: LiquidGlassBlendGroup(
            blend: 12,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(barRadius),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final availableWidth = constraints.maxWidth;

                  const selectedFlex = 1.75;
                  const unselectedFlex = 1.0;

                  ({
                    double pillLeft,
                    double pillWidth,
                    List<double> itemLefts,
                    List<double> itemWidths
                  }) calculateLayout(double fractionalIndex) {
                    final weights = List.generate(itemsCount, (i) {
                      final distance = (fractionalIndex - i).abs();
                      final t = (1.0 - distance).clamp(0.0, 1.0);
                      return lerpDouble(unselectedFlex, selectedFlex, t)!;
                    });

                    final totalWeight = weights.reduce((a, b) => a + b);
                    final unitWidth = availableWidth / totalWeight;

                    final itemWidths =
                        weights.map((w) => w * unitWidth).toList();
                    final itemLefts = <double>[];
                    double currentLeft = 0;
                    for (final w in itemWidths) {
                      itemLefts.add(currentLeft);
                      currentLeft += w;
                    }

                    final lowerIndex =
                        fractionalIndex.floor().clamp(0, itemsCount - 1);
                    final upperIndex =
                        (lowerIndex + 1).clamp(0, itemsCount - 1);
                    final t = fractionalIndex - lowerIndex;

                    final lowerLeft = itemLefts[lowerIndex];
                    final lowerWidth = itemWidths[lowerIndex];

                    final upperLeft = itemLefts[upperIndex];
                    final upperWidth = itemWidths[upperIndex];

                    final pillLeft = lerpDouble(lowerLeft, upperLeft, t)!;
                    final pillWidth = lerpDouble(lowerWidth, upperWidth, t)!;

                    return (
                      pillLeft: pillLeft,
                      pillWidth: pillWidth,
                      itemLefts: itemLefts,
                      itemWidths: itemWidths,
                    );
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (details) {
                      setState(() {
                        _dragValue = currentIndex.toDouble();
                      });
                    },
                    onHorizontalDragUpdate: (details) {
                      if (_dragValue == null) return;
                      final deltaIndex =
                          details.primaryDelta! / (availableWidth / itemsCount);
                      setState(() {
                        _dragValue = (_dragValue! + deltaIndex)
                            .clamp(0.0, itemsCount - 1 + 0.0);
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      if (_dragValue == null) return;

                      final velocity = details.primaryVelocity ?? 0;
                      int targetIndex = _dragValue!.round();

                      if (velocity.abs() > 300) {
                        if (velocity > 0) {
                          targetIndex = _dragValue!.floor() + 1;
                        } else {
                          targetIndex = _dragValue!.ceil() - 1;
                        }
                      }

                      targetIndex = targetIndex.clamp(0, itemsCount - 1);

                      final dragEndPos = _dragValue!;

                      setState(() {
                        _dragEndPosition = dragEndPos;
                        _dragValue = null;
                      });
                      _onTap(context, targetIndex);
                    },
                    onHorizontalDragCancel: () {
                      setState(() {
                        _dragValue = null;
                      });
                    },
                    child: AnimatedBuilder(
                      animation: _tabAnimation,
                      builder: (context, child) {
                        double drivingValue;
                        if (_dragValue != null) {
                          drivingValue = _dragValue!;
                        } else if (_dragEndPosition != null) {
                          drivingValue = lerpDouble(
                            _dragEndPosition!,
                            currentIndex.toDouble(),
                            _tabAnimation.value,
                          )!;
                          if (_tabAnimation.value >= 1.0) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                setState(() {
                                  _dragEndPosition = null;
                                });
                              }
                            });
                          }
                        } else {
                          drivingValue = lerpDouble(
                            _previousIndex.toDouble(),
                            currentIndex.toDouble(),
                            _tabAnimation.value,
                          )!;
                        }

                        final layout = calculateLayout(drivingValue);

                        return Stack(
                          children: [
                            Positioned.fill(
                              child: LiquidGlass.grouped(
                                clipBehavior: Clip.antiAlias,
                                shape: LiquidRoundedSuperellipse(
                                  borderRadius: barRadius,
                                ),
                                child: _buildGlassBarTint(isDark),
                              ),
                            ),
                            Positioned(
                              left:
                                  layout.pillLeft + selectedPillHorizontalInset,
                              top: selectedPillInset,
                              bottom: selectedPillInset,
                              width: layout.pillWidth -
                                  selectedPillHorizontalInset * 2,
                              child: LiquidGlass.grouped(
                                clipBehavior: Clip.antiAlias,
                                shape: LiquidRoundedSuperellipse(
                                  borderRadius: selectedPillRadius,
                                ),
                                child: _buildSelectedGlassPillTint(
                                  isDark,
                                  selectedPillRadius,
                                ),
                              ),
                            ),
                            ...List.generate(itemsCount, (index) {
                              final left = layout.itemLefts[index];
                              final width = layout.itemWidths[index];

                              return Positioned(
                                left: left,
                                top: 0,
                                bottom: 0,
                                width: width,
                                child: _buildTabItem(
                                  context,
                                  index: index,
                                  activeIcon: _getActiveIcon(index),
                                  inactiveIcon: _getInactiveIcon(index),
                                  label: _getLabel(index),
                                  isSelected: index == drivingValue.round(),
                                  isDark: isDark,
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassBarTint(bool isDark) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(33),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.11)
              : Colors.white.withValues(alpha: 0.62),
          width: isDark ? 1.0 : 1.1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0, 0.42, 1],
          colors: [
            Colors.white.withValues(alpha: isDark ? 0.045 : 0.18),
            (isDark ? Colors.black : Colors.white)
                .withValues(alpha: isDark ? 0.14 : 0.22),
            Colors.white.withValues(alpha: isDark ? 0.025 : 0.12),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedGlassPillTint(bool isDark, double borderRadius) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: RadialGradient(
                center: const Alignment(-0.28, -0.30),
                radius: 1.05,
                stops: const [0.0, 0.64, 1.0],
                colors: isDark
                    ? [
                        Colors.white.withValues(alpha: 0.16),
                        Colors.white.withValues(alpha: 0.065),
                        Colors.white.withValues(alpha: 0.03),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.24),
                        const Color(0xFFDDE7F3).withValues(alpha: 0.10),
                        const Color(0xFF9EADBF).withValues(alpha: 0.05),
                      ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.36, 1.0],
                colors: [
                  Colors.white.withValues(alpha: isDark ? 0.10 : 0.18),
                  Colors.white.withValues(alpha: isDark ? 0.03 : 0.055),
                  Colors.white.withValues(alpha: isDark ? 0.01 : 0.018),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.18),
                width: 0.8,
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getActiveIcon(int index) {
    switch (index) {
      case 0:
        return Icons.home;
      case 1:
        return Icons.whatshot; // Hot
      case 2:
        return Icons.video_library;
      case 3:
        return Icons.person; // Profile
      default:
        return Icons.circle;
    }
  }

  IconData _getInactiveIcon(int index) {
    switch (index) {
      case 0:
        return Icons.home_outlined;
      case 1:
        return Icons.whatshot_outlined; // Hot
      case 2:
        return Icons.video_library_outlined;
      case 3:
        return Icons.person_outline; // Profile
      default:
        return Icons.circle_outlined;
    }
  }

  String _getLabel(int index) {
    switch (index) {
      case 0:
        return '首页';
      case 1:
        return '推荐';
      case 2:
        return '资料库';
      case 3:
        return '账户';
      default:
        return '';
    }
  }

  Widget _buildTabItem(
    BuildContext context, {
    required int index,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
    required bool isSelected,
    required bool isDark,
  }) {
    final activeColor = isDark ? Colors.white : const Color(0xFF070B12);
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.88)
        : const Color(0xFF070B12).withValues(alpha: 0.92);

    return GestureDetector(
      onTap: () => _onTap(context, index),
      behavior: HitTestBehavior.translucent,
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: Tooltip(
          message: label,
          child: Center(
            child: AnimatedScale(
              scale: isSelected ? 1.08 : 1.0,
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              child: Icon(
                isSelected ? activeIcon : inactiveIcon,
                size: 32,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getTitle(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Hot';
      case 2:
        return 'Library';
      case 3:
        return 'Settings';
      default:
        return 'Epilog';
    }
  }

  void _onTap(BuildContext context, int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }
}
