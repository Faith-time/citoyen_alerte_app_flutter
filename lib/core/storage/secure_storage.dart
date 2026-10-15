import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

class SecureStorage {
  static final SecureStorage _instance = SecureStorage._internal();
  factory SecureStorage() => _instance;
  SecureStorage._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );

  // Token
  Future<void> saveToken(String token) async {
    await _storage.write(key: AppConstants.tokenKey, value: token);
  }

  Future<String?> getToken() async {
    return await _storage.read(key: AppConstants.tokenKey);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: AppConstants.tokenKey);
  }

  // User data
  Future<void> saveUser(String userData) async {
    await _storage.write(key: AppConstants.userKey, value: userData);
  }

  Future<String?> getUser() async {
    return await _storage.read(key: AppConstants.userKey);
  }

  Future<void> deleteUser() async {
    await _storage.delete(key: AppConstants.userKey);
  }

  // Clear all
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
