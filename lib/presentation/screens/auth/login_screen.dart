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
      _auth.googleError.value = '';

      final user = await _auth.signInWithGoogle();

      if (user != null) {
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
        final err = _auth.googleError.value;
        if (err.isNotEmpty) _showError(err);
      }
    } catch (e) {
      _showError('Erreur inattendue : $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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

  // ─── Décoration des champs (style maquette) ───────────────────────────────
  InputDecoration _deco({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      suffixIcon: suffix,
      prefixIcon: Container(
        margin: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.primary.withOpacity(0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.primary, size: 20),
      ),
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.canvasGradient),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Bouton retour ──────────────────────────────────
                      Align(
                        alignment: Alignment.topLeft,
                        child: NeuCard(
                          padding: EdgeInsets.zero,
                          radius: 14,
                          depth: 0.5,
                          onTap: () => Get.back(),
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(Icons.arrow_back_ios_new_rounded,
                                color: AppTheme.navy, size: 18),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ── Logo ───────────────────────────────────────────
                      Hero(
                        tag: 'app_logo',
                        child: Center(
                          child: Container(
                            width: 112,
                            height: 112,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: AppTheme.neuShadow(depth: 1.1),
                            ),
                            child: const ShieldLogo(),
                          ),
                        ),
                      ),

                      const SizedBox(height: 26),

                      const Text(
                        'Bon retour !',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy,
                          fontFamily: AppTheme.fontFamily,
                          letterSpacing: -0.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Connectez-vous pour continuer',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.slate,
                          fontFamily: AppTheme.fontFamily,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 14),

                      const SizedBox(height: 30),

                      // ── Email ──────────────────────────────────────────
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 15,
                          color: AppTheme.navy,
                        ),
                        decoration: _deco(
                          label: 'Email',
                          hint: 'exemple@email.com',
                          icon: Icons.email_outlined,
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

                      const SizedBox(height: 18),

                      // ── Mot de passe ───────────────────────────────────
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _handleLogin(),
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 15,
                          color: AppTheme.navy,
                        ),
                        decoration: _deco(
                          label: 'Mot de passe',
                          hint: '••••••••',
                          icon: Icons.lock_outline,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppTheme.slate,
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

                      const SizedBox(height: 12),

                      // ── Se souvenir + Mot de passe oublié ──────────────
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
                                  activeColor: AppTheme.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Se souvenir',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontFamily: AppTheme.fontFamily,
                                  color: AppTheme.slate,
                                ),
                              ),
                            ],
                          ),
                          TextButton(
                            onPressed: () =>
                                Get.toNamed(Routes.FORGOT_PASSWORD),
                            child: const Text('Mot de passe oublié ?'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // ── Bouton Se connecter ────────────────────────────
                      _isLoading
                          ? Container(
                              height: 54,
                              decoration: BoxDecoration(
                                color: AppTheme.mist,
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusMd),
                              ),
                              child: const Center(
                                child: SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primary,
                                    strokeWidth: 2.2,
                                  ),
                                ),
                              ),
                            )
                          : PrimaryActionButton(
                              label: 'Se connecter',
                              icon: Icons.login_rounded,
                              onTap: _handleLogin,
                            ),

                      const SizedBox(height: 22),

                      // ── Séparateur OU ──────────────────────────────────
                      Row(
                        children: [
                          const Expanded(child: Divider(color: AppTheme.mist)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OU',
                              style: TextStyle(
                                color: AppTheme.slate.withOpacity(0.8),
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                letterSpacing: 1.2,
                                fontFamily: AppTheme.fontFamily,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(color: AppTheme.mist)),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // ── Bouton Google ──────────────────────────────────
                      Obx(() {
                        final googleLoading = _auth.isGoogleLoading.value;
                        return NeuCard(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          radius: AppTheme.radiusMd,
                          depth: 0.6,
                          onTap: (_isLoading || googleLoading)
                              ? null
                              : _handleGoogleSignIn,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (googleLoading)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppTheme.primary,
                                  ),
                                )
                              else
                                const FaIcon(
                                  FontAwesomeIcons.google,
                                  size: 20,
                                  color: Color(0xFFDB4437),
                                ),
                              const SizedBox(width: 12),
                              Text(
                                googleLoading
                                    ? 'Connexion en cours…'
                                    : 'Continuer avec Google',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.navy,
                                  fontFamily: AppTheme.fontFamily,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      const SizedBox(height: 26),

                      // ── Lien inscription ───────────────────────────────
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Pas encore de compte ? ',
                            style: TextStyle(
                              color: AppTheme.slate,
                              fontSize: 13,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Get.toNamed(Routes.REGISTER),
                            child: const Text(
                              "S'inscrire",
                              style: TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                fontFamily: AppTheme.fontFamily,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Loading overlay global ─────────────────────────────────
              if (_isLoading)
                Positioned.fill(
                  child: AbsorbPointer(
                    child: Container(
                      color: AppTheme.navy.withOpacity(0.12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
