import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:clerk_flutter/clerk_flutter.dart';
import '../../../../core/services/auth_bridge.dart';
import '../../../../core/services/convex_service.dart';
import 'package:flutter_notion_avatar/flutter_notion_avatar.dart';
import 'package:flutter_notion_avatar/flutter_notion_avatar_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../../../app/theme/app_theme.dart';
import '../../../../core/presentation/widgets/app_snack_bar.dart';
import '../widgets/success_dialog.dart';

class SetupProfilePage extends StatefulWidget {
  const SetupProfilePage({super.key});

  @override
  State<SetupProfilePage> createState() => _SetupProfilePageState();
}

class _SetupProfilePageState extends State<SetupProfilePage> {
  static const _avatarPickSize = 512.0;
  static const _avatarUploadSize = 256;
  static const _avatarJpegQuality = 68;

  final _usernameController = TextEditingController();
  bool _isLoading = false;

  // Avatar State
  final GlobalKey _avatarKey = GlobalKey();
  NotionAvatarController? _avatarController;
  File? _localImageFile;
  bool _isUsingLocalImage = false;
  bool _isPickingImage = false;

  // Existing avatar from DB

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _regenerateSeed();
    _usernameController.addListener(() {
      setState(() {});
    });
  }

  Future<void> _loadInitialData() async {
    // 1. Try to get from Convex (if already stored)
    try {
      final userJson = await ConvexService.instance.client.query(
        'users:currentUser',
        const <String, String>{},
      );

      final user = jsonDecode(userJson);

      if (user != null) {
        if (mounted) {
          final userData = user as Map<String, dynamic>;
          _usernameController.text = userData['name'] as String? ?? '';
          // _existingAvatarUrl = userData['avatarUrl'] as String?;
          setState(() {});
        }
        return;
      }
    } catch (e) {
      debugPrint('Convex load error: $e');
    }

    // 2. If not in Convex, try Clerk data
    if (mounted) {
      final clerkUser = ClerkAuth.userOf(context);
      if (clerkUser != null) {
        _usernameController.text = clerkUser.firstName ?? '';
        // _existingAvatarUrl = clerkUser.imageUrl;
      }
    }
  }

  void _regenerateSeed() {
    _avatarController?.random();
    setState(() {
      _isUsingLocalImage = false;
      _localImageFile = null;
    });
  }

  Future<void> _pickImage() async {
    if (_isPickingImage) return;

    _isPickingImage = true;

    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        requestFullMetadata: false,
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
          setState(() {
            _localImageFile = File(croppedFile.path);
            _isUsingLocalImage = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    } finally {
      _isPickingImage = false;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _captureAvatarPng() async {
    try {
      RenderRepaintBoundary? boundary = _avatarKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;

      // Delay slightly to ensure render
      await Future.delayed(const Duration(milliseconds: 20));

      final image = await boundary.toImage(pixelRatio: 1.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint("Error capturing avatar: $e");
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

  Future<void> _saveProfile() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      AppSnackBar.showWarning(context, '请输入昵称');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authState = ClerkAuth.of(context, listen: false);
      await authState.updateUser(firstName: username);

      final isAuthenticated = await AuthBridge.ensureFromAuthState(authState);
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

      // Handle Avatar Upload if changed
      // If using local image
      if (_isUsingLocalImage && _localImageFile != null) {
        final bytes = await _localImageFile!.readAsBytes();
        avatarStorageId = await _uploadToConvex(bytes, 'image/jpeg');
      } else if (!_isUsingLocalImage) {
        // Only upload generated avatar if we don't have an existing one OR user requested regeneration
        // But logic here says if not using local image, we capture PNG.
        final bytes = await _captureAvatarPng();
        if (bytes != null) {
          avatarStorageId = await _uploadToConvex(bytes, 'image/png');
        }
      }

      // Call Convex Mutation
      final result = await ConvexService.instance.client.mutation(
        name: 'users:storeUser',
        args: {
          'name': username,
          if (avatarStorageId != null) 'avatarStorageId': avatarStorageId,
        },
      );
      if (!AuthBridge.isMutationOk(result)) {
        throw StateError('Convex auth identity is missing');
      }

      if (mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => SuccessDialog(
            onDismiss: () {
              Navigator.of(context).pop(); // Close dialog
              context.go('/home'); // Navigate to home
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackBar.showError(context, message: '保存失败: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1A2A3A) : AppTheme.surface;
    final borderColor = isDark ? Colors.grey.shade700 : AppTheme.divider;
    final titleColor = isDark ? Colors.white : AppTheme.textPrimary;
    final buttonBgColor = isDark ? const Color(0xFF1A2A3A) : Colors.white;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.textSecondary),
            onPressed: () async {
              try {
                await ClerkAuth.of(context).signOut();
              } catch (e) {
                // Ignore
              }
              if (!context.mounted) return;
              context.go('/login');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),

              // Avatar Section
              Center(
                child: Stack(
                  children: [
                    RepaintBoundary(
                      key: _avatarKey,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: surfaceColor,
                          border: Border.all(color: borderColor, width: 2),
                        ),
                        child: ClipOval(
                          child: _isUsingLocalImage && _localImageFile != null
                              ? Image.file(_localImageFile!, fit: BoxFit.cover)
                              : SizedBox(
                                  width: 120,
                                  height: 120,
                                  child: NotionAvatar(
                                    useRandom: true,
                                    onCreated: (c) {
                                      _avatarController = c;
                                    },
                                  ),
                                ),
                        ),
                      ),
                    ),

                    // Refresh Button (Only for generated)
                    if (!_isUsingLocalImage)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: InkWell(
                          onTap: _regenerateSeed,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppTheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.refresh,
                                color: Colors.white, size: 16),
                          ),
                        ),
                      ),

                    // Add Image Button
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: buttonBgColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: borderColor),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add_photo_alternate,
                              color: AppTheme.primary, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Text(
                "设置你的昵称",
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: titleColor,
                    ),
              ),
              const SizedBox(height: 16),
              Text(
                "不管是真名还是代号，告诉我们该如何称呼你。",
                textAlign: TextAlign.center,
                style: TextStyle(
                    color:
                        isDark ? Colors.grey.shade400 : AppTheme.textSecondary),
              ),
              const SizedBox(height: 48),

              // Username Field
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  hintText: "昵称",
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  filled: true,
                  fillColor: surfaceColor,
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: _usernameController.text.isNotEmpty
                      ? [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          "开启 Epilog 之旅",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
