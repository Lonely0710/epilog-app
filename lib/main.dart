import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'app/app.dart';
import 'app/presentation/splash_screen.dart';
import 'dart:io';
import 'package:flutter/services.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Preserve the splash screen until we're ready to show our custom splash
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Fix for CERTIFICATE_VERIFY_FAILED: application verification failure
  HttpOverrides.global = MyHttpOverrides();

  await Supabase.initialize(
    url: 'https://gihxuhnasjlwznheyska.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdpaHh1aG5hc2psd3puaGV5c2thIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc4NjYzOTgsImV4cCI6MjA4MzQ0MjM5OH0.GBZbGigod_MXBiTI1o9SN9CiXUKLcRSMRXbIfscVSec',
  );

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      statusBarColor: Colors.transparent,
    ),
  );

  // Remove native splash and show our app with custom splash
  FlutterNativeSplash.remove();

  runApp(const ProviderScope(child: DramaTrackerAppWithSplash()));
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

/// Wrapper that shows splash screen during initial app setup
class DramaTrackerAppWithSplash extends StatefulWidget {
  const DramaTrackerAppWithSplash({super.key});

  @override
  State<DramaTrackerAppWithSplash> createState() => _DramaTrackerAppWithSplashState();
}

class _DramaTrackerAppWithSplashState extends State<DramaTrackerAppWithSplash> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Show splash for minimum duration to display Lottie animation
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      // Show splash screen during initialization
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SplashScreen(),
      );
    }

    // Show actual app after initialization
    return const ProviderScope(child: DramaTrackerApp());
  }
}
