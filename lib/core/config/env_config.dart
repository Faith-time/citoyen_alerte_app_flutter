import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static final EnvConfig _instance = EnvConfig._internal();
  factory EnvConfig() => _instance;
  EnvConfig._internal();

  String get appName => dotenv.env['APP_NAME'] ?? 'Citoyen Alerte';
  String get appVersion => dotenv.env['APP_VERSION'] ?? '1.0.0';
  String get appEnv => dotenv.env['APP_ENV'] ?? 'development';
  String get apiBaseUrl => dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000/api/v1';
  int get apiTimeout => int.parse(dotenv.env['API_TIMEOUT'] ?? '30000');
  String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  String get firebaseMessagingSenderId => dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '';
  String get firebaseProjectId => dotenv.env['FIREBASE_PROJECT_ID'] ?? '';
  String get firebaseAppId => dotenv.env['FIREBASE_APP_ID'] ?? '';
  bool get enableDebugMode => (dotenv.env['ENABLE_DEBUG_MODE'] ?? 'false').toLowerCase() == 'true';
  bool get enableMockData => (dotenv.env['ENABLE_MOCK_DATA'] ?? 'false').toLowerCase() == 'true';
  bool get enableAnalytics => (dotenv.env['ENABLE_ANALYTICS'] ?? 'false').toLowerCase() == 'true';
  bool get isDevelopment => appEnv == 'development';
  bool get isProduction => appEnv == 'production';
  bool get isStaging => appEnv == 'staging';

  void printConfig() {
    if (!isProduction) {
      print('ENV CONFIGURATION');
      print('App Name: $appName');
      print('Version: $appVersion');
      print('Environment: $appEnv');
      print('API URL: $apiBaseUrl');
      print('Timeout: ${apiTimeout}ms');
      print('Google Maps: ${googleMapsApiKey.isNotEmpty ? "✅" : "❌"}');
      print('Firebase: ${firebaseProjectId.isNotEmpty ? "✅" : "❌"}');
      print('Debug: ${enableDebugMode ? "✅" : "❌"}');
      print('═══════════════════════════════════════');
    }
  }
}
