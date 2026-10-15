// lib/core/network/dio_client.dart

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart' as getx;
import 'package:citoyen_alerte_app_backup/core/services/auth_service.dart';
import 'package:citoyen_alerte_app_backup/core/constants/api_constants.dart';

class DioClient {
  late final Dio _dio;
  bool _isRefreshing = false;

  DioClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _buildAuthInterceptor(),
      if (kDebugMode) _buildLoggingInterceptor(),
    ]);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  INTERCEPTEURS
  // ═══════════════════════════════════════════════════════════════════════════

  Interceptor _buildAuthInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        // Injecter le token Bearer si disponible
        try {
          final token = AuthService.instance.authToken;
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        } catch (_) {
          // AuthService pas encore prêt (rare), on continue sans token
        }
        return handler.next(options);
      },

      onError: (DioException error, handler) async {
        // Seul le 401 déclenche la logique de refresh
        if (error.response?.statusCode != 401) {
          return handler.next(error);
        }

        final path = error.requestOptions.path;

        // Ne jamais retenter sur les routes d'auth elles-mêmes
        final isAuthRoute = path.contains('/auth/refresh') ||
            path.contains('/auth/login') ||
            path.contains('/auth/register');

        if (isAuthRoute || _isRefreshing) {
          await _forceLogout();
          return handler.next(error);
        }

        // Tentative de refresh du token
        _isRefreshing = true;
        try {
          final refreshed = await _tryRefreshToken();

          if (!refreshed) {
            await _forceLogout();
            return handler.next(error);
          }

          // Rejouer la requête originale avec le nouveau token
          final opts = error.requestOptions;
          opts.headers['Authorization'] =
          'Bearer ${AuthService.instance.authToken}';
          final response = await _dio.fetch(opts);
          return handler.resolve(response);
        } catch (_) {
          await _forceLogout();
          return handler.next(error);
        } finally {
          _isRefreshing = false;
        }
      },
    );
  }

  Interceptor _buildLoggingInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('🌐 [${options.method}] ${options.baseUrl}${options.path}');
        if (options.queryParameters.isNotEmpty) {
          debugPrint('🔍 PARAMS: ${options.queryParameters}');
        }
        if (options.data != null) {
          debugPrint('📤 BODY: ${options.data}');
        }
        debugPrint(
            '🔑 AUTH: ${options.headers['Authorization'] != null ? 'Bearer ***' : 'aucun token'}');
        return handler.next(options);
      },
      onResponse: (response, handler) {
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint(
            '✅ [${response.statusCode}] ${response.requestOptions.path}');
        debugPrint('📥 RESPONSE: ${response.data}');
        return handler.next(response);
      },
      onError: (error, handler) {
        debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint(
            '❌ [${error.response?.statusCode}] ${error.requestOptions.path}');
        debugPrint('📛 ERROR: ${error.message}');
        if (error.response?.data != null) {
          debugPrint('📛 DATA: ${error.response?.data}');
        }
        return handler.next(error);
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  HELPERS AUTH
  // ═══════════════════════════════════════════════════════════════════════════

  /// Tente de rafraîchir le JWT. Retourne true si succès.
  Future<bool> _tryRefreshToken() async {
    try {
      final currentToken = AuthService.instance.authToken;
      if (currentToken == null || currentToken.isEmpty) return false;

      final response = await _dio.post(
        ApiConstants.refresh,
        options: Options(
          headers: {'Authorization': 'Bearer $currentToken'},
          extra: {'skipAuthInterceptor': true},
        ),
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'] as Map<String, dynamic>?;
        final newToken = data?['access_token'] as String?;
        if (newToken == null || newToken.isEmpty) return false;

        await AuthService.instance.updateToken(newToken);
        updateAuthToken(newToken);
        debugPrint('🔄 Token rafraîchi avec succès');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('🔄 Refresh token échoué: $e');
      return false;
    }
  }

  Future<void> _forceLogout() async {
    _isRefreshing = false;
    debugPrint('🚪 Session expirée → déconnexion forcée');
    try {
      await AuthService.instance.logout(); // logout() navigue déjà vers SPLASH
    } catch (_) {
      getx.Get.offAllNamed('/');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  /// Injecte (ou met à jour) le token Bearer dans les headers par défaut.
  void updateAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
    debugPrint('🔑 DioClient: token mis à jour');
  }

  /// Supprime le token Bearer.
  void removeAuthToken() {
    _dio.options.headers.remove('Authorization');
    debugPrint('🔑 DioClient: token supprimé');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  MÉTHODES HTTP
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Response> get(
      String path, {
        Map<String, dynamic>? queryParameters,
        Options? options,
      }) async {
    try {
      return await _dio.get(path,
          queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response> post(
      String path, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
        Options? options,
      }) async {
    try {
      return await _dio.post(path,
          data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response> put(
      String path, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
        Options? options,
      }) async {
    try {
      return await _dio.put(path,
          data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response> patch(
      String path, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
        Options? options,
      }) async {
    try {
      return await _dio.patch(path,
          data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response> delete(
      String path, {
        dynamic data,
        Map<String, dynamic>? queryParameters,
        Options? options,
      }) async {
    try {
      return await _dio.delete(path,
          data: data, queryParameters: queryParameters, options: options);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  GESTION DES ERREURS
  // ═══════════════════════════════════════════════════════════════════════════

  Exception _mapError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return Exception('Délai de connexion dépassé. Vérifiez votre réseau.');

      case DioExceptionType.connectionError:
        return Exception(
            'Impossible de se connecter au serveur. Vérifiez votre connexion.');

      case DioExceptionType.cancel:
        return Exception('Requête annulée.');

      case DioExceptionType.badCertificate:
        return Exception('Certificat SSL invalide.');

      case DioExceptionType.badResponse:
        return _mapHttpError(e.response);

      case DioExceptionType.unknown:
      default:
        return Exception('Erreur inattendue: ${e.message}');
    }
  }

  Exception _mapHttpError(Response? response) {
    final status = response?.statusCode;
    final data = response?.data;

    switch (status) {
      case 400:
        return Exception(_extractMessage(data, 'Requête invalide.'));
      case 401:
        return Exception(_extractMessage(data, 'Session expirée.'));
      case 403:
        return Exception(_extractMessage(data, 'Accès refusé.'));
      case 404:
        return Exception(_extractMessage(data, 'Ressource introuvable.'));
      case 422:
      // Erreurs de validation Laravel — retourne la première erreur champ
        if (data is Map && data['errors'] != null) {
          final errors = data['errors'] as Map<String, dynamic>;
          final firstList = errors.values.first;
          final msg = firstList is List
              ? firstList.first.toString()
              : firstList.toString();
          return Exception(msg);
        }
        return Exception(_extractMessage(data, 'Données invalides.'));
      case 429:
        return Exception('Trop de requêtes. Réessayez dans un moment.');
      case 500:
      case 502:
      case 503:
        return Exception('Erreur serveur. Réessayez plus tard.');
      default:
        return Exception(_extractMessage(data, 'Erreur HTTP $status.'));
    }
  }

  String _extractMessage(dynamic data, String fallback) {
    if (data is Map) {
      final msg = data['message'] ?? data['error'];
      if (msg != null && msg.toString().isNotEmpty) return msg.toString();
    }
    return fallback;
  }
}