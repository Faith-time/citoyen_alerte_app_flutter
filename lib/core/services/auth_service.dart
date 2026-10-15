import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:citoyen_alerte_app_backup/routes/app_pages.dart';

import 'notification_service.dart';

class AuthService extends GetxService {
  static AuthService get instance => Get.find<AuthService>();

  static const _keyIsLoggedIn   = 'is_logged_in';
  static const _keyUserId       = 'user_id';
  static const _keyUserToken    = 'user_token';
  static const _keyUserName     = 'user_name';
  static const _keyUserEmail    = 'user_email';
  static const _keyUserPhone    = 'user_phone';
  static const _keyUserAvatar   = 'user_avatar';
  static const _keyUserRole     = 'user_role';
  static const _keyAuthProvider = 'auth_provider';
  static const _keyAuthorityId  = 'authority_id';

  late SharedPreferences _prefs;

  // ── Firebase ──────────────────────────────────────────────────────────────
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // ── Google Sign In 6.x ───────────────────────────────────────────────────
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  // ── État observable ───────────────────────────────────────────────────────
  final isLoggedIn      = false.obs;
  final userId          = Rx<String?>(null);
  final userName        = Rx<String?>(null);
  final userEmail       = Rx<String?>(null);
  final userPhone       = Rx<String?>(null);
  final userAvatar      = Rx<String?>(null);
  final userToken       = Rx<String?>(null);
  final userRole        = Rx<String?>(null);
  final authProvider    = 'email'.obs;
  final userAuthorityId = Rx<int?>(null);
  final isInitialized   = false.obs;

  // ── État Google/Firebase ──────────────────────────────────────────────────
  final Rx<User?> firebaseUser    = Rx<User?>(null);
  final RxBool    isGoogleLoading = false.obs;
  final RxString  googleError     = ''.obs;

  Future<bool> Function({
  required String idToken,
  required String email,
  required String name,
  String? avatar,
  })? onGoogleAuthBackend;

  @override
  Future<void> onInit() async {
    super.onInit();
    if (isInitialized.value) return;
    _prefs = await SharedPreferences.getInstance();
    await _loadUserData();
    firebaseUser.bindStream(_firebaseAuth.authStateChanges());
    isInitialized.value = true;
    debugPrint('AuthService initialisé — connecté: $isUserLoggedIn, rôle: ${userRole.value}');

    // Si l'utilisateur était déjà connecté (session restaurée depuis les prefs),
    // on (ré)abonne aux topics de notifications correspondants à son rôle.
    if (isUserLoggedIn && userId.value != null && userRole.value != null) {
      await _subscribeToPushTopics();
    }
  }

  Future<void> _loadUserData() async {
    isLoggedIn.value   = _prefs.getBool(_keyIsLoggedIn) ?? false;
    userId.value       = _prefs.getString(_keyUserId);
    userName.value     = _prefs.getString(_keyUserName);
    userEmail.value    = _prefs.getString(_keyUserEmail);
    userPhone.value    = _prefs.getString(_keyUserPhone);
    userAvatar.value   = _prefs.getString(_keyUserAvatar);
    userToken.value    = _prefs.getString(_keyUserToken);
    userRole.value     = _prefs.getString(_keyUserRole);
    authProvider.value = _prefs.getString(_keyAuthProvider) ?? 'email';
    final stored       = _prefs.getInt(_keyAuthorityId);
    userAuthorityId.value = (stored != null && stored != -1) ? stored : null;
  }

  /// Abonne l'appareil aux topics FCM correspondant au rôle courant.
  /// Centralisé ici pour être appelé après un login classique, un login
  /// Google, ET au démarrage si une session est déjà active (onInit).
  Future<void> _subscribeToPushTopics() async {
    try {
      await PushNotificationService.instance.subscribeToRoleTopics(
        userId: userId.value!,
        role: userRole.value!, // 'citizen' | 'agent' | 'authority' | 'admin'
        authorityId: userAuthorityId.string, // pertinent uniquement pour role == 'authority'
      );
    } catch (e) {
      debugPrint('Erreur abonnement notifications: $e');
    }
  }

  Future<void> saveLoginData({
    required String id,
    required String name,
    required String email,
    required String token,
    String? phone,
    String? avatar,
    String role      = 'citizen',
    String provider  = 'email',
    int?   authorityId,
  }) async {
    await _prefs.setBool(_keyIsLoggedIn,     true);
    await _prefs.setString(_keyUserId,       id);
    await _prefs.setString(_keyUserName,     name);
    await _prefs.setString(_keyUserEmail,    email);
    await _prefs.setString(_keyUserToken,    token);
    await _prefs.setString(_keyUserRole,     role);
    await _prefs.setString(_keyAuthProvider, provider);
    await _prefs.setInt(_keyAuthorityId,     authorityId ?? -1);
    if (phone  != null) await _prefs.setString(_keyUserPhone,  phone);
    if (avatar != null) await _prefs.setString(_keyUserAvatar, avatar);

    isLoggedIn.value      = true;
    userId.value          = id;
    userName.value        = name;
    userEmail.value       = email;
    userPhone.value       = phone;
    userAvatar.value      = avatar;
    userToken.value       = token;
    userRole.value        = role;
    authProvider.value    = provider;
    userAuthorityId.value = authorityId;

    // ── Abonnement notifications push (login classique ET Google) ─────────
    await _subscribeToPushTopics();
  }

