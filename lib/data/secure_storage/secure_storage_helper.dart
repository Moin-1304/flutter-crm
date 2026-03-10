import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Securely stores sensitive data such as API base URL.
/// Uses platform secure storage (Keychain on iOS, EncryptedSharedPreferences on Android).
class SecureStorageHelper {
  SecureStorageHelper() : _storage = const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences: true));

  final FlutterSecureStorage _storage;

  static const String _keyApiBaseUrl = 'api_base_url';

  /// Reads the stored API base URL. Returns null if never set (e.g. new install).
  Future<String?> getApiBaseUrl() async {
    return _storage.read(key: _keyApiBaseUrl);
  }

  /// Saves the API base URL securely.
  Future<void> setApiBaseUrl(String url) async {
    await _storage.write(key: _keyApiBaseUrl, value: url);
  }

  /// Removes the stored API base URL.
  Future<void> clearApiBaseUrl() async {
    await _storage.delete(key: _keyApiBaseUrl);
  }
}
