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
