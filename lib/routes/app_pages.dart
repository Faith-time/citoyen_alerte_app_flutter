import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/presentation/screens/splash_screen.dart';
import 'package:citoyen_alerte_app_backup/presentation/screens/auth/login_screen.dart';
import 'package:citoyen_alerte_app_backup/presentation/screens/auth/register_screen.dart';
import 'package:citoyen_alerte_app_backup/presentation/screens/auth/forgot_password_screen.dart';
import 'package:citoyen_alerte_app_backup/presentation/screens/auth/verify_phone_screen.dart';
import 'package:citoyen_alerte_app_backup/presentation/screens/home/home_screen.dart';
import 'package:citoyen_alerte_app_backup/presentation/screens/home/main_navigation_screen.dart';
import 'package:citoyen_alerte_app_backup/presentation/screens/dashboard/citizen_dashboard_screen.dart';
import 'package:citoyen_alerte_app_backup/presentation/screens/dashboard/agent_dashboard_screen.dart';
import 'package:citoyen_alerte_app_backup/presentation/screens/dashboard/admin_dashboard_screen.dart';
import 'package:citoyen_alerte_app_backup/presentation/screens/dashboard/authority_dashboard_screen.dart';
import 'package:citoyen_alerte_app_backup/presentation/screens/dashboard/statistics_screen.dart';
part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const INITIAL = Routes.SPLASH;

  static final routes = [
    GetPage(
      name: Routes.SPLASH,
      page: () => const SplashScreen(),
    ),
    GetPage(
      name: Routes.LOGIN,
      page: () => const LoginScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.REGISTER,
      page: () => const RegisterScreen(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.FORGOT_PASSWORD,
      page: () => const ForgotPasswordScreen(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.VERIFY_PHONE,
      page: () => const VerifyPhoneScreen(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: Routes.HOME,
      page: () => const HomeScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.MAIN_NAVIGATION,
      page: () => const MainNavigationScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.CITIZEN_DASHBOARD,
      page: () => const CitizenDashboardScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.AGENT_DASHBOARD,
      page: () => const AgentDashboardScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.ADMIN_DASHBOARD,
      page: () => const AdminDashboardScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.AUTHORITY_DASHBOARD,
      page: () => const AuthorityDashboardScreen(),
      transition: Transition.fadeIn,
    ),
    GetPage(
      name: Routes.STATISTICS,
      page: () => const StatisticsScreen(),
      transition: Transition.fadeIn,
    ),
  ];
}