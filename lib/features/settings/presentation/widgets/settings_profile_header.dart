import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_notion_avatar/flutter_notion_avatar_controller.dart';

import 'settings_avatar.dart';
import 'settings_user_info.dart';
import 'typewriter_slogan.dart';

class SettingsProfileHeader extends StatelessWidget {
  final GlobalKey avatarKey;
  final String? avatarUrl;
  final bool isUsingLocalImage;
  final File? localImageFile;
  final bool isUploading;
  final int avatarVersion;
  final VoidCallback onRefresh;
  final VoidCallback onPickImage;
  final ValueChanged<NotionAvatarController>? onCreated;
  final String displayName;
  final VoidCallback onEditName;

  const SettingsProfileHeader({
    super.key,
    required this.avatarKey,
    required this.avatarUrl,
    required this.isUsingLocalImage,
    required this.localImageFile,
    required this.isUploading,
    required this.avatarVersion,
    required this.onRefresh,
    required this.onPickImage,
    required this.displayName,
    required this.onEditName,
    this.onCreated,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isDark
                ? Theme.of(context).colorScheme.surface.withValues(alpha: 0.52)
                : Colors.white.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.26),
              width: 0.7,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.045),
                blurRadius: 34,
                spreadRadius: -24,
                offset: const Offset(0, 18),
              ),
              if (!isDark)
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.72),
                  blurRadius: 18,
                  spreadRadius: -14,
                  offset: const Offset(-6, -8),
                ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SettingsAvatar(
                  avatarKey: avatarKey,
                  avatarUrl: avatarUrl,
                  isUsingLocalImage: isUsingLocalImage,
                  localImageFile: localImageFile,
                  isUploading: isUploading,
                  avatarVersion: avatarVersion,
                  onRefresh: onRefresh,
                  onPickImage: onPickImage,
                  onCreated: onCreated,
                ),
                const SizedBox(width: 22),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SettingsUserInfo(
                        displayName: displayName,
                        onEditName: onEditName,
                      ),
                      const SizedBox(height: 12),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: TypewriterSlogan(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
