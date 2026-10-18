import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    // TODO: brancher l'API de réinitialisation du mot de passe.
    Get.snackbar(
      'Bientôt disponible',
      'La réinitialisation du mot de passe arrive prochainement.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.navy,
      colorText: AppTheme.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.canvasGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  const SizedBox(height: 36),
                  const Center(
                    child: BrickIcon(icon: Icons.lock_reset_rounded, size: 88),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Mot de passe oublié ?',
                    textAlign: TextAlign.center,
                    style: AppTheme.h1,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Entrez votre email : nous vous enverrons un lien pour choisir un nouveau mot de passe.',
                    textAlign: TextAlign.center,
                    style: AppTheme.body.copyWith(color: AppTheme.slate),
                  ),
                  const SizedBox(height: 14),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 15,
                      color: AppTheme.navy,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'exemple@email.com',
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.email_outlined,
                            color: AppTheme.primary, size: 20),
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
                  const SizedBox(height: 26),
                  PrimaryActionButton(
                    label: 'Envoyer le lien',
                    icon: Icons.send_rounded,
                    onTap: _submit,
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: TextButton(
                      onPressed: () => Get.back(),
                      child: const Text('Retour à la connexion'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
