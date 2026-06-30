import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_notion_avatar/flutter_notion_avatar.dart';
import 'package:flutter_notion_avatar/flutter_notion_avatar_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../app/theme/app_theme.dart';

class SettingsAvatar extends StatelessWidget {
  final GlobalKey avatarKey;
  final String? avatarUrl;
  final bool isUsingLocalImage;
  final File? localImageFile;
  final bool isUploading;
  final int avatarVersion;
  final VoidCallback onRefresh;
  final VoidCallback onPickImage;

  const SettingsAvatar({
    super.key,
    required this.avatarKey,
    this.avatarUrl,
    required this.isUsingLocalImage,
    this.localImageFile,
    required this.isUploading,
    required this.avatarVersion,
    required this.onRefresh,
    required this.onPickImage,
    this.onCreated,
  });

  final ValueChanged<NotionAvatarController>? onCreated;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Semantics(
          button: true,
          label: '更换头像图片',
          child: GestureDetector(
            onTap: onPickImage,
            child: RepaintBoundary(
              key: avatarKey,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).colorScheme.surface,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.white.withValues(alpha: 0.72),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context)
                          .shadowColor
                          .withValues(alpha: isDark ? 0.18 : 0.08),
                      blurRadius: 18,
                      spreadRadius: -10,
                      offset: const Offset(0, 9),
                    )
                  ],
                ),
                child: ClipOval(
                  child: isUsingLocalImage && localImageFile != null
                      ? Image.file(
                          localImageFile!,
                          key: ValueKey(
                              'local-$avatarVersion-${localImageFile!.path}'),
                          fit: BoxFit.cover,
                        )
                      : (avatarUrl != null &&
                              avatarUrl!.isNotEmpty &&
                              !isUsingLocalImage
                          ? CachedNetworkImage(
                              key: ValueKey('remote-$avatarVersion-$avatarUrl'),
                              imageUrl: avatarUrl!,
                              fit: BoxFit.cover,
                            )
                          : SizedBox(
                              width: 80,
                              height: 80,
                              child: ClipRect(
                                child: NotionAvatar(
                                  useRandom: true,
                                  onCreated: onCreated,
                                ),
                              ),
                            )),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: _AvatarActionButton(
            tooltip: '随机头像',
            onTap: onRefresh,
            padding: const EdgeInsets.all(4),
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            icon: Icons.refresh,
            iconSize: 14,
          ),
        ),
        if (isUploading)
          Positioned.fill(
            child: Center(
              child: ClipOval(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.18),
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AvatarActionButton extends StatelessWidget {
  final String tooltip;
  final VoidCallback onTap;
  final EdgeInsets padding;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final double iconSize;

  const _AvatarActionButton({
    required this.tooltip,
    required this.onTap,
    required this.padding,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: foregroundColor, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }
}
