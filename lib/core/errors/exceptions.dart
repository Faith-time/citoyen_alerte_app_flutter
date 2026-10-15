class ServerException implements Exception {
  final String message;
  final int? statusCode;

  ServerException({
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => message;
}

class CacheException implements Exception {
  final String message;

  CacheException({required this.message});

  @override
  String toString() => message;
}

class NetworkException implements Exception {
  final String message;

  NetworkException({this.message = 'No internet connection'});

  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  final String message;

  UnauthorizedException({this.message = 'Unauthorized'});

  @override
  String toString() => message;
}

class ValidationException implements Exception {
  final Map<String, dynamic> errors;

  ValidationException({required this.errors});

  @override
  String toString() => 'Validation failed: $errors';
}
