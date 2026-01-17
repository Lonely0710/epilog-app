import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/animations/route_transitions.dart';
import '../../app/animations/animated_branch_container.dart';
import '../../features/auth/presentation/pages/auth_page.dart';
import '../../features/auth/presentation/pages/login_page.dart';
import '../../features/auth/presentation/pages/register_page.dart';
import '../../features/auth/presentation/pages/verification_page.dart';
import '../../features/auth/presentation/pages/setup_profile_page.dart';
import '../../features/auth/presentation/pages/splash_page.dart';
import '../../features/auth/presentation/pages/forgot_password/forgot_password_page.dart';
import '../../features/auth/presentation/pages/forgot_password/forgot_password_verification_page.dart';
import '../../features/auth/presentation/pages/forgot_password/reset_password_page.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/library/presentation/pages/library_page.dart';
import '../../features/recommend/presentation/pages/recommend_page.dart';
import '../../features/settings/presentation/pages/settings_page.dart';
import 'scaffold_with_nav_bar.dart';
import '../../core/presentation/pages/web_browser_page.dart';
import '../../features/search/presentation/pages/search_page.dart';
import '../../features/detail/presentation/pages/media_detail_page.dart';
import '../../core/domain/entities/media.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorHomeKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellHome',
);
final _shellNavigatorLibraryKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellLibrary',
);
final _shellNavigatorRecommendKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellRecommend',
);
final _shellNavigatorSettingsKey = GlobalKey<NavigatorState>(
  debugLabel: 'shellSettings',
);

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (context, state) => const SplashPage()),
      GoRoute(path: '/auth', builder: (context, state) => const AuthPage()),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/setup-profile',
        builder: (context, state) => const SetupProfilePage(),
      ),
      GoRoute(
        path: '/verification',
        builder: (context, state) {
          final email = state.extra as String;
          return VerificationPage(email: email);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordPage(),
        routes: [
          GoRoute(
            path: 'verify',
            builder: (context, state) {
              final email = state.extra as String;
              return ForgotPasswordVerificationPage(email: email);
            },
          ),
          GoRoute(
            path: 'reset',
            builder: (context, state) => const ResetPasswordPage(),
          ),
        ],
      ),
      // Push routes with SharedAxis animation
      GoRoute(
        path: '/webview',
        pageBuilder: (context, state) {
          final args = state.extra as WebBrowserPageArgs;
          return SharedAxisTransitionPage(
            key: state.pageKey,
            child: WebBrowserPage(args: args),
          );
        },
      ),
      GoRoute(
        path: '/search',
        pageBuilder: (context, state) {
          final type = state.uri.queryParameters['type'] ?? 'all';
          return SharedAxisTransitionPage(
            key: state.pageKey,
            child: SearchPage(searchType: type),
          );
        },
      ),
      GoRoute(
        path: '/detail',
        pageBuilder: (context, state) {
          final media = state.extra as Media;
          return SharedAxisTransitionPage(
            key: state.pageKey,
            child: MediaDetailPage(media: media),
          );
        },
      ),
      StatefulShellRoute(
        navigatorContainerBuilder: (context, navigationShell, children) {
          return AnimatedBranchContainer(
            currentIndex: navigationShell.currentIndex,
            children: children,
          );
        },
        builder: (context, state, navigationShell) {
          return ScaffoldWithNavBar(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellNavigatorHomeKey,
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          // Recommend is now index 1 (swapped with Library)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorRecommendKey,
            routes: [
              GoRoute(
                path: '/recommend',
                builder: (context, state) => const RecommendPage(),
              ),
            ],
          ),
          // Library is now index 2 (swapped with Recommend)
          StatefulShellBranch(
            navigatorKey: _shellNavigatorLibraryKey,
            routes: [
              GoRoute(
                path: '/library',
                builder: (context, state) => const LibraryPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellNavigatorSettingsKey,
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
