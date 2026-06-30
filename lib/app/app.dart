import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme/app_theme.dart';
import 'theme/theme_provider.dart';
import '../core/router/app_router.dart';

class DramaTrackerApp extends ConsumerStatefulWidget {
  const DramaTrackerApp({super.key});

  @override
  ConsumerState<DramaTrackerApp> createState() => _DramaTrackerAppState();
}

class _DramaTrackerAppState extends ConsumerState<DramaTrackerApp> {
  @override
  Widget build(BuildContext context) {
    final goRouter = ref.watch(appRouterProvider);

    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Drama Tracker',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: goRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
