import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppIconOption {
  final String id;
  final String assetPath;
  final String label;
  final String? iosIconName;
  final String androidAlias;

  const AppIconOption({
    required this.id,
    required this.assetPath,
    required this.label,
    required this.androidAlias,
    this.iosIconName,
  });
}

class AppIconService {
  static const _channel = MethodChannel('epilog/app_icon');
  static const _storageKey = 'selected_app_icon';
  static const defaultAssetPath = 'assets/icons/ic_logo.png';

  static const options = <AppIconOption>[
    AppIconOption(
      id: 'default',
      assetPath: defaultAssetPath,
      label: '默认',
      androidAlias: 'MainActivityDefault',
    ),
    AppIconOption(
      id: 'new_light',
      assetPath: 'assets/icons/app/ic_logo_new_light.png',
      label: '浅色',
      iosIconName: 'new_light',
      androidAlias: 'MainActivityNewLight',
    ),
    AppIconOption(
      id: 'new_dark',
      assetPath: 'assets/icons/app/ic_logo_new_dark.png',
      label: '深色',
      iosIconName: 'new_dark',
      androidAlias: 'MainActivityNewDark',
    ),
    AppIconOption(
      id: 'ticket_warm',
      assetPath: 'assets/icons/app/ic_logo_ticket_warm.png',
      label: '暖色',
      iosIconName: 'ticket_warm',
      androidAlias: 'MainActivityTicketWarm',
    ),
    AppIconOption(
      id: 'ticket_purple',
      assetPath: 'assets/icons/app/ic_logo_ticket_purple.png',
      label: '紫色',
      iosIconName: 'ticket_purple',
      androidAlias: 'MainActivityTicketPurple',
    ),
    AppIconOption(
      id: 'dark',
      assetPath: 'assets/icons/app/ic_logo_dark.png',
      label: '暗色',
      iosIconName: 'dark',
      androidAlias: 'MainActivityDark',
    ),
  ];

  static Future<String> loadSelectedAssetPath() async {
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_storageKey);
    final option = options.where((entry) => entry.id == savedId).isNotEmpty
        ? options.firstWhere((entry) => entry.id == savedId)
        : null;
    return option?.assetPath ?? defaultAssetPath;
  }

  static Future<void> saveSelectedAssetPath(String assetPath) async {
    final prefs = await SharedPreferences.getInstance();
    final option = options.firstWhere(
      (entry) => entry.assetPath == assetPath,
      orElse: () => options.first,
    );
    await prefs.setString(_storageKey, option.id);
  }

  static Future<bool> supportsAlternateIcons() async {
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('supportsAlternateIcons') ?? false;
  }

  static Future<void> setIcon(AppIconOption option) async {
    if (Platform.isIOS) {
      await _channel.invokeMethod<void>('setAlternateIcon', {
        'iconName': option.iosIconName,
      });
    } else if (Platform.isAndroid) {
      await _channel.invokeMethod<void>('setAlternateIcon', {
        'alias': option.androidAlias,
      });
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, option.id);
  }
}
