import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/auth_bridge.dart';
import '../../services/avatar_preview_service.dart';
import '../../../features/auth/data/convex_user_repository.dart';

class SharedAppBar extends StatefulWidget implements PreferredSizeWidget {
  final String title;
  final bool showAvatar;

  const SharedAppBar({
    super.key,
    required this.title,
    this.showAvatar = true,
  });

  @override
  State<SharedAppBar> createState() => _SharedAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _SharedAppBarState extends State<SharedAppBar> {
  Stream<Map<String, dynamic>?>? _userStream;

  @override
  void initState() {
    super.initState();
    if (widget.showAvatar) {
      _userStream = ConvexUserRepository.instance.watchCurrentUser();
    }
  }

  @override
  void didUpdateWidget(covariant SharedAppBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showAvatar != oldWidget.showAvatar) {
      if (widget.showAvatar) {
        _userStream = ConvexUserRepository.instance.watchCurrentUser();
      } else {
        _userStream = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<Map<String, dynamic>?>(
      stream: widget.showAvatar ? _userStream : null,
      builder: (context, snapshot) {
        final convexUser = snapshot.data;
        final avatarUrl = AuthBridge.avatarUrl(convexUser);

        return AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          centerTitle: true,
          leadingWidth: 56,
          leading: const SizedBox(width: 56),
          title: _BeamTitle(
            title: widget.title,
            color: isDark ? Colors.white : Colors.black,
          ),
          actions: [
            if (widget.showAvatar)
              GestureDetector(
                onTap: () {
                  context.go('/settings');
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: ClipOval(
                    child: ValueListenableBuilder<File?>(
                      valueListenable:
                          AvatarPreviewService.instance.localAvatar,
                      builder: (context, localAvatar, child) {
                        if (localAvatar != null) {
                          return Image.file(
                            localAvatar,
                            fit: BoxFit.cover,
                          );
                        }
                        if (avatarUrl != null) {
                          return CachedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.person,
                              color: Colors.grey,
                            ),
                          );
                        }
                        return const Icon(
                          Icons.person,
                          color: Colors.grey,
                        );
                      },
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 48), // Placeholder
          ],
        );
      },
    );
  }
}

class _BeamTitle extends StatelessWidget {
  final String title;
  final Color color;

  const _BeamTitle({
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 7,
            left: 18,
            child: Transform.rotate(
              angle: -0.1,
              child: Container(
                width: 48,
                height: 13,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFFFFE66D).withValues(alpha: 0.68),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFE66D).withValues(alpha: 0.36),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 14,
            child: Transform.rotate(
              angle: -0.1,
              child: Container(
                width: 46,
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: const Color(0xFF7A6CFF).withValues(alpha: 0.38),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF7A6CFF).withValues(alpha: 0.28),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              fontFamily: 'Pacifico',
              height: 1.0,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}
