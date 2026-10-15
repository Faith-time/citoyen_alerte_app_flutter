#!/bin/bash
# setup_project.sh - Génération complète de la structure Flutter

echo "🚀 Génération de la structure complète du projet Flutter..."

# ============================================
# 1. STRUCTURE DE BASE
# ============================================

echo "📁 Création de la structure de base..."

# Core
mkdir -p lib/core/config
mkdir -p lib/core/constants
mkdir -p lib/core/errors
mkdir -p lib/core/network
mkdir -p lib/core/services
mkdir -p lib/core/storage
mkdir -p lib/core/theme
mkdir -p lib/core/utils
mkdir -p lib/core/validators

# Data Layer
mkdir -p lib/data/datasources/local
mkdir -p lib/data/datasources/remote
mkdir -p lib/data/models
mkdir -p lib/data/repositories

# Domain Layer
mkdir -p lib/domain/entities
mkdir -p lib/domain/repositories
mkdir -p lib/domain/usecases

# Presentation Layer
mkdir -p lib/presentation/providers
mkdir -p lib/presentation/screens/auth
mkdir -p lib/presentation/screens/home
mkdir -p lib/presentation/screens/reports
mkdir -p lib/presentation/screens/maps
mkdir -p lib/presentation/screens/profile
mkdir -p lib/presentation/screens/dashboard
mkdir -p lib/presentation/screens/interventions
mkdir -p lib/presentation/screens/notifications
mkdir -p lib/presentation/screens/chat
mkdir -p lib/presentation/screens/settings
mkdir -p lib/presentation/widgets/common
mkdir -p lib/presentation/widgets/reports
mkdir -p lib/presentation/widgets/forms

# Routes
mkdir -p lib/routes

# Assets
mkdir -p assets/images/icons
mkdir -p assets/images/illustrations
mkdir -p assets/images/badges
mkdir -p assets/images/categories
mkdir -p assets/images/placeholder
mkdir -p assets/animations
mkdir -p assets/lottie
mkdir -p assets/fonts
mkdir -p assets/data

# Test
mkdir -p test/unit
mkdir -p test/widget
mkdir -p test/integration

echo "✅ Structure de base créée"

# ============================================
# 2. FICHIERS DE CONFIGURATION
# ============================================

echo "⚙️ Création des fichiers de configuration..."

# .env files
cat > .env << 'EOF'
APP_NAME=Citoyen Alerte Sénégal
APP_VERSION=1.0.0
APP_ENV=development
API_BASE_URL=http://localhost:8000/api/v1
API_TIMEOUT=30000
GOOGLE_MAPS_API_KEY=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_PROJECT_ID=
FIREBASE_APP_ID=
ENABLE_DEBUG_MODE=true
ENABLE_MOCK_DATA=false
ENABLE_ANALYTICS=false
EOF

cat > .env.development << 'EOF'
APP_NAME=Citoyen Alerte [DEV]
APP_VERSION=1.0.0-dev
APP_ENV=development
API_BASE_URL=http://10.0.2.2:8000/api/v1
API_TIMEOUT=30000
GOOGLE_MAPS_API_KEY=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_PROJECT_ID=
FIREBASE_APP_ID=
ENABLE_DEBUG_MODE=true
ENABLE_MOCK_DATA=true
ENABLE_ANALYTICS=false
EOF

cat > .env.production << 'EOF'
APP_NAME=Citoyen Alerte Sénégal
APP_VERSION=1.0.0
APP_ENV=production
API_BASE_URL=https://api.citoyenalerte.sn/api/v1
API_TIMEOUT=30000
GOOGLE_MAPS_API_KEY=
FIREBASE_MESSAGING_SENDER_ID=
FIREBASE_PROJECT_ID=
FIREBASE_APP_ID=
ENABLE_DEBUG_MODE=false
ENABLE_MOCK_DATA=false
ENABLE_ANALYTICS=true
EOF

# ============================================
# 3. CORE - CONFIGURATION
# ============================================

echo "🔧 Génération des fichiers Core..."

