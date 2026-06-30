import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

String watchStatusIconPath(String status, {bool filled = false}) {
  return switch (status) {
    'wish' => filled
        ? 'assets/icons/popcorn-fill.svg'
        : 'assets/icons/popcorn-bold.svg',
    'watching' => filled
        ? 'assets/icons/monitor-play-fill.svg'
        : 'assets/icons/monitor-play-bold.svg',
    'watched' => filled
        ? 'assets/icons/monitor-play-fill.svg'
        : 'assets/icons/monitor-play-bold.svg',
    'on_hold' =>
      filled ? 'assets/icons/cactus-fill.svg' : 'assets/icons/cactus-bold.svg',
    _ => '',
  };
}

IconData watchStatusIconData(String status, {bool filled = true}) {
  return switch (status) {
    'watching' =>
      filled ? Icons.play_circle : Icons.play_circle_outline_rounded,
    'watched' =>
      filled ? Icons.check_circle : Icons.check_circle_outline_rounded,
    'on_hold' =>
      filled ? Icons.pause_circle : Icons.pause_circle_outline_rounded,
    _ => filled ? Icons.bookmark : Icons.bookmark_outline,
  };
}

Color watchStatusColor(String status) {
  return switch (status) {
    'watching' => Colors.blue,
    'watched' => AppColors.success,
    'on_hold' => Colors.grey,
    _ => AppColors.starActive,
  };
}

String watchStatusLabel(String status) {
  return switch (status) {
    'watching' => '在看',
    'watched' => '看过',
    'on_hold' => '搁置',
    _ => '想看',
  };
}
