import 'package:flutter/material.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/animations/dialog_animations.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../../../../core/presentation/widgets/app_dialog.dart';
import '../../../../core/services/app_icon_service.dart';
import '../widgets/delete_account_confirm_dialog.dart';
import '../widgets/settings_background.dart';
import '../widgets/settings_lucide_motion_icons.dart';
import '../widgets/settings_tile.dart';

class SystemSettingsPage extends StatefulWidget {
  const SystemSettingsPage({super.key});

  @override
  State<SystemSettingsPage> createState() => _SystemSettingsPageState();
}

class _SystemSettingsPageState extends State<SystemSettingsPage> {
  String _selectedIconPath = AppIconService.defaultAssetPath;

  @override
  void initState() {
    super.initState();
    _loadSelectedIcon();
  }

  Future<void> _loadSelectedIcon() async {
    final assetPath = await AppIconService.loadSelectedAssetPath();
    if (!mounted) return;
    setState(() => _selectedIconPath = assetPath);
  }

  Future<void> _selectIcon(AppIconOption option) async {
    if (_selectedIconPath == option.assetPath) return;
    final previousIconPath = _selectedIconPath;
    setState(() => _selectedIconPath = option.assetPath);
    try {
      await AppIconService.setIcon(option);
      if (!mounted) return;
      _showIconChangedDialog(option.label);
    } catch (error) {
      if (!mounted) return;
      setState(() => _selectedIconPath = previousIconPath);
      AppSnackBar.showError(
        context,
        message: '切换图标失败：$error',
      );
    }
  }

  void _showComingSoon(
    BuildContext context,
    String title,
    String message,
  ) {
    showAnimatedDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return AppDialog(
          title: title,
          content: Text(
            message,
            textAlign: TextAlign.start,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withValues(alpha: 0.72),
              height: 1.5,
              letterSpacing: 0,
            ),
          ),
          primaryAction: AppDialogAction(
            text: '知道了',
            onPressed: () => Navigator.pop(context),
          ),
        );
      },
    );
  }

  void _showIconChangedDialog(String label) {
    showAnimatedDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return AppDialog(
          title: '更换成功',
          content: Text(
            '已切换为「$label」图标。',
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.color
                  ?.withValues(alpha: 0.72),
              height: 1.5,
              letterSpacing: 0,
            ),
          ),
          primaryAction: AppDialogAction(
            text: '知道了',
            onPressed: () => Navigator.pop(context),
          ),
        );
      },
    );
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const DeleteAccountConfirmDialog(),
    );
    if (confirmed == true && context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = theme.textTheme.bodyLarge?.color ?? AppTheme.textPrimary;
    final pageBackground =
        isDark ? const Color(0xFF0D1D2A) : const Color(0xFFF6F6F7);

    return Scaffold(
      backgroundColor: pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        leadingWidth: 64,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 26,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '系统设置',
          style: TextStyle(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
      body: ColoredBox(
        color: pageBackground,
        child: SettingsBackground(
          backgroundColor: pageBackground,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SettingsTile(
                    icon: bell,
                    iconColor: AppTheme.primary,
                    title: '通知设置',
                    subtitle: '管理应用通知',
                    trailing: const LucideAnimatedIcon(
                      icon: chevron_right,
                      color: AppTheme.textSecondary,
                      size: 22,
                      trigger: AnimationTrigger.manual,
                    ),
                    onTap: () => _showComingSoon(
                      context,
                      '通知设置',
                      '该功能正在开发中，敬请期待。',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AppIconPickerCard(
                    selectedIconPath: _selectedIconPath,
                    options: AppIconService.options,
                    onSelect: _selectIcon,
                  ),
                  const SizedBox(height: 28),
                  SettingsTile(
                    animatedIconBuilder: (color, size, animationTick) =>
                        SettingsLucideMotionIcon(
                      type: SettingsMotionIconType.delete,
                      color: color,
                      size: size,
                      animationTick: animationTick,
                    ),
                    iconColor: AppTheme.error,
                    title: '注销账号',
                    subtitle: '永久删除账号资料和收藏',
                    trailing: const LucideAnimatedIcon(
                      icon: chevron_right,
                      color: AppTheme.textSecondary,
                      size: 22,
                      trigger: AnimationTrigger.manual,
                    ),
                    onTap: () => _handleDeleteAccount(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppIconPickerCard extends StatelessWidget {
  final String selectedIconPath;
  final List<AppIconOption> options;
  final ValueChanged<AppIconOption> onSelect;

  const _AppIconPickerCard({
    required this.selectedIconPath,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.04),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LucideAnimatedIcon(
                icon: webhook,
                color: AppTheme.primary,
                size: 24,
                trigger: AnimationTrigger.manual,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '应用图标',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '点击下方图标即可切换',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const LucideAnimatedIcon(
                icon: chevron_down,
                color: AppTheme.textSecondary,
                size: 22,
                trigger: AnimationTrigger.manual,
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              final itemWidth = (constraints.maxWidth - spacing) / 2;
              final arrangedOptions = _arrangeOptions(options);

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final option in arrangedOptions)
                    SizedBox(
                      width: itemWidth,
                      child: _AppIconChoiceTile(
                        option: option,
                        isSelected: option.assetPath == selectedIconPath,
                        onTap: () => onSelect(option),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<AppIconOption> _arrangeOptions(List<AppIconOption> options) {
    const order = <String>[
      'default',
      'dark',
      'new_light',
      'new_dark',
      'ticket_warm',
      'ticket_purple',
    ];
    final byId = {for (final option in options) option.id: option};
    return [
      for (final id in order)
        if (byId[id] != null) byId[id]!,
      for (final option in options)
        if (!order.contains(option.id)) option,
    ];
  }
}

class _AppIconChoiceTile extends StatelessWidget {
  final AppIconOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _AppIconChoiceTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      selected: isSelected,
      label: option.label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 148,
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.10)
                : theme.colorScheme.surface.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primary
                  : theme.dividerColor.withValues(alpha: 0.55),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
                  child: _AssetMemoryImage(
                    assetPath: option.assetPath,
                    fallback: const Icon(
                      Icons.image_not_supported_rounded,
                      size: 34,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Text(
                  option.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? AppTheme.primary
                        : theme.textTheme.bodyMedium?.color
                            ?.withValues(alpha: 0.72),
                  ),
                ),
              ),
              if (isSelected)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.primary,
                    size: 18,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetMemoryImage extends StatelessWidget {
  final String assetPath;
  final Widget fallback;

  const _AssetMemoryImage({
    required this.assetPath,
    required this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetPath,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}
