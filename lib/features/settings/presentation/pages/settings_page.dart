import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_lucide_animated/flutter_lucide_animated.dart';

import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_notion_avatar/flutter_notion_avatar_controller.dart';
import '../../../../app/animations/dialog_animations.dart';
import '../widgets/settings_background.dart';
import '../widgets/settings_lucide_motion_icons.dart';
import '../widgets/settings_tile.dart';
import '../widgets/logout_confirm_dialog.dart';
import '../widgets/settings_profile_header.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../widgets/export_dialog.dart';
import '../../../../app/theme/app_theme.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/theme_provider.dart';
import '../../../../core/services/auth_bridge.dart';
import '../../../../core/services/avatar_preview_service.dart';
import '../../../../core/services/convex_service.dart';
import 'package:clerk_flutter/clerk_flutter.dart';

@Preview()
Widget previewSettingsPage() => const SettingsPage();

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  static const _avatarPickSize = 512.0;
  static const _avatarUploadSize = 256;
  static const _avatarJpegQuality = 68;

  String _displayName = 'User';
  String? _avatarUrl;
  int _avatarVersion = 0;

  // Avatar Editing State
  final GlobalKey _avatarKey = GlobalKey();
  NotionAvatarController? _avatarController;
  File? _localImageFile;
  bool _isUsingLocalImage = false;
  bool _isUploading = false;
  bool _isPickingImage = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _regenerateSeed();
  }

  void _regenerateSeed() {
    _avatarController?.random();
  }

  Future<void> _loadProfile() async {
    String? convexName;
    String? convexAvatarUrl;

    try {
      final userJson = await ConvexService.instance.client.query(
        'users:currentUser',
        const <String, String>{},
      );

      final user = jsonDecode(userJson);
      if (user != null) {
        final userData = user as Map<String, dynamic>;
        convexName = AuthBridge.profileName(userData);
        convexAvatarUrl = AuthBridge.avatarUrl(userData);
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    }

    if (!mounted) return;

    final clerkName = AuthBridge.displayName(ClerkAuth.userOf(context));

    setState(() {
      _displayName = convexName ?? clerkName ?? 'User';
      _avatarUrl = convexAvatarUrl;
      _avatarVersion++;
    });
  }

  // --- Avatar Logic ---
  Future<void> _pickImage() async {
    if (_isPickingImage) return;

    _isPickingImage = true;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false, // Optimization: skip EXIF metadata reading
        maxWidth: _avatarPickSize,
        maxHeight: _avatarPickSize,
        imageQuality: _avatarJpegQuality,
      );

      if (pickedFile != null) {
        final croppedFile = await ImageCropper().cropImage(
          sourcePath: pickedFile.path,
          maxWidth: _avatarUploadSize,
          maxHeight: _avatarUploadSize,
          compressQuality: _avatarJpegQuality,
          compressFormat: ImageCompressFormat.jpg,
          uiSettings: [
            AndroidUiSettings(
              toolbarTitle: '裁剪头像',
              toolbarColor: AppTheme.primary,
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.square,
              lockAspectRatio: true,
              hideBottomControls: true,
              cropStyle: CropStyle.circle,
              aspectRatioPresets: [CropAspectRatioPreset.square],
            ),
            IOSUiSettings(
              title: '裁剪头像',
              aspectRatioLockEnabled: true,
              resetAspectRatioEnabled: false,
              aspectRatioPickerButtonHidden: true,
              doneButtonTitle: '完成',
              cancelButtonTitle: '取消',
              cropStyle: CropStyle.circle,
              aspectRatioPresets: [CropAspectRatioPreset.square],
            ),
          ],
        );

        if (croppedFile != null) {
          final localImage = File(croppedFile.path);
          setState(() {
            _localImageFile = localImage;
            _isUsingLocalImage = true;
          });
          AvatarPreviewService.instance.showLocal(localImage);
          // Auto-save when picking local image
          _saveAvatar();
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    } finally {
      _isPickingImage = false;
    }
  }

  Future<void> _onRefreshAvatar() async {
    final wasShowingNotionAvatar =
        (_avatarUrl == null || _avatarUrl!.isEmpty) && !_isUsingLocalImage;

    setState(() {
      _isUsingLocalImage = false;
      _localImageFile = null;
      _avatarUrl = null; // Clear existing URL to show random avatar
      _avatarVersion++;
    });

    if (!wasShowingNotionAvatar) {
      await WidgetsBinding.instance.endOfFrame;
    }

    if (!mounted) return;
    _regenerateSeed();
    await WidgetsBinding.instance.endOfFrame;

    if (mounted) {
      await _saveAvatar();
    }
  }

  Future<Uint8List?> _captureAvatarPng() async {
    try {
      RenderRepaintBoundary? boundary = _avatarKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      await Future.delayed(const Duration(milliseconds: 50)); // Wait for render
      final image = await boundary.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Capture error: $e");
      return null;
    }
  }

  Future<String?> _uploadToConvex(Uint8List bytes, String contentType) async {
    try {
      // 1. Generate Upload URL
      final uploadUrlJson = await ConvexService.instance.client.mutation(
        name: 'users:generateUploadUrl',
        args: {},
      );
      final uploadUrl = jsonDecode(uploadUrlJson) as String?;
      debugPrint('🚀 Generated Upload URL: $uploadUrl');

      if (uploadUrl == null) throw Exception('Failed to generate upload URL');

      // 2. Upload File
      final response = await http.post(
        Uri.parse(uploadUrl),
        headers: {'Content-Type': contentType},
        body: bytes,
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Upload failed: ${response.statusCode} ${response.body}');
      }

      // 3. Response contains storageId
      final jsonResponse = jsonDecode(response.body);
      return jsonResponse['storageId'];
    } catch (e) {
      debugPrint("Upload error: $e");
      return null;
    }
  }

  Future<void> _saveAvatar() async {
    if (_isUploading) return;
    setState(() => _isUploading = true);

    File? optimisticLocalImage;
    try {
      final isAuthenticated = await AuthBridge.ensureFromContext(context);
      if (!isAuthenticated) {
        if (mounted) {
          AppSnackBar.showError(
            context,
            message: '无法连接到后端，请重新登录后再试',
          );
        }
        return;
      }

      String? avatarStorageId;
      optimisticLocalImage = _isUsingLocalImage ? _localImageFile : null;
      if (_isUsingLocalImage && _localImageFile != null) {
        final bytes = await _localImageFile!.readAsBytes();
        avatarStorageId = await _uploadToConvex(bytes, 'image/jpeg');
      } else {
        final bytes = await _captureAvatarPng();
        if (bytes != null) {
          avatarStorageId = await _uploadToConvex(bytes, 'image/png');
        }
      }

      if (avatarStorageId != null) {
        final result = await ConvexService.instance.client.mutation(
          name: 'users:storeUser',
          args: {
            'name': _displayName,
            'avatarStorageId': avatarStorageId,
          },
        );
        if (!AuthBridge.isMutationOk(result)) {
          throw StateError('Convex auth identity is missing');
        }
        final newAvatarUrl = _extractAvatarUrl(result);

        if (mounted) {
          setState(() {
            if (newAvatarUrl != null && newAvatarUrl.isNotEmpty) {
              _avatarUrl = newAvatarUrl;
            }
            _isUploading = false;
            _isUsingLocalImage = false;
            _localImageFile = null;
            _avatarVersion++;
          });
          AppSnackBar.showSuccess(context, '头像已更新');
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '更新失败，请稍后重试');
      }
    } finally {
      if (optimisticLocalImage != null) {
        AvatarPreviewService.instance.clearLocal(optimisticLocalImage);
      }
      if (mounted) {
        setState(() {
          _isUploading = false;
          _isUsingLocalImage = false;
          _localImageFile = null;
        });
      }
    }
  }

  String? _extractAvatarUrl(dynamic result) {
    try {
      final decoded = result is String ? jsonDecode(result) : result;
      if (decoded is Map<String, dynamic>) {
        return decoded['avatarUrl'] as String?;
      }
      if (decoded is Map) {
        return decoded['avatarUrl'] as String?;
      }
    } catch (e) {
      debugPrint('Avatar response parse error: $e');
    }
    return null;
  }

  // --- Name Editing Logic ---
  Future<void> _editName() async {
    final newName = await context.push<String>(
      '/settings/edit-name',
      extra: _displayName,
    );

    if (!mounted || newName == null || newName == _displayName) return;

    setState(() => _displayName = newName);
    AppSnackBar.showSuccess(context, '昵称已更新');
  }

  Future<void> _handleLogout() async {
    // Show confirmation dialog
    final confirmed = await showAnimatedDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => const LogoutConfirmDialog(),
    );

    if (confirmed == true) {
      if (!mounted) return;
      try {
        await ClerkAuth.of(context).signOut();
        if (mounted) {
          context.go('/login');
        }
      } catch (e) {
        if (mounted) {
          AppSnackBar.showError(context, message: '退出失败: $e');
        }
      }
    }
  }

  void _showExportDialog() {
    showAnimatedDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) => const ExportDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SettingsBackground(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          children: [
            const SizedBox(height: 12),
            SettingsProfileHeader(
              avatarKey: _avatarKey,
              avatarUrl: _avatarUrl,
              isUsingLocalImage: _isUsingLocalImage,
              localImageFile: _localImageFile,
              isUploading: _isUploading,
              avatarVersion: _avatarVersion,
              onRefresh: _onRefreshAvatar,
              onPickImage: _pickImage,
              onCreated: (c) => _avatarController = c,
              displayName: _displayName,
              onEditName: _editName,
            ),
            const SizedBox(height: 28),

            // Settings List
            Consumer(
              builder: (context, ref, child) {
                final themeMode = ref.watch(themeModeProvider);
                final isDark = themeMode == ThemeMode.dark;
                return SettingsTile(
                  icon: isDark ? moon : null,
                  animatedIconBuilder: isDark
                      ? null
                      : (color, size, animationTick) =>
                          SettingsLucideMotionIcon(
                            type: SettingsMotionIconType.sun,
                            color: color,
                            size: size,
                            animationTick: animationTick,
                          ),
                  iconColor: AppTheme.primary,
                  title: '深色模式',
                  subtitle: '切换应用的主题颜色',
                  trailing: Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: isDark,
                      onChanged: (val) {
                        ref.read(themeModeProvider.notifier).toggleTheme(val);
                      },
                      activeThumbColor: AppTheme.primary,
                      activeTrackColor: AppTheme.primary.withValues(alpha: 0.4),
                      inactiveThumbColor: Colors.grey[400],
                      inactiveTrackColor: Colors.grey[300],
                    ),
                  ),
                  onTap: () {
                    ref.read(themeModeProvider.notifier).toggleTheme(!isDark);
                  },
                );
              },
            ),
            const SizedBox(height: 12),
            SettingsTile(
              animatedIconBuilder: (color, size, animationTick) =>
                  SettingsLucideMotionIcon(
                type: SettingsMotionIconType.cloudDownload,
                color: color,
                size: size,
                animationTick: animationTick,
              ),
              iconColor: AppTheme.primary,
              title: '数据管理',
              subtitle: '导出收藏数据',
              trailing: const LucideAnimatedIcon(
                icon: chevron_right,
                color: AppTheme.textSecondary,
                size: 22,
                trigger: AnimationTrigger.manual,
              ),
              onTap: _showExportDialog,
            ),
            const SizedBox(height: 12),
            SettingsTile(
              icon: settings,
              iconColor: AppTheme.primary,
              title: '系统设置',
              subtitle: '管理通知、图标等系统选项',
              trailing: const LucideAnimatedIcon(
                icon: chevron_right,
                color: AppTheme.textSecondary,
                size: 22,
                trigger: AnimationTrigger.manual,
              ),
              onTap: () => context.push('/settings/system'),
            ),
            const SizedBox(height: 12),
            SettingsTile(
              icon: circle_help,
              iconColor: AppTheme.primary,
              title: '问题反馈',
              subtitle: '反馈问题、联系开发者与版本信息',
              trailing: const LucideAnimatedIcon(
                icon: chevron_right,
                color: AppTheme.textSecondary,
                size: 22,
                trigger: AnimationTrigger.manual,
              ),
              onTap: () => context.push('/settings/support'),
            ),
            const SizedBox(height: 12),
            // Logout - same format as other tiles
            SettingsTile(
              icon: lock_open,
              iconColor: AppTheme.error,
              title: '退出登录',
              subtitle: '退出当前账号',
              trailing: const LucideAnimatedIcon(
                icon: chevron_right,
                color: AppTheme.textSecondary,
                size: 22,
                trigger: AnimationTrigger.manual,
              ),
              onTap: _handleLogout,
            ),

            const SizedBox(height: 64), // Extra padding for bottom nav
          ],
        ),
      ),
    );
  }
}
