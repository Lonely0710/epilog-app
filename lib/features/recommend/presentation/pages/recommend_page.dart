import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../settings/presentation/widgets/settings_background.dart';
import '../widgets/recent_movies_view.dart';
import '../widgets/top_rated_view.dart';
import '../widgets/daily_schedule_view.dart';

class RecommendPage extends StatefulWidget {
  const RecommendPage({super.key});

  @override
  State<RecommendPage> createState() => _RecommendPageState();
}

class _RecommendPageState extends State<RecommendPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SettingsBackground(
      child: Column(
        children: [
          // Custom Tab Bar
          Container(
            height: 60,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF253646).withValues(alpha: 0.42)
                  : Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
              border: isDark
                  ? Border.all(
                      color: Colors.white.withValues(alpha: 0.055),
                      width: 0.8,
                    )
                  : null,
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 18,
                        spreadRadius: -12,
                        offset: const Offset(0, 10),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: LayoutBuilder(
              builder: (context, tabConstraints) {
                final tabWidth = tabConstraints.maxWidth / 3;
                return Stack(
                  children: [
                    // FakeGlass Selection Indicator
                    AnimatedBuilder(
                      animation: _tabController.animation!,
                      builder: (context, child) {
                        final double offset =
                            _tabController.animation!.value * tabWidth;
                        return Positioned(
                          left: offset,
                          top: 0,
                          bottom: 0,
                          width: tabWidth,
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: LiquidGlassLayer(
                              settings: const LiquidGlassSettings(
                                thickness: 15,
                                blur: 0,
                                glassColor: Color(0x22FFFFFF),
                              ),
                              child: FakeGlass(
                                shape: LiquidRoundedSuperellipse(
                                  borderRadius: 16,
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.09)
                                        : Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.18)
                                          : Colors.white.withValues(alpha: 0.8),
                                      width: isDark ? 1 : 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDark
                                            ? Colors.black
                                                .withValues(alpha: 0.10)
                                            : AppTheme.primary
                                                .withValues(alpha: 0.15),
                                        blurRadius: 12,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    // Tab Items
                    Row(
                      children: [
                        _buildTabItem(0, '近期上映',
                            icon: Icons.four_k_rounded, isDark: isDark),
                        _buildTabItem(1, '每日放送',
                            icon: Icons.calendar_today, isDark: isDark),
                        _buildTabItem(2, '高分推荐',
                            icon: Icons.bar_chart, isDark: isDark),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),

          // Tab View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                RecentMoviesView(),
                DailyScheduleView(),
                TopRatedView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, String label,
      {IconData? icon, String? assetIcon, required bool isDark}) {
    final inactiveColor = isDark ? Colors.grey[400]! : Colors.grey;

    return Expanded(
      child: GestureDetector(
        onTap: () => _tabController.animateTo(index),
        behavior: HitTestBehavior.translucent,
        child: AnimatedBuilder(
          animation: _tabController.animation!,
          builder: (context, child) {
            final int currentIndex = _tabController.animation!.value.round();
            final bool isSelected = currentIndex == index;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (assetIcon != null)
                  ImageIcon(
                    AssetImage(assetIcon),
                    size: 24,
                    color: isSelected ? AppTheme.primary : inactiveColor,
                  )
                else
                  Icon(
                    icon,
                    size: 24,
                    color: isSelected ? AppTheme.primary : inactiveColor,
                  ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? AppTheme.primary : inactiveColor,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