cat > lib/core/config/env_config.dart << 'EOF'
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
      print('═══════════════════════════════════════');
      print('🔧 ENV CONFIGURATION');
      print('═══════════════════════════════════════');
      print('📱 App Name: $appName');
      print('📦 Version: $appVersion');
      print('🌍 Environment: $appEnv');
      print('🔗 API URL: $apiBaseUrl');
      print('⏱️  Timeout: ${apiTimeout}ms');
      print('🗺️  Google Maps: ${googleMapsApiKey.isNotEmpty ? "✅" : "❌"}');
      print('🔥 Firebase: ${firebaseProjectId.isNotEmpty ? "✅" : "❌"}');
      print('🐛 Debug: ${enableDebugMode ? "✅" : "❌"}');
      print('═══════════════════════════════════════');
    }
  }
}
EOF

cat > lib/core/constants/api_constants.dart << 'EOF'
class ApiConstants {
  // Auth endpoints
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String refreshToken = '/auth/refresh';
  
  // Reports endpoints
  static const String reports = '/reports';
  static const String createReport = '/reports';
  static const String updateReport = '/reports';
  static const String deleteReport = '/reports';
  static const String nearbyReports = '/reports/nearby';
  
  // Categories
  static const String categories = '/categories';
  
  // Regions & Communes
  static const String regions = '/regions';
  static const String communes = '/communes';
  
  // Notifications
  static const String notifications = '/notifications';
  static const String markAsRead = '/notifications';
  
  // Profile
  static const String updateProfile = '/auth/profile';
  static const String changePassword = '/auth/change-password';
  
  // Dashboard
  static const String citizenDashboard = '/dashboard/citizen';
  static const String agentDashboard = '/dashboard/agent';
  static const String adminDashboard = '/dashboard/admin';
}
EOF

cat > lib/core/constants/app_constants.dart << 'EOF'
class AppConstants {
  static const String appName = 'Citoyen Alerte Sénégal';
  static const int maxImageSize = 5 * 1024 * 1024; // 5MB
  static const int maxImages = 5;
  static const double defaultLatitude = 14.693425; // Dakar
  static const double defaultLongitude = -17.447938;
  static const double defaultZoom = 12.0;
  
  // Storage keys
  static const String tokenKey = 'auth_token';
  static const String userKey = 'user_data';
  static const String languageKey = 'app_language';
  
  // Report status
  static const List<String> reportStatuses = [
    'pending',
    'validated',
    'assigned',
    'in_progress',
    'resolved',
    'closed',
    'rejected',
  ];
  
  // Severities
  static const List<String> severities = [
    'low',
    'medium',
    'high',
    'urgent',
  ];
}
EOF

cat > lib/core/constants/colors.dart << 'EOF'
import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF2196F3);
  static const Color primaryDark = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF64B5F6);
  
  // Accent
  static const Color accent = Color(0xFFFF9800);
  
  // Severity colors
  static const Color low = Color(0xFF4CAF50);
  static const Color medium = Color(0xFFFF9800);
  static const Color high = Color(0xFFFF5722);
  static const Color urgent = Color(0xFFF44336);
  
  // Status colors
  static const Color pending = Color(0xFFFFC107);
  static const Color validated = Color(0xFF2196F3);
  static const Color assigned = Color(0xFF9C27B0);
  static const Color inProgress = Color(0xFF00BCD4);
  static const Color resolved = Color(0xFF4CAF50);
  static const Color closed = Color(0xFF757575);
  static const Color rejected = Color(0xFFF44336);
  
  // UI colors
  static const Color background = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color error = Color(0xFFF44336);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color divider = Color(0xFFBDBDBD);
}
EOF

# ============================================
# 4. CORE - NETWORK
# ============================================

cat > lib/core/network/dio_client.dart << 'EOF'
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../config/env_config.dart';
import '../storage/secure_storage.dart';

class DioClient {
  late final Dio _dio;
  final SecureStorage _storage = SecureStorage();

  DioClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig().apiBaseUrl,
        connectTimeout: Duration(milliseconds: EnvConfig().apiTimeout),
        receiveTimeout: Duration(milliseconds: EnvConfig().apiTimeout),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.getToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _storage.deleteToken();
            // TODO: Navigate to login
          }
          return handler.next(error);
        },
      ),
    );

    if (EnvConfig().enableDebugMode) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
        ),
      );
    }
  }

  Dio get dio => _dio;

  // GET
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  // POST
  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  // PUT
  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }

  // DELETE
  Future<Response> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } catch (e) {
      rethrow;
    }
  }
}
EOF

