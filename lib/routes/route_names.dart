/// Définition de toutes les routes de l'application
class AppRoutes {
  static const String splash = '/';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String forgotPassword = '/auth/forgot-password';
  static const String verifyPhone = '/auth/verify-phone';

  // ============ ONBOARDING ============
  static const String onboarding = '/onboarding';

  // ============ HOME & NAVIGATION ============
  static const String home = '/home';
  static const String mainNavigation = '/main-navigation';

  // ============ DASHBOARDS ============
  static const String citizenDashboard = '/dashboard/citizen';
  static const String agentDashboard = '/dashboard/agent';
  static const String adminDashboard = '/dashboard/admin';
  static const String statistics = '/dashboard/statistics';

  // ============ INTERVENTIONS ============
  static const String interventions = '/interventions';
  static const String interventionDetails = '/interventions/details';
  static const String createIntervention = '/interventions/create';

  // ============ MAPS ============
  static const String map = '/map';
  static const String mapDetails = '/map/details';

  // ============ NOTIFICATIONS ============
  static const String notifications = '/notifications';
  static const String notificationDetails = '/notifications/details';

  // ============ CHAT ============
  static const String chat = '/chat';
  static const String chatRoom = '/chat/room';

  // ============ PROFILE ============
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';

  // ============ REPORTS ============
  static const String reports = '/reports';
  static const String createReport = '/reports/create';
  static const String reportDetails = '/reports/details';

  // ============ SETTINGS ============
  static const String settings = '/settings';
  static const String settingsAccount = '/settings/account';
  static const String settingsNotifications = '/settings/notifications';
  static const String settingsPrivacy = '/settings/privacy';
  static const String settingsAbout = '/settings/about';

  AppRoutes._();

}