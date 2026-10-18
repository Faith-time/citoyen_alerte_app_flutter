import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';

class VerifyPhoneScreen extends StatefulWidget {
  const VerifyPhoneScreen({super.key});

  @override
  State<VerifyPhoneScreen> createState() => _VerifyPhoneScreenState();
}

class _VerifyPhoneScreenState extends State<VerifyPhoneScreen> {
  static const int _length = 6;
  final List<TextEditingController> _ctrls =
      List.generate(_length, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(_length, (_) => FocusNode());

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _code => _ctrls.map((c) => c.text).join();

  void _submit() {
    if (_code.length < _length) {
      Get.snackbar(
        'Code incomplet',
        'Entrez les $_length chiffres reçus par SMS.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.error,
        colorText: AppTheme.white,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }
    // TODO: brancher l'API de vérification du téléphone.
    Get.snackbar(
      'Bientôt disponible',
      'La vérification du téléphone arrive prochainement.',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: AppTheme.navy,
      colorText: AppTheme.white,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }

  Widget _box(int i) {
    return SizedBox(
      width: 46,
      height: 56,
      child: TextField(
        controller: _ctrls[i],
        focusNode: _nodes[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(1),
        ],
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppTheme.navy,
        ),
        decoration: const InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: (v) {
          if (v.isNotEmpty && i < _length - 1) _nodes[i + 1].requestFocus();
          if (v.isEmpty && i > 0) _nodes[i - 1].requestFocus();
        },
      ),
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
                  child: BrickIcon(
                    icon: Icons.phone_android_rounded,
                    color: AppTheme.accentAmber,
                    size: 88,
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  'Vérification du téléphone',
                  textAlign: TextAlign.center,
                  style: AppTheme.h1,
                ),
                const SizedBox(height: 10),
                Text(
                  'Entrez le code à 6 chiffres envoyé par SMS.',
                  textAlign: TextAlign.center,
                  style: AppTheme.body.copyWith(color: AppTheme.slate),
                ),
                const SizedBox(height: 14),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_length, _box),
                ),
                const SizedBox(height: 28),
                PrimaryActionButton(
                  label: 'Vérifier',
                  icon: Icons.verified_rounded,
                  onTap: _submit,
                ),
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: () => Get.snackbar(
                      'Bientôt disponible',
                      'Le renvoi du code arrive prochainement.',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: AppTheme.navy,
                      colorText: AppTheme.white,
                      margin: const EdgeInsets.all(16),
                      borderRadius: 12,
                    ),
                    child: const Text('Renvoyer le code'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
