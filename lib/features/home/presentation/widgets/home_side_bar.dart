import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';

class HomeSideBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const HomeSideBar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      margin: const EdgeInsets.only(left: 8, top: 24, bottom: 24),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildIcon(0, Icons.live_tv),
          const SizedBox(height: 20),
          _buildIcon(1, null, assetPath: 'assets/icons/ic_maoyan.png'),
          const SizedBox(height: 20),
          _buildIcon(2, null, assetPath: 'assets/icons/ic_bilibili.png'),
          const SizedBox(height: 20),
          _buildIcon(3, Icons.collections_bookmark),
        ],
      ),
    );
  }

  Widget _buildIcon(int index, IconData? icon, {String? assetPath}) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onItemSelected(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : [],
        ),
        child: Center(
          child: assetPath != null
              ? Image.asset(
                  assetPath,
                  width: 26,
                  height: 26,
                  // Use white for selected, grey for unselected
                  color: isSelected ? Colors.white : Colors.grey,
                )
              : Icon(
                  icon,
                  color: isSelected ? Colors.white : Colors.grey,
                  size: 26,
                ),
        ),
      ),
    );
  }
}
