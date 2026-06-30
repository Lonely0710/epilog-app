import 'dart:convert';

import 'package:clerk_flutter/clerk_flutter.dart';
import 'package:flutter/widgets.dart';

import '../../features/auth/data/auth_repository.dart';
import 'convex_service.dart';

class AuthBridge {
  const AuthBridge._();

  static Future<bool> ensureFromContext(BuildContext context) async {
    final authState = ClerkAuth.of(context, listen: false);
    return ensureFromAuthState(authState);
  }

  static Future<bool> ensureFromAuthState(ClerkAuthState authState) async {
    ClerkAuthRepositoryImpl.setAuthState(authState);

    ConvexService.instance.registerAuthTokenFetcher(() async {
      final latestAuthState = ClerkAuthRepositoryImpl.authState;
      if (latestAuthState?.isSignedIn != true) return null;

      final sessionToken =
          await latestAuthState!.sessionToken(templateName: 'convex');
      return sessionToken.jwt;
    });

    if (!authState.isSignedIn) {
      await ConvexService.instance.clearAuthToken();
      return false;
    }

    try {
      final sessionToken = await authState.sessionToken(templateName: 'convex');
      await ConvexService.instance.setAuthToken(sessionToken.jwt);
      return ConvexService.instance.hasAuthToken;
    } catch (e) {
      debugPrint('Convex auth token sync failed: $e');
      await ConvexService.instance.clearAuthToken();
      return false;
    }
  }

  static Future<bool> syncProfileFromContext(BuildContext context) async {
    final authState = ClerkAuth.of(context, listen: false);
    return syncProfileFromAuthState(authState);
  }

  static Future<bool> syncProfileFromAuthState(
    ClerkAuthState authState,
  ) async {
    final isAuthenticated = await ensureFromAuthState(authState);
    if (!isAuthenticated) return false;

    final name = displayName(authState.user);

    try {
      await ConvexService.instance.client.mutation(
        name: 'users:storeUser',
        args: {
          if (name != null) 'name': name,
        },
      );
    } catch (e) {
      debugPrint('Convex profile sync failed: $e');
    }

    return true;
  }

  static String? avatarUrl(Map<String, dynamic>? profile) {
    final camelCase = profile?['avatarUrl'];
    if (camelCase is String && camelCase.trim().isNotEmpty) {
      return camelCase.trim();
    }

    final snakeCase = profile?['avatar_url'];
    if (snakeCase is String && snakeCase.trim().isNotEmpty) {
      return snakeCase.trim();
    }

    return null;
  }

  static String? profileName(Map<String, dynamic>? profile) {
    final name = profile?['name'];
    if (name is String && name.trim().isNotEmpty) {
      return name.trim();
    }
    return null;
  }

  static String? displayName(dynamic user) {
    final name = _readString(user, 'name');
    if (name != null) return name;

    final firstName = _readString(user, 'firstName');
    final lastName = _readString(user, 'lastName');
    final fullName = [
      if (firstName != null) firstName,
      if (lastName != null) lastName,
    ].join(' ').trim();
    if (fullName.isNotEmpty) return fullName;

    final emailAddresses = _readValue(user, 'emailAddresses');
    if (emailAddresses is Iterable && emailAddresses.isNotEmpty) {
      final firstEmail = emailAddresses.first;
      final email = _readString(firstEmail, 'emailAddress');
      if (email != null) return email.split('@').first;
    }

    return null;
  }

  static bool isMutationOk(dynamic result) {
    final decoded = result is String ? jsonDecode(result) : result;
    if (decoded is Map && decoded['ok'] == false) {
      return false;
    }
    return true;
  }

  static String? _readString(dynamic object, String property) {
    final value = _readValue(object, property);
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  static dynamic _readValue(dynamic object, String property) {
    if (object == null) return null;
    try {
      switch (property) {
        case 'name':
          return object.name;
        case 'firstName':
          return object.firstName;
        case 'lastName':
          return object.lastName;
        case 'emailAddresses':
          return object.emailAddresses;
        case 'emailAddress':
          return object.emailAddress;
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}
