import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:citoyen_alerte_app_backup/routes/app_pages.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/core/services/auth_service.dart';
import 'package:citoyen_alerte_app_backup/core/network/dio_client.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/core/services/dashboard_service.dart';
import 'package:citoyen_alerte_app_backup/core/services/category_service.dart';
import 'package:citoyen_alerte_app_backup/core/services/location_service.dart';

import 'core/services/notification_service.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: dotenv.env['APP_NAME'] ?? 'Citoyen Alerte',
      debugShowCheckedModeBanner: false,
      // theme: AppTheme.lightTheme,
     // darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      initialRoute: AppPages.INITIAL,
      getPages: AppPages.routes,
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Style de la barre système ─────────────────────────────────────────────
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ── 1. Charger les variables d'environnement ──────────────────────────────
  try {
    await dotenv.load(fileName: '.env');
    debugPrint('.env chargé');
  } catch (e) {
    debugPrint('Erreur chargement .env: $e');
  }

  // ── 2. Initialiser Firebase ───────────────────────────────────────────────
  //  Doit être fait avant tout autre service Firebase (Auth, Messaging, etc.)
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialisé');
    await PushNotificationService.instance.init(); // ⬅️ AJOUT, après Firebase.initializeApp()

  } catch (e) {
    debugPrint('Erreur initialisation Firebase: $e');
  }

  final authService = await Get.putAsync<AuthService>(() async {
    final service = AuthService();
    await service.onInit();
    return service;
  }, permanent: true);
  debugPrint('AuthService prêt — connecté: ${authService.isUserLoggedIn}, rôle: ${authService.userRole.value}');

  // ── 4. GoogleAuthService ──────────────────────────────────────────────────
  //  Gère la connexion / déconnexion Google + Firebase Auth
  //  Enregistré en permanent (fenix: false) car utilisé tout au long de l'app
  debugPrint('GoogleAuthService prêt');

  // ── 5. DioClient — créé APRÈS AuthService ────────────────────────────────
  //  Le token sauvegardé est injecté immédiatement dans les headers par défaut
  //  pour éviter que la première requête parte sans Bearer.
  final dioClient = DioClient();
  if (authService.authToken != null && authService.authToken!.isNotEmpty) {
    dioClient.updateAuthToken(authService.authToken!);
    debugPrint('Token restauré dans DioClient');
  } else {
    debugPrint('Aucun token sauvegardé (utilisateur non connecté)');
  }
  Get.put<DioClient>(dioClient);

  // ── 6. ApiService ─────────────────────────────────────────────────────────
  Get.put<ApiService>(ApiService(dioClient));
  debugPrint('ApiService prêt');

  final apiService = Get.find<ApiService>();
  authService.onGoogleAuthBackend = ({
    required String idToken,
    required String email,
    required String name,
    String? avatar,
  }) async {
    try {
      debugPrint('>>> [Google Backend] Appel avec email=$email, name=$name');
      debugPrint('>>> [Google Backend] idToken (50 premiers chars): ${idToken.substring(0, idToken.length > 50 ? 50 : idToken.length)}');

      final response = await apiService.googleAuth({
        'id_token': idToken,
        'email':    email,
        'name':     name,
        if (avatar != null) 'avatar': avatar,
      });

      if (!response.success) {
        debugPrint('>>> [Google Backend] ÉCHEC — token Firebase rejeté par Laravel');
        authService.googleError.value =
            response.message ?? 'Erreur de connexion au serveur';
      }

      return response.success;
    } catch (e, stack) {
      debugPrint('>>> [Google Backend] EXCEPTION: $e');
      debugPrint('>>> [Google Backend] STACK: $stack');
      authService.googleError.value = 'Erreur réseau : $e';
      return false;
    }
  };
  // ── 7. Services métier (lazy + fenix) ────────────────────────────────────
  //  Instanciés uniquement à la première utilisation, recréés si détruits.
  Get.lazyPut<DashboardService>(() => DashboardService(), fenix: true);
  Get.lazyPut<CategoryService>(() => CategoryService(), fenix: true);
  Get.lazyPut<LocationService>(() => LocationService(), fenix: true);
  debugPrint('Services lazy enregistrés');

  // ── 8. Lancer l'app ───────────────────────────────────────────────────────
  runApp(const MyApp());
}