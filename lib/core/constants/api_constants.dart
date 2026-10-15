import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiConstants {
  // ══════════════════════════════════════════════════════════════════════════
  //  BASE URL
  // ══════════════════════════════════════════════════════════════════════════

  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000/api/v1';

  // ══════════════════════════════════════════════════════════════════════════
  //  AUTH
  // ══════════════════════════════════════════════════════════════════════════

  static const String login                = '/auth/login';
  static const String register             = '/auth/register';
  static const String logout               = '/auth/logout';
  static const String refresh              = '/auth/refresh';
  static const String me                   = '/auth/me';
  static const String updateProfile        = '/auth/profile';
  static const String changePassword       = '/auth/change-password';
  static const String forgotPassword       = '/auth/forgot-password';
  static const String resetPassword        = '/auth/reset-password';
  static const String verifyPhone          = '/auth/verify-phone';
  static const String sendVerificationCode = '/auth/send-verification-code';
  static String get googleAuth             => '/auth/google';

  // ══════════════════════════════════════════════════════════════════════════
  //  REPORTS
  // ══════════════════════════════════════════════════════════════════════════

  static const String reports       = '/reports';
  static const String reportNearby  = '/reports/nearby';
  static const String reportAssign  = '/reports/{id}/routings';
  static const String reportAccept  = '/reports/{id}/routings/{rid}/in-progress';
  static const String reportResolve = '/reports/{id}/routings/{rid}/resolve';

  // ══════════════════════════════════════════════════════════════════════════
  //  CATEGORIES
  // ══════════════════════════════════════════════════════════════════════════

  static const String categories = '/categories';

  // ══════════════════════════════════════════════════════════════════════════
  //  AUTHORITIES
  // ══════════════════════════════════════════════════════════════════════════

  static const String authorities = '/authorities';

  // ══════════════════════════════════════════════════════════════════════════
  //  REGIONS & COMMUNES
  // ══════════════════════════════════════════════════════════════════════════

  static const String regions  = '/regions';
  static const String communes = '/communes';

  // ══════════════════════════════════════════════════════════════════════════
  //  AGENT ZONES
  // ══════════════════════════════════════════════════════════════════════════

  static const String agentZones = '/agent-zones';

  // ══════════════════════════════════════════════════════════════════════════
  //  NOTIFICATIONS
  // ══════════════════════════════════════════════════════════════════════════

  static const String notifications              = '/notifications';
  static const String notificationsMarkAsRead    = '/notifications/{id}/mark-as-read';
  static const String notificationsMarkAllAsRead = '/notifications/mark-all-as-read';

  // ══════════════════════════════════════════════════════════════════════════
  //  VOTES & COMMENTS
  // ══════════════════════════════════════════════════════════════════════════

  static const String votes    = '/votes';
  static const String comments = '/comments';

  // ══════════════════════════════════════════════════════════════════════════
  //  INTERVENTIONS
  // ══════════════════════════════════════════════════════════════════════════

  static const String interventions = '/interventions';

  // ══════════════════════════════════════════════════════════════════════════
  //  EMERGENCY CONTACTS
  // ══════════════════════════════════════════════════════════════════════════

  static const String emergencyContacts = '/emergency-contacts';

  // ══════════════════════════════════════════════════════════════════════════
  //  DASHBOARDS
  // ══════════════════════════════════════════════════════════════════════════

  static const String dashboardCitizen   = '/dashboard/citizen';
  static const String dashboardAgent     = '/dashboard/agent';
  static const String dashboardAdmin     = '/dashboard/admin';
  static const String dashboardMairie    = '/dashboard/mairie';
  static const String dashboardAuthority = '/dashboard/authority';

  // ══════════════════════════════════════════════════════════════════════════
  //  SETTINGS
  // ══════════════════════════════════════════════════════════════════════════

  static const String settingsPublic = '/settings/public';

  // ══════════════════════════════════════════════════════════════════════════
  //  UPLOAD
  // ══════════════════════════════════════════════════════════════════════════

  static const String uploadAvatar      = '/upload/avatar';
  static const String uploadReportMedia = '/upload/report-media';
}