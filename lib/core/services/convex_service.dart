import 'dart:async';

import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ConvexService {
  static final instance = ConvexService._();

  ConvexService._();

  bool _isInitialized = false;
  bool _hasAuthToken = false;
  Completer<void> _authTokenCompleter = Completer<void>();
  Future<String?> Function()? _authTokenFetcher;

  Future<void> initialize() async {
    if (_isInitialized) return;

    final deploymentUrl = dotenv.env['CONVEX_URL'];

    if (deploymentUrl == null || deploymentUrl.isEmpty) {
      debugPrint('⚠️ Convex URL not set. Please check your .env file.');
      return;
    }

    try {
      await ConvexClient.initialize(
        ConvexConfig(
          deploymentUrl: deploymentUrl,
          clientId: 'drama-tracker-flutter-1.0',
        ),
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ Failed to initialize Convex: $e');
    }
  }

  void registerAuthTokenFetcher(Future<String?> Function() fetcher) {
    _authTokenFetcher = fetcher;
  }

  /// Set the auth token for Convex (from Clerk JWT)
  Future<void> setAuthToken(String token) async {
    if (!_isInitialized) {
      debugPrint('⚠️ ConvexService not initialized, cannot set auth token');
      return;
    }

    try {
      if (token.isEmpty) {
        await clearAuthToken();
        return;
      }

      await ConvexClient.instance.setAuth(token: token);
      _hasAuthToken = true;
      if (!_authTokenCompleter.isCompleted) {
        _authTokenCompleter.complete();
      }
    } catch (e) {
      debugPrint('❌ Failed to set Convex auth token: $e');
    }
  }

  /// Clear the auth token (on sign out)
  Future<void> clearAuthToken() async {
    if (!_isInitialized) return;

    try {
      await ConvexClient.instance.setAuth(token: null);
      _hasAuthToken = false;
      if (_authTokenCompleter.isCompleted) {
        _authTokenCompleter = Completer<void>();
      }
    } catch (e) {
      debugPrint('❌ Failed to clear Convex auth token: $e');
    }
  }

  bool get hasAuthToken => _hasAuthToken;

  Future<bool> refreshAuthToken() async {
    final fetcher = _authTokenFetcher;
    if (fetcher == null) return _hasAuthToken;

    try {
      final token = await fetcher();
      if (token == null || token.isEmpty) {
        await clearAuthToken();
        return false;
      }

      await setAuthToken(token);
      return _hasAuthToken;
    } catch (e) {
      debugPrint('❌ Failed to refresh Convex auth token: $e');
      return _hasAuthToken;
    }
  }

  Future<bool> waitForAuthToken({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (_hasAuthToken) return true;

    if (await refreshAuthToken()) return true;

    try {
      await _authTokenCompleter.future.timeout(timeout);
    } on TimeoutException {
      return _hasAuthToken;
    }

    return _hasAuthToken;
  }

  ConvexClient get client {
    if (!_isInitialized) {
      throw Exception(
          'ConvexService not initialized. Call initialize() first.');
    }
    return ConvexClient.instance;
  }
}
