import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/core/services/auth_service.dart';
import 'package:citoyen_alerte_app_backup/routes/app_pages.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  // Raccourci vers le service
  AuthService get _auth => AuthService.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Navigation selon le rôle ──────────────────────────────────────────────
  void _navigateByRole(String role) {
    switch (role) {
      case 'admin':
        Get.offAllNamed(Routes.ADMIN_DASHBOARD);
        break;
      case 'agent':
        Get.offAllNamed(Routes.AGENT_DASHBOARD);
        break;
      case 'authority':
        Get.offAllNamed(Routes.AUTHORITY_DASHBOARD);
        break;
      case 'citizen':
      default:
        Get.offAllNamed(Routes.CITIZEN_DASHBOARD);
        break;
    }
  }

  // ─── Connexion email / mot de passe ───────────────────────────────────────
  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await Get.find<ApiService>().login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (response.success) {
        final role = _auth.userRole.value ?? 'citizen';
        Get.snackbar(
          'Connexion réussie',
          'Bon retour parmi nous !',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppTheme.success,
          colorText: AppTheme.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 2),
          icon: const Icon(Icons.check_circle, color: AppTheme.white),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        _navigateByRole(role);
      } else {
        _showError(response.message ?? 'Identifiants incorrects');
      }
    } catch (e) {
      _showError(e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Connexion Google (branché sur AuthService) ───────────────────────────
  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      // Réinitialise l'éventuelle erreur précédente
      _auth.googleError.value = '';

      final user = await _auth.signInWithGoogle();

      if (user != null) {
        // Connexion réussie : on navigue selon le rôle persisté
        final role = _auth.userRole.value ?? 'citizen';
        Get.snackbar(
          'Connexion réussie',
          'Bienvenue ${_auth.userName.value ?? user.displayName ?? ''} !',
          snackPosition: SnackPosition.TOP,
          backgroundColor: AppTheme.success,
          colorText: AppTheme.white,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 2),
          icon: const Icon(Icons.check_circle, color: AppTheme.white),
        );
        await Future.delayed(const Duration(milliseconds: 500));
        _navigateByRole(role);
      } else {
        // Annulé par l'utilisateur ou erreur gérée dans AuthService
        final err = _auth.googleError.value;
        if (err.isNotEmpty) _showError(err);
        // Sinon : annulation silencieuse, on ne fait rien
      }
    } catch (e) {
      _showError('Erreur inattendue : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Snack d'erreur ───────────────────────────────────────────────────────
  void _showError(String msg) {
    Get.snackbar(
      'Erreur',
      msg,
      snackPosition: SnackPosition.TOP,
      backgroundColor: AppTheme.error,
      colorText: AppTheme.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
      icon: const Icon(Icons.error_outline, color: AppTheme.white),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Bouton retour ────────────────────────────────────────
                    Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new,
                              color: AppTheme.darkBlue, size: 20),
                          onPressed: () => Get.back(),
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── Logo ─────────────────────────────────────────────────
                    Hero(
                      tag: 'app_logo',
                      child: Center(
                        child: Container(
                          width: 120,
                          height: 120,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryGreen.withOpacity(0.1),
                                blurRadius: 30,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/images/alert_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Titre ────────────────────────────────────────────────
                    const Text(
                      'Bon retour !',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkBlue,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connectez-vous pour continuer',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.greyMedium,
                        fontFamily: 'Poppins',
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    // ── Email ────────────────────────────────────────────────
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        color: AppTheme.darkBlue,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        hintText: 'exemple@email.com',
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.email_outlined,
                            color: AppTheme.primaryGreen,
                            size: 20,
                          ),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Veuillez entrer votre email';
                        }
                        if (!GetUtils.isEmail(v.trim())) {
                          return 'Email invalide';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ── Mot de passe ─────────────────────────────────────────
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _handleLogin(),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        color: AppTheme.darkBlue,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Mot de passe',
                        hintText: '••••••••',
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.lock_outline,
                            color: AppTheme.primaryGreen,
                            size: 20,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: AppTheme.greyMedium,
                            size: 20,
                          ),
                          onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Veuillez entrer votre mot de passe';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // ── Se souvenir + Mot de passe oublié ────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (v) =>
                                    setState(() => _rememberMe = v ?? false),
                                activeColor: AppTheme.primaryGreen,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Se souvenir',
                              style: TextStyle(
                                fontSize: 14,
                                fontFamily: 'Poppins',
                                color: AppTheme.greyMedium,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => Get.toNamed(Routes.FORGOT_PASSWORD),
                          child: const Text(
                            'Mot de passe oublié ?',
                            style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // ── Bouton Se connecter ──────────────────────────────────
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          foregroundColor: AppTheme.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          disabledBackgroundColor: AppTheme.greyLight,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: AppTheme.white,
                            strokeWidth: 2,
                          ),
                        )
                            : const Text(
                          'SE CONNECTER',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Séparateur OU ────────────────────────────────────────
                    Row(
                      children: [
                        const Expanded(
                          child: Divider(
                              color: AppTheme.greyLight, thickness: 1),
                        ),
                        Padding(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'OU',
                            style: TextStyle(
                              color: AppTheme.greyMedium.withOpacity(0.8),
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                        const Expanded(
                          child: Divider(
                              color: AppTheme.greyLight, thickness: 1),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── Bouton Google ────────────────────────────────────────
                    // Obx permet d'afficher le spinner interne de l'AuthService
                    Obx(() {
                      final googleLoading = _auth.isGoogleLoading.value;
                      return SizedBox(
                        height: 56,
                        child: OutlinedButton.icon(
                          onPressed:
                          (_isLoading || googleLoading)
                              ? null
                              : _handleGoogleSignIn,
                          icon: googleLoading
                              ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.primaryGreen,
                            ),
                          )
                              : const FaIcon(
                            FontAwesomeIcons.google,
                            size: 20,
                            color: Color(0xFFDB4437),
                          ),
                          label: Text(
                            googleLoading
                                ? 'Connexion en cours…'
                                : 'Continuer avec Google',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.darkBlue,
                              fontFamily: 'Poppins',
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: AppTheme.white,
                            side: const BorderSide(
                                color: AppTheme.greyLight, width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 32),

                    // ── Lien inscription ─────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Pas encore de compte ? ',
                          style: TextStyle(
                            color: AppTheme.greyMedium,
                            fontFamily: 'Poppins',
                          ),
                        ),
                        TextButton(
                          onPressed: () => Get.toNamed(Routes.REGISTER),
                          child: const Text(
                            "S'inscrire",
                            style: TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              fontFamily: 'Poppins',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── Loading overlay global ────────────────────────────────────────
            if (_isLoading)
              Container(
                color: AppTheme.black.withOpacity(0.3),
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryGreen),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}