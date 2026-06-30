import 'dart:async';
import 'package:flutter/material.dart';
import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:clerk_auth/clerk_auth.dart' as clerk;

abstract class AuthRepository {
  factory AuthRepository() {
    return ClerkAuthRepositoryImpl();
  }

  // Common properties
  String? get userId;
  bool get isAuthenticated;
  Stream<bool> get authStateChanges;

  // Sign In
  Future<void> signInWithEmail(
      {required String email, required String password});
  Future<void> signInWithOAuth(String provider);

  // Sign Up & Verification
  Future<void> signUpWithEmail(
      {required String email, required String password});
  Future<void> verifyEmailOtp(
      {required String email, required String token}); // OTP Verification

  // Password Reset
  Future<void> sendPasswordResetEmail({required String email});
  Future<void> verifyPasswordResetOtp(
      {required String email, required String token, String? password});

  Future<void> updatePassword({required String password});

  Future<void> resendEmailOtp({required String email});

  // Sign Out
  Future<void> signOut();
}

/// Clerk-based authentication repository
class ClerkAuthRepositoryImpl implements AuthRepository {
  // Static reference to ClerkAuthState - set from widget tree
  static ClerkAuthState? _authState;

  /// Set the ClerkAuthState from the widget tree
  static void setAuthState(ClerkAuthState authState) {
    _authState = authState;
  }

  static ClerkAuthState? get authState => _authState;

  ClerkAuthState? get _auth => _authState;

  @override
  String? get userId => _auth?.user?.id;

  @override
  bool get isAuthenticated => _auth?.isSignedIn ?? false;

  @override
  Stream<bool> get authStateChanges {
    // Convert ChangeNotifier to Stream
    if (_auth == null) {
      return Stream.value(false).asBroadcastStream();
    }

    final controller = StreamController<bool>.broadcast();
    void listener() {
      controller.add(_auth?.isSignedIn ?? false);
    }

    _auth!.addListener(listener);

    // Initial value
    controller.add(_auth!.isSignedIn);

    return controller.stream;
  }

  @override
  Future<void> signInWithEmail(
      {required String email, required String password}) async {
    if (_auth == null) {
      throw Exception('ClerkAuthState not initialized. Use ClerkAuth widget.');
    }

    try {
      if (_auth!.isSignedIn) return;

      // Clear any stale progressive sign-in attempt before creating a fresh
      // password sign-in. Clerk otherwise continues the previous SignIn object
      // for the same identifier, including old needs_second_factor states.
      await _auth!.resetClient();

      await _auth!.attemptSignIn(
        strategy: clerk.Strategy.password,
        identifier: email,
        password: password,
      );

      if (_auth!.isSignedIn) return;

      final status = _auth!.client.signIn?.status.toString();
      if (status != null && status.contains('needs_second_factor')) {
        throw Exception('Second factor verification is required.');
      }

      throw Exception(
          'Sign in did not complete. Status: ${status ?? 'unknown'}');
    } catch (e) {
      debugPrint("Clerk Sign In Failed: $e");
      rethrow;
    }
  }

  @override
  Future<void> signInWithOAuth(String provider) async {
    debugPrint(
        "Clerk OAuth sign-in should be done via ClerkAuthentication widget");
    throw UnimplementedError(
        'Use ClerkAuthentication widget for OAuth sign-in');
  }

  @override
  Future<void> signUpWithEmail(
      {required String email, required String password}) async {
    if (_auth == null) {
      throw Exception('ClerkAuthState not initialized. Use ClerkAuth widget.');
    }

    try {
      await _auth!.attemptSignUp(
        strategy: clerk.Strategy.emailCode,
        emailAddress: email,
        password: password,
        passwordConfirmation: password,
      );
    } catch (e) {
      debugPrint("Clerk Sign Up Failed: $e");
      rethrow;
    }
  }

  @override
  Future<void> verifyEmailOtp(
      {required String email, required String token}) async {
    if (_auth == null) {
      throw Exception('ClerkAuthState not initialized');
    }

    try {
      await _auth!.attemptSignUp(
        strategy: clerk.Strategy.emailCode,
        code: token,
      );
    } catch (e) {
      debugPrint("Clerk Verification Failed: $e");
      rethrow;
    }
  }

  @override
  Future<void> sendPasswordResetEmail({required String email}) async {
    if (_auth == null) {
      throw Exception('ClerkAuthState not initialized');
    }

    try {
      await _auth!.initiatePasswordReset(
        identifier: email,
        strategy: clerk.Strategy.resetPasswordEmailCode,
      );
    } catch (e) {
      debugPrint("Clerk Reset Password Email Failed: $e");
      rethrow;
    }
  }

  @override
  Future<void> verifyPasswordResetOtp(
      {required String email, required String token, String? password}) async {
    if (_auth == null) {
      throw Exception('ClerkAuthState not initialized');
    }

    try {
      await _auth!.attemptSignIn(
        strategy: clerk.Strategy.resetPasswordEmailCode,
        identifier: email,
        code: token,
        password: password, // Required for this strategy
      );

      final signIn = _auth?.client.signIn;
      if (signIn != null &&
          !signIn.status.toString().toLowerCase().contains('complete')) {
        debugPrint("SignIn Status: ${signIn.status}");
        throw Exception(
            "Verification failed. Password might be too weak or compromised (form_password_pwned).");
      }
    } catch (e) {
      if (e.toString().contains('session_exists')) {
        debugPrint("Session already exists, treating as success.");
        return;
      }
      debugPrint("Clerk Reset Password Verify Failed: $e");
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    if (_auth == null) return;
    await _auth!.signOut();
  }

  @override
  Future<void> updatePassword({required String password}) async {
    // Clerk Update Password - use attemptSignIn with password strategy after reset
    if (_auth == null) {
      throw Exception('ClerkAuthState not initialized');
    }

    // After password reset OTP verification, set new password
    await _auth!.attemptSignIn(
      strategy: clerk.Strategy.password,
      password: password,
    );
  }

  @override
  Future<void> resendEmailOtp({required String email}) async {
    if (_auth == null) {
      throw Exception('ClerkAuthState not initialized');
    }

    // Re-attempt sign up to resend code
    await _auth!.attemptSignUp(
      strategy: clerk.Strategy.emailCode,
      emailAddress: email,
    );
  }
}