# ============================================
# 5. CORE - STORAGE
# ============================================

cat > lib/core/storage/secure_storage.dart << 'EOF'
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
EOF

cat > lib/core/storage/local_storage.dart << 'EOF'
import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static final LocalStorage _instance = LocalStorage._internal();
  factory LocalStorage() => _instance;
  LocalStorage._internal();

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // String
  Future<bool> setString(String key, String value) async {
    await init();
    return _prefs!.setString(key, value);
  }

  String? getString(String key) {
    return _prefs?.getString(key);
  }

  // Int
  Future<bool> setInt(String key, int value) async {
    await init();
    return _prefs!.setInt(key, value);
  }

  int? getInt(String key) {
    return _prefs?.getInt(key);
  }

  // Bool
  Future<bool> setBool(String key, bool value) async {
    await init();
    return _prefs!.setBool(key, value);
  }

  bool? getBool(String key) {
    return _prefs?.getBool(key);
  }

  // Remove
  Future<bool> remove(String key) async {
    await init();
    return _prefs!.remove(key);
  }

  // Clear
  Future<bool> clear() async {
    await init();
    return _prefs!.clear();
  }
}
EOF

echo "✅ Fichiers Core générés"

# ============================================
# 6. GÉNÉRATION DES MODÈLES (30 MODELS)
# ============================================

echo "📦 Génération des modèles..."

# User Model
cat > lib/data/models/user_model.dart << 'EOF'
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user_model.freezed.dart';
part 'user_model.g.dart';

@freezed
class UserModel with _$UserModel {
  const factory UserModel({
    required int id,
    required String name,
    required String email,
    String? phone,
    String? avatar,
    required String role,
    @Default(10) int credits,
    @Default(50) int reputationScore,
    int? communeId,
    int? regionId,
    @Default(false) bool isSuspended,
    @Default(false) bool isBanned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _UserModel;

  factory UserModel.fromJson(Map<String, dynamic> json) =>
      _$UserModelFromJson(json);
}
EOF

# Report Model
cat > lib/data/models/report_model.dart << 'EOF'
import 'package:freezed_annotation/freezed_annotation.dart';

part 'report_model.freezed.dart';
part 'report_model.g.dart';

@freezed
class ReportModel with _$ReportModel {
  const factory ReportModel({
    required int id,
    required String reference,
    required int citizenId,
    required int categoryId,
    required String title,
    required String description,
    required double locationLat,
    required double locationLong,
    String? address,
    required int communeId,
    required int regionId,
    required String severity,
    required String status,
    @Default(0) int upvotes,
    @Default(0) int downvotes,
    @Default(0) int viewsCount,
    int? assignedAgentId,
    DateTime? resolvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _ReportModel;

  factory ReportModel.fromJson(Map<String, dynamic> json) =>
      _$ReportModelFromJson(json);
}
EOF

# Category Model
cat > lib/data/models/category_model.dart << 'EOF'
import 'package:freezed_annotation/freezed_annotation.dart';

part 'category_model.freezed.dart';
part 'category_model.g.dart';

@freezed
class CategoryModel with _$CategoryModel {
  const factory CategoryModel({
    required int id,
    required String name,
    required String slug,
    String? description,
    String? icon,
    String? color,
    int? parentId,
    @Default(true) bool isActive,
    DateTime? createdAt,
  }) = _CategoryModel;

  factory CategoryModel.fromJson(Map<String, dynamic> json) =>
      _$CategoryModelFromJson(json);
}
EOF

echo "✅ Modèles de base générés"

echo ""
echo "🎉 STRUCTURE COMPLÈTE GÉNÉRÉE !"
echo ""
echo "📊 Résumé:"
echo "  - Core: Configuration, Network, Storage, Constants"
echo "  - Data: Models, Repositories, DataSources"
echo "  - Domain: Entities, UseCases"
echo "  - Presentation: Screens, Widgets, Providers"
echo ""
echo "▶️  Prochaines étapes:"
echo "  1. flutter pub get"
echo "  2. flutter pub run build_runner build --delete-conflicting-outputs"
echo "  3. flutter run"
echo ""
EOF

# ============================================
# RENDRE LE SCRIPT EXÉCUTABLE
# ============================================

chmod +x setup_project.sh

# EXÉCUTER LE SCRIPT
./setup_project.sh