import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  static const _storage = FlutterSecureStorage();

  static const _keyTmdbApiKey = 'tmdb_api_key';
  static const _keyTmdbApiToken = 'tmdb_api_token';

  static const _keyEmail = 'auth_email';
  static const _keyPassword = 'auth_password';
  static const _keyRememberMe = 'auth_remember_me';

  // Read methods
  static Future<String?> get tmdbApiKey async =>
      await _storage.read(key: _keyTmdbApiKey);
  static Future<String?> get tmdbApiToken async =>
      await _storage.read(key: _keyTmdbApiToken);

  static Future<String?> get email async => await _storage.read(key: _keyEmail);
  static Future<String?> get password async =>
      await _storage.read(key: _keyPassword);
  static Future<bool> get rememberMe async {
    final value = await _storage.read(key: _keyRememberMe);
    return value == 'true';
  }

  static Future<bool> get hasSavedCredentials async {
    final remember = await rememberMe;
    if (!remember) return false;

    final savedEmail = await email;
    final savedPassword = await password;
    return savedEmail != null &&
        savedEmail.isNotEmpty &&
        savedPassword != null &&
        savedPassword.isNotEmpty;
  }

  // Write methods
  static Future<void> setTmdbApiKey(String value) async {
    await _storage.write(key: _keyTmdbApiKey, value: value);
  }

  static Future<void> setTmdbApiToken(String value) async {
    await _storage.write(key: _keyTmdbApiToken, value: value);
  }

  static Future<void> saveCredentials({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _keyEmail, value: email);
    await _storage.write(key: _keyPassword, value: password);
    await _storage.write(key: _keyRememberMe, value: 'true');
  }

  static Future<void> clearCredentials() async {
    await _storage.delete(key: _keyEmail);
    await _storage.delete(key: _keyPassword);
    await _storage.delete(key: _keyRememberMe);
  }

  // Clear methods (optional)
  static Future<void> clearTmdbKeys() async {
    await _storage.delete(key: _keyTmdbApiKey);
    await _storage.delete(key: _keyTmdbApiToken);
  }
}
