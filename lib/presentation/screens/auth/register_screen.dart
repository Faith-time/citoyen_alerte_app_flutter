import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/routes/app_pages.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/core/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptTerms = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _navigateByRole(String role) {
    switch (role) {
      case 'admin':     Get.offAllNamed(Routes.ADMIN_DASHBOARD); break;
      case 'agent':     Get.offAllNamed(Routes.AGENT_DASHBOARD); break;
      case 'authority': Get.offAllNamed(Routes.AUTHORITY_DASHBOARD); break;
      default:          Get.offAllNamed(Routes.CITIZEN_DASHBOARD); break;
    }
  }

  // ─── Inscription ──────────────────────────────────────────────────────────
  Future<void> _handleRegister() async {
    if (!_acceptTerms) {
      _showSnack('Veuillez accepter les conditions d\'utilisation',
          isError: true, bottom: true);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final api = Get.find<ApiService>();
      final response = await api.register({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'password': _passwordController.text,
        'password_confirmation': _confirmPasswordController.text,
        'role': 'citizen',
      });

      if (response.success) {
        final role = AuthService.instance.userRole.value ?? 'citizen';
        _showSnack('Bienvenue ${_nameController.text} !',
            isError: false, bottom: true);
        await Future.delayed(const Duration(milliseconds: 500));
        _navigateByRole(role);
      } else {
        _showSnack(response.message ?? 'Une erreur est survenue',
            isError: true, bottom: true);
      }
    } catch (_) {
      _showSnack('Impossible de joindre le serveur.',
          isError: true, bottom: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => _isLoading = false);
    _showSnack('Fonctionnalité bientôt disponible',
        isError: false, bottom: true);
  }

  void _showSnack(String msg,
      {required bool isError, required bool bottom}) {
    Get.snackbar(
      isError ? 'Erreur' : 'Succès',
      msg,
      snackPosition:
      bottom ? SnackPosition.BOTTOM : SnackPosition.TOP,
      backgroundColor: isError ? AppTheme.error : AppTheme.success,
      colorText: AppTheme.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                // ── AppBar custom ──────────────────────────────────────────
                _buildTopBar(),

                // ── Formulaire scrollable ──────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo
                          _buildLogo(),
                          const SizedBox(height: 20),

                          // Titre
                          const Text(
                            'Créez votre compte',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkBlue,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Rejoignez la communauté et signalez les incidents',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              color: AppTheme.greyMedium,
                            ),
                          ),

                          const SizedBox(height: 28),

                          // ── Avatar ──────────────────────────────────────
                          _buildAvatar(),
                          const SizedBox(height: 28),

                          // ── Champs ──────────────────────────────────────
                          _buildField(
                            controller: _nameController,
                            label: 'Nom complet',
                            hint: 'Prénom Nom',
                            icon: Icons.person_outline_rounded,
                            capitalization: TextCapitalization.words,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Veuillez entrer votre nom';
                              }
                              if (v.trim().length < 3) {
                                return 'Minimum 3 caractères';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          _buildField(
                            controller: _emailController,
                            label: 'Email',
                            hint: 'exemple@email.com',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
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

                          const SizedBox(height: 14),

                          _buildField(
                            controller: _phoneController,
                            label: 'Téléphone',
                            hint: '77 123 45 67',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            isRequired: false,
                            validator: (v) {
                              if (v != null && v.trim().isNotEmpty) {
                                final clean = v.trim().replaceAll(' ', '');
                                if (!RegExp(r'^7[0-9]{8}$').hasMatch(clean)) {
                                  return 'Numéro invalide (ex: 77 123 45 67)';
                                }
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          _buildPasswordField(
                            controller: _passwordController,
                            label: 'Mot de passe',
                            hint: 'Au moins 8 caractères',
                            obscure: _obscurePassword,
                            onToggle: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Veuillez entrer un mot de passe';
                              }
                              if (v.length < 8) {
                                return 'Minimum 8 caractères';
                              }
                              if (!v.contains(RegExp(r'[A-Z]'))) {
                                return 'Au moins une majuscule requise';
                              }
                              if (!v.contains(RegExp(r'[0-9]'))) {
                                return 'Au moins un chiffre requis';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          _buildPasswordField(
                            controller: _confirmPasswordController,
                            label: 'Confirmer le mot de passe',
                            hint: 'Retapez votre mot de passe',
                            obscure: _obscureConfirm,
                            onToggle: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm),
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Veuillez confirmer votre mot de passe';
                              }
                              if (v != _passwordController.text) {
                                return 'Les mots de passe ne correspondent pas';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 20),

                          // ── Conditions ──────────────────────────────────
                          _buildTermsRow(),

                          const SizedBox(height: 28),

                          // ── Bouton S'inscrire ────────────────────────────
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleRegister,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryGreen,
                                foregroundColor: AppTheme.white,
                                disabledBackgroundColor: AppTheme.greyLight,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: AppTheme.white,
                                  strokeWidth: 2,
                                ),
                              )
                                  : const Text(
                                "S'INSCRIRE",
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // ── Séparateur OU ────────────────────────────────
                          Row(
                            children: [
                              const Expanded(
                                  child: Divider(
                                      color: AppTheme.greyLight, thickness: 1)),
                              Padding(
                                padding:
                                const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                  'OU',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color:
                                    AppTheme.greyMedium.withOpacity(0.7),
                                  ),
                                ),
                              ),
                              const Expanded(
                                  child: Divider(
                                      color: AppTheme.greyLight, thickness: 1)),
                            ],
                          ),

                          const SizedBox(height: 20),

                          // ── Google ───────────────────────────────────────
                          SizedBox(
                            height: 56,
                            child: OutlinedButton.icon(
                              onPressed:
                              _isLoading ? null : _handleGoogleSignIn,
                              icon: const FaIcon(FontAwesomeIcons.google,
                                  size: 18, color: Color(0xFFDB4437)),
                              label: const Text(
                                "S'inscrire avec Google",
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.darkBlue,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: AppTheme.white,
                                side: const BorderSide(
                                    color: AppTheme.greyLight, width: 1),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // ── Lien connexion ───────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Déjà un compte ? ',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  color: AppTheme.greyMedium,
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Get.back(),
                                child: const Text(
                                  'Se connecter',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryGreen,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Loading overlay ────────────────────────────────────────────────
          if (_isLoading)
            Container(
              color: AppTheme.darkBlue.withOpacity(0.25),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor:
                  AlwaysStoppedAnimation<Color>(AppTheme.primaryGreen),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ─── AppBar custom ────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          // Bouton retour
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.greyLight),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.darkBlue.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: AppTheme.darkBlue),
              onPressed: () => Get.back(),
              padding: EdgeInsets.zero,
            ),
          ),
          const Expanded(
            child: Text(
              'Créer un compte',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppTheme.darkBlue,
              ),
            ),
          ),
          const SizedBox(width: 44), // équilibre le back button
        ],
      ),
    );
  }

  // ─── Logo ─────────────────────────────────────────────────────────────────
  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryGreen.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.asset(
            'assets/images/alert_logo.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  // ─── Avatar ───────────────────────────────────────────────────────────────
  Widget _buildAvatar() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.greyLight,
                  border: Border.all(
                    color: AppTheme.primaryGreen,
                    width: 2.5,
                  ),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  size: 44,
                  color: AppTheme.greyMedium,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => Get.snackbar(
                    'Avatar',
                    'Fonctionnalité à implémenter',
                    snackPosition: SnackPosition.BOTTOM,
                    //backgroundColor: AppTheme.info,
                    colorText: AppTheme.white,
                    margin: const EdgeInsets.all(16),
                  ),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      size: 14,
                      color: AppTheme.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Ajouter une photo (optionnel)',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: AppTheme.greyMedium,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Champ texte générique ────────────────────────────────────────────────
  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    bool isRequired = true,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: AppTheme.darkBlue,
      ),
      decoration: _deco(label: label, hint: hint, icon: icon),
      validator: validator,
    );
  }

  // ─── Champ mot de passe ───────────────────────────────────────────────────
  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 14,
        color: AppTheme.darkBlue,
      ),
      decoration: _deco(
        label: label,
        hint: hint,
        icon: Icons.lock_outline_rounded,
      ).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            obscure
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: AppTheme.greyMedium,
            size: 20,
          ),
          onPressed: onToggle,
        ),
      ),
      validator: validator,
    );
  }

  // ─── Décoration commune des champs ────────────────────────────────────────
  InputDecoration _deco({
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primaryGreen.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
      ),
      filled: true,
      fillColor: AppTheme.white,
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.greyLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.greyLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide:
        const BorderSide(color: AppTheme.primaryGreen, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.error, width: 2),
      ),
      labelStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        color: AppTheme.greyMedium,
      ),
      hintStyle: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 13,
        color: AppTheme.greyMedium,
      ),
    );
  }

  // ─── Ligne conditions d'utilisation ──────────────────────────────────────
  Widget _buildTermsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: Checkbox(
            value: _acceptTerms,
            onChanged: (v) => setState(() => _acceptTerms = v ?? false),
            activeColor: AppTheme.primaryGreen,
            side: const BorderSide(color: AppTheme.greyMedium, width: 1.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _acceptTerms = !_acceptTerms),
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppTheme.greyMedium,
                  height: 1.5,
                ),
                children: [
                  TextSpan(text: "J'accepte les "),
                  TextSpan(
                    text: "Conditions d'utilisation",
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(text: ' et la '),
                  TextSpan(
                    text: 'Politique de confidentialité',
                    style: TextStyle(
                      color: AppTheme.primaryGreen,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

  }
}