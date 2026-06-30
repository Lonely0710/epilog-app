import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import '../../data/auth_repository.dart';
import '../../../../core/services/secure_storage_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const _minimumDisplayDuration = Duration(milliseconds: 2200);

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    if (!mounted) return;

    final minimumDisplay = Future<void>.delayed(_minimumDisplayDuration);
    final isAuthenticated = AuthRepository().isAuthenticated;
    final hasSavedCredentials = await SecureStorageService.hasSavedCredentials;
    await minimumDisplay;

    if (!mounted) return;

    if (isAuthenticated) {
      context.go('/home');
    } else if (hasSavedCredentials) {
      context.go('/login');
    } else {
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sloganColor = isDark ? Colors.white70 : Colors.black87;
    final subtitleColor = isDark ? Colors.grey.shade500 : Colors.grey;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Lottie Animations
            SizedBox(
              height: 200,
              width: 300,
              child: Lottie.asset('assets/lottie/tv_loading.json'),
            ),
            SizedBox(
              height: 100,
              width: 300,
              child: Lottie.asset('assets/lottie/plane_loading.json'),
            ),
            const SizedBox(height: 20),
            // Slogan
            Text(
              "Your films. Your archives.",
              textAlign: TextAlign.center,
              style: GoogleFonts.ebGaramond(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                color: sloganColor,
              ),
            ),
            const Spacer(),
            // Footer
            Padding(
              padding: const EdgeInsets.only(bottom: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icons/ic_logo.png',
                    width: 48,
                    height: 48,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        "影迹",
                        style: TextStyle(
                          fontFamily: 'HanSerifSC',
                          fontSize: 20,
                          color: isDark
                              ? Colors.white
                              : const Color.fromARGB(255, 108, 114, 128),
                          height: 1.0,
                        ),
                      ),
                      Text(
                        "Epilog",
                        style: GoogleFonts.ebGaramond(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontStyle: FontStyle.italic,
                          color: subtitleColor,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
