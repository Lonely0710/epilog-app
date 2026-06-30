import 'dart:io';

import 'package:flutter/foundation.dart';

class AvatarPreviewService {
  AvatarPreviewService._();

  static final instance = AvatarPreviewService._();

  final ValueNotifier<File?> localAvatar = ValueNotifier<File?>(null);

  void showLocal(File file) {
    localAvatar.value = file;
  }

  void clearLocal(File file) {
    if (localAvatar.value?.path == file.path) {
      localAvatar.value = null;
    }
  }
}