  // ── Connexion Google ──────────────────────────────────────────────────────
  Future<User?> signInWithGoogle() async {
    try {
      isGoogleLoading.value = true;
      googleError.value     = '';

      // 1. Déconnexion pour forcer le sélecteur
      try { await _googleSignIn.signOut(); } catch (_) {}

      // 2. Sélecteur de compte Google
      final GoogleSignInAccount? googleAccount =
      await _googleSignIn.signIn();
      if (googleAccount == null) {
        debugPrint('Connexion Google annulée');
        return null;
      }

      // 3. Tokens Google
      final GoogleSignInAuthentication googleAuth =
      await googleAccount.authentication;

      // 4. Credential Firebase
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken:     googleAuth.idToken,
      );

      // 5. Connexion Firebase
      final UserCredential userCredential =
      await _firebaseAuth.signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        final String? firebaseIdToken = await user.getIdToken();

        // 6. Appel backend Laravel via callback injecté
        bool backendOk = false;
        if (onGoogleAuthBackend != null) {
          debugPrint('>>> onGoogleAuthBackend présent, appel backend...');
          try {
            backendOk = await onGoogleAuthBackend!(
              idToken : firebaseIdToken ?? '',
              email   : user.email ?? googleAccount.email,
              name    : user.displayName ?? googleAccount.displayName ?? 'Utilisateur',
              avatar  : user.photoURL ?? googleAccount.photoUrl,
            );
            debugPrint('>>> backendOk: $backendOk');
          } catch (e) {
            debugPrint('>>> Backend error: $e');  // ← voir l'erreur réelle
          }
        } else {
          debugPrint('>>> onGoogleAuthBackend EST NULL');  // ← diagnostic
        }

        // 7. Fallback si le backend n'a pas répondu ou a échoué
        // NOTE: si le backend a déjà répondu (backendOk == true), c'est lui
        // qui est censé appeler saveLoginData (donc l'abonnement push est
        // déjà déclenché). Le fallback ci-dessous couvre le cas backend KO.
        if (!backendOk) {
          await saveLoginData(
            id:       user.uid,
            name:     user.displayName ?? googleAccount.displayName ?? 'Utilisateur',
            email:    user.email ?? googleAccount.email,
            token:    firebaseIdToken ?? '',
            avatar:   user.photoURL ?? googleAccount.photoUrl,
            role:     'citizen',
            provider: 'google',
          );
        }

        debugPrint('Google Sign-In réussi : ${user.email}');
      }
      return user;

    } on FirebaseAuthException catch (e) {
      googleError.value = _handleFirebaseError(e.code);
      debugPrint('FirebaseAuthException [${e.code}]: ${e.message}');
      return null;
    } catch (e) {
      googleError.value = 'Une erreur inattendue s\'est produite.';
      debugPrint('Erreur Google Sign-In: $e');
      return null;
    } finally {
      isGoogleLoading.value = false;
    }
  }


  Future<String?> getFirebaseIdToken({bool forceRefresh = false}) async {
    try {
      return await _firebaseAuth.currentUser?.getIdToken(forceRefresh);
    } catch (e) {
      debugPrint('Erreur récupération ID token: $e');
      return null;
    }
  }

  Future<void> signOutGoogle() async {
    if (authProvider.value == 'google') {
      try { await _googleSignIn.signOut(); } catch (_) {}
      try { await _firebaseAuth.signOut(); } catch (_) {}
    }
  }

  Future<void> logout() async {
    // ── Désabonnement des topics de notifications AVANT de vider les données
    try {
      await PushNotificationService.instance.unsubscribeAll();
    } catch (e) {
      debugPrint('Erreur désabonnement notifications: $e');
    }

    await signOutGoogle();
    await _prefs.clear();

    isLoggedIn.value      = false;
    userId.value          = null;
    userName.value        = null;
    userEmail.value       = null;
    userPhone.value       = null;
    userAvatar.value      = null;
    userToken.value       = null;
    userRole.value        = null;
    authProvider.value    = 'email';
    userAuthorityId.value = null;

    Get.offAllNamed(Routes.SPLASH);
  }

  Future<void> updateProfile({
    String? name, String? email, String? phone, String? avatar,
  }) async {
    if (name   != null) { await _prefs.setString(_keyUserName,   name);   userName.value   = name; }
    if (email  != null) { await _prefs.setString(_keyUserEmail,  email);  userEmail.value  = email; }
    if (phone  != null) { await _prefs.setString(_keyUserPhone,  phone);  userPhone.value  = phone; }
    if (avatar != null) { await _prefs.setString(_keyUserAvatar, avatar); userAvatar.value = avatar; }
  }

  Future<void> updateToken(String token) async {
    await _prefs.setString(_keyUserToken, token);
    userToken.value = token;
  }

  bool get isUserLoggedIn  => isLoggedIn.value;
  String? get authToken    => userToken.value;
  bool get isGoogleAuth    => authProvider.value == 'google';
  bool get hasFirebaseUser => _firebaseAuth.currentUser != null;

  bool hasRole(String role) =>
      userRole.value?.toLowerCase() == role.toLowerCase();

  bool get isCitizen => hasRole('citizen');
  bool get isAgent   => hasRole('agent');
  bool get isAdmin   => hasRole('admin');
  bool get isMairie  => isAdmin && userAuthorityId.value != null;

  String _handleFirebaseError(String code) {
    switch (code) {
      case 'account-exists-with-different-credential':
        return 'Ce compte existe déjà avec un autre fournisseur.';
      case 'invalid-credential':
        return 'Identifiants invalides. Veuillez réessayer.';
      case 'user-disabled':
        return 'Ce compte a été désactivé.';
      case 'network-request-failed':
        return 'Erreur réseau. Vérifiez votre connexion.';
      case 'popup-closed-by-user':
        return 'Connexion annulée.';
      default:
        return 'Erreur d\'authentification ($code).';
    }
  }
}