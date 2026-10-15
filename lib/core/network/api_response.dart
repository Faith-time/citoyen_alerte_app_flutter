class ApiResponse<T> {
  final bool success;
  final String? message;
  final T? data;
  final Map<String, dynamic>? errors;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.message,
    this.data,
    this.errors,
    this.statusCode,
  });

  factory ApiResponse.fromJson(
      Map<String, dynamic> json,
      T Function(dynamic)? fromJsonT, {
        int? httpStatusCode,
      }) {
    final bool is2xx =
        httpStatusCode != null && httpStatusCode >= 200 && httpStatusCode < 300;

    // ── Forme A : { success: bool, data?, message?, errors? }
    // Laravel enveloppe explicitement avec "success"
    // ex: GET /dashboard, GET /reports/user/1 quand enveloppé
    if (json.containsKey('success')) {
      final bool ok = (json['success'] as bool?) ?? is2xx;
      return ApiResponse<T>(
        success: ok,
        message: json['message'] as String?,
        data: _extract<T>(json['data'], fromJsonT),
        errors: json['errors'] as Map<String, dynamic>?,
        statusCode: httpStatusCode,
      );
    }

    // ── Forme B : { message: "...", data: { id, ... } }
    // Laravel retourne un message + la ressource créée/modifiée
    // ex: POST /reports → 201  { message: "Signalement créé...", data: { id:9, ... } }
    if (json.containsKey('message') && json.containsKey('data')) {
      return ApiResponse<T>(
        success: is2xx,
        message: json['message'] as String?,
        data: _extract<T>(json['data'], fromJsonT),
        errors: null,
        statusCode: httpStatusCode,
      );
    }

    // ── Forme C : { current_page, data: [...], total, ... }
    // Réponse paginée Laravel
    // ex: GET /reports/user/1
    if (json.containsKey('current_page') && json.containsKey('data')) {
      return ApiResponse<T>(
        success: is2xx,
        message: null,
        data: _extract<T>(json, fromJsonT), // on passe tout le json paginé
        errors: null,
        statusCode: httpStatusCode,
      );
    }

    if (json.containsKey('id')) {
      return ApiResponse<T>(
        success: is2xx,
        message: null,
        data: _extract<T>(json, fromJsonT),
        errors: null,
        statusCode: httpStatusCode,
      );
    }

    // ── Forme E : { message, errors } → erreur de validation 422
    if (json.containsKey('errors')) {
      return ApiResponse<T>(
        success: false,
        message: json['message'] as String?,
        data: null,
        errors: json['errors'] as Map<String, dynamic>?,
        statusCode: httpStatusCode,
      );
    }

    // ── Forme F : { message } seul → succès sans body (delete, logout...)
    if (json.containsKey('message')) {
      return ApiResponse<T>(
        success: is2xx,
        message: json['message'] as String?,
        data: null,
        errors: null,
        statusCode: httpStatusCode,
      );
    }

    // ── Fallback : on renvoie le json brut si 2xx
    return ApiResponse<T>(
      success: is2xx,
      message: null,
      data: is2xx ? _extract<T>(json, fromJsonT) : null,
      errors: null,
      statusCode: httpStatusCode,
    );
  }

  // ── Helper interne ────────────────────────────────────────────────────────

  static T? _extract<T>(dynamic raw, T Function(dynamic)? fromJsonT) {
    if (raw == null) return null;
    if (fromJsonT != null) return fromJsonT(raw);
    return raw as T?;
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  bool get isSuccess => success;
  bool get hasError => !success;

  @override
  String toString() =>
      'ApiResponse(success: $success, statusCode: $statusCode, '
          'message: $message, data: $data)';
}