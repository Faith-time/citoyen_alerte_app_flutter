import 'dart:math' as math;
import 'package:citoyen_alerte_app_backup/core/services/auth_service.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/routes/app_pages.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dashboard/citizen_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainCtrl;
  late AnimationController _floatCtrl;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _contentFade;
  late Animation<Offset> _contentSlide;
  late Animation<double> _float;

  bool _isCheckingAuth = true;

  AuthService get _auth => AuthService.instance;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    _mainCtrl = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );

    _floatCtrl = AnimationController(
      duration: const Duration(milliseconds: 2800),
      vsync: this,
    )..repeat(reverse: true);

    _float = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut),
    );

    _logoFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _mainCtrl,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _logoScale = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(parent: _mainCtrl,
          curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );
    _contentFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _mainCtrl,
          curve: const Interval(0.45, 0.85, curve: Curves.easeOut)),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _mainCtrl,
        curve: const Interval(0.45, 0.85, curve: Curves.easeOut)));

    _mainCtrl.forward().then((_) => _checkAuthenticationStatus());
  }

  Future<void> _checkAuthenticationStatus() async {
    if (!_auth.isUserLoggedIn || _auth.authToken == null) {
      if (mounted) setState(() => _isCheckingAuth = false);
      return;
    }
    try {
      final apiService = Get.find<ApiService>();
      final response = await apiService
          .getCurrentUser()
          .timeout(const Duration(seconds: 5));
      if (response.success) {
        _navigateByRole(_auth.userRole.value ?? 'citizen');
      } else {
        await _auth.logout();
        if (mounted) setState(() => _isCheckingAuth = false);
      }
    } catch (e) {
      if (_auth.userRole.value != null) {
        _navigateByRole(_auth.userRole.value!);
      } else {
        try { await _auth.logout(); } catch (_) {}
        if (mounted) setState(() => _isCheckingAuth = false);
      }
    }
  }

  void _navigateByRole(String role) {
    if (Get.isRegistered<CitizenDashboardController>()) {
      Get.delete<CitizenDashboardController>(force: true);
    }
    switch (role.toLowerCase()) {
      case 'admin':     Get.offAllNamed(Routes.ADMIN_DASHBOARD); break;
      case 'agent':     Get.offAllNamed(Routes.AGENT_DASHBOARD); break;
      case 'authority': Get.offAllNamed(Routes.AUTHORITY_DASHBOARD); break;
      default:          Get.offAllNamed(Routes.CITIZEN_DASHBOARD); break;
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isCheckingAuth = true);
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
        );
        await Future.delayed(const Duration(milliseconds: 500));
        _navigateByRole(role);
      } else {
        final err = _auth.googleError.value;
        if (err.isNotEmpty) {
          Get.snackbar('Erreur', err,
              snackPosition: SnackPosition.BOTTOM,
              backgroundColor: AppTheme.error,
              colorText: AppTheme.white,
              margin: const EdgeInsets.all(16));
        }
        if (mounted) setState(() => _isCheckingAuth = false);
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Erreur inattendue : $e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.error,
          colorText: AppTheme.white,
          margin: const EdgeInsets.all(16));
      if (mounted) setState(() => _isCheckingAuth = false);
    }
  }

  @override
  void dispose() {
    _mainCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Fond artistique ──────────────────────────────────────────────
          const _ArtisticBackground(),

          // ── Contenu principal ────────────────────────────────────────────
          SafeArea(
            child: Column(
              children: [
                // ── Zone logo ───────────────────────────────────────────
                Expanded(
                  flex: 58,
                  child: AnimatedBuilder(
                    animation: _mainCtrl,
                    builder: (_, __) => FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: AnimatedBuilder(
                          animation: _float,
                          builder: (_, child) => Transform.translate(
                            offset: Offset(0, _float.value),
                            child: child,
                          ),
                          child: Center(
                            child: _LargeLogo(size: size.width * 0.52),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Zone titre + sous-titre ──────────────────────────────
                AnimatedBuilder(
                  animation: _mainCtrl,
                  builder: (_, __) => FadeTransition(
                    opacity: _contentFade,
                    child: SlideTransition(
                      position: _contentSlide,
                      child: _TitleSection(),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // ── Zone boutons ─────────────────────────────────────────
                Expanded(
                  flex: 38,
                  child: _isCheckingAuth
                      ? const Center(
                    child: CircularProgressIndicator(
                      color: AppTheme.yellow,
                      strokeWidth: 2.5,
                    ),
                  )
                      : AnimatedBuilder(
                    animation: _mainCtrl,
                    builder: (_, __) => FadeTransition(
                      opacity: _contentFade,
                      child: _ButtonsSection(
                        onGoogleSignIn: _handleGoogleSignIn,
                        auth: _auth,
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withOpacity(0.45),
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Fond artistique ─────────────────────────────────────────────────────────

class _ArtisticBackground extends StatelessWidget {
  const _ArtisticBackground();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox(
      width: size.width,
      height: size.height,
      child: CustomPaint(painter: _BgPainter()),
    );
  }
}

class _BgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Fond principal vert sénégal
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF0D5C2E),
    );

    // Bande jaune centrale subtile (drapeau)
    final yellowPath = Path()
      ..moveTo(w * 0.42, 0)
      ..lineTo(w * 0.58, 0)
      ..lineTo(w * 0.58, h)
      ..lineTo(w * 0.42, h)
      ..close();
    canvas.drawPath(yellowPath,
        Paint()..color = const Color(0xFFF2C94C).withOpacity(0.06));

    // Grande courbe verte claire en haut
    final topCurve = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..lineTo(w, h * 0.42)
      ..quadraticBezierTo(w * 0.5, h * 0.52, 0, h * 0.38)
      ..close();
    canvas.drawPath(topCurve,
        Paint()..color = const Color(0xFF137A3D).withOpacity(0.65));

    // Cercle décoratif jaune haut-droit
    canvas.drawCircle(
      Offset(w * 0.88, h * 0.08),
      w * 0.28,
      Paint()..color = const Color(0xFFF2C94C).withOpacity(0.08),
    );

    // Cercle décoratif rouge bas-gauche
    canvas.drawCircle(
      Offset(w * 0.12, h * 0.88),
      w * 0.32,
      Paint()..color = const Color(0xFFE05A47).withOpacity(0.07),
    );

    // Motif géométrique africain (losanges) - bande du bas
    final paint = Paint()
      ..color = const Color(0xFF2FAE63).withOpacity(0.18)
      ..style = PaintingStyle.fill;
    final double diamond = 18;
    final double spacing = 38;
    for (double x = 0; x < w; x += spacing) {
      for (double y = h * 0.85; y < h; y += spacing * 0.6) {
        final path = Path()
          ..moveTo(x + diamond / 2, y)
          ..lineTo(x + diamond, y + diamond / 3)
          ..lineTo(x + diamond / 2, y + diamond * 0.65)
          ..lineTo(x, y + diamond / 3)
          ..close();
        canvas.drawPath(path, paint);
      }
    }

    // Ligne décorative drapeau en bas
    canvas.drawRect(
      Rect.fromLTWH(0, h - 5, w / 3, 5),
      Paint()..color = const Color(0xFF137A3D),
    );
    canvas.drawRect(
      Rect.fromLTWH(w / 3, h - 5, w / 3, 5),
      Paint()..color = const Color(0xFFF2C94C),
    );
    canvas.drawRect(
      Rect.fromLTWH(2 * w / 3, h - 5, w / 3, 5),
      Paint()..color = const Color(0xFFE05A47),
    );
  }

  @override
  bool shouldRepaint(_BgPainter old) => false;
}

// ─── Grand logo ───────────────────────────────────────────────────────────────

class _LargeLogo extends StatelessWidget {
  final double size;
  const _LargeLogo({required this.size});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bouclier principal
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.08),
            border: Border.all(
              color: AppTheme.yellow.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(size * 0.1),
            child: CustomPaint(painter: _LargeShieldPainter()),
          ),
        ),

        const SizedBox(height: 20),

        // Nom de l'app
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            children: [
              TextSpan(
                text: 'ALERTE ',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.yellow,
                  letterSpacing: 2,
                ),
              ),
              TextSpan(
                text: 'CITOYEN',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Signaler pour un Sénégal meilleur',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            color: Colors.white.withOpacity(0.75),
            letterSpacing: 0.3,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 16),

        // Bande drapeau décorative
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            width: 80,
            height: 4,
            child: Row(
              children: [
                Expanded(child: Container(color: AppTheme.primaryGreen)),
                Expanded(child: Container(color: AppTheme.yellow)),
                Expanded(child: Container(color: AppTheme.coral)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LargeShieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final shieldPath = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.1)
      ..lineTo(w, h * 0.62)
      ..quadraticBezierTo(w, h * 0.86, w * 0.5, h)
      ..quadraticBezierTo(0, h * 0.86, 0, h * 0.62)
      ..lineTo(0, h * 0.1)
      ..close();

    // Ombre portée
    canvas.drawPath(
      shieldPath,
      Paint()
        ..color = Colors.black.withOpacity(0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Moitié gauche verte
    final leftPath = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(0, h * 0.1)
      ..lineTo(0, h * 0.62)
      ..quadraticBezierTo(0, h * 0.86, w * 0.5, h)
      ..close();

    // Moitié droite rouge
    final rightPath = Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.1)
      ..lineTo(w, h * 0.62)
      ..quadraticBezierTo(w, h * 0.86, w * 0.5, h)
      ..close();

    canvas.drawPath(leftPath, Paint()..color = const Color(0xFF137A3D));
    canvas.drawPath(rightPath, Paint()..color = const Color(0xFFE05A47));

    // Bande jaune centrale
    canvas.save();
    canvas.clipPath(shieldPath);
    final yellowPath = Path()
      ..moveTo(w * 0.33, 0)
      ..lineTo(w * 0.67, 0)
      ..lineTo(w * 0.67, h)
      ..lineTo(w * 0.33, h)
      ..close();
    canvas.drawPath(yellowPath, Paint()..color = const Color(0xFFF2C94C));
    canvas.restore();

    // Étoile verte centrale
    _drawStar(
      canvas: canvas,
      center: Offset(w * 0.5, h * 0.48),
      outerRadius: w * 0.18,
      innerRadius: w * 0.08,
      color: const Color(0xFF137A3D),
    );

    // Bordure du bouclier
    canvas.drawPath(
      shieldPath,
      Paint()
        ..color = const Color(0xFFF2C94C).withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  void _drawStar({
    required Canvas canvas,
    required Offset center,
    required double outerRadius,
    required double innerRadius,
    required Color color,
  }) {
    const points = 5;
    final path = Path();
    final angleStep = (math.pi * 2) / points;
    const startAngle = -math.pi / 2;

    for (int i = 0; i < points; i++) {
      final outerX = center.dx + outerRadius * math.cos(startAngle + i * angleStep);
      final outerY = center.dy + outerRadius * math.sin(startAngle + i * angleStep);
      final innerX = center.dx + innerRadius * math.cos(startAngle + (i + 0.5) * angleStep);
      final innerY = center.dy + innerRadius * math.sin(startAngle + (i + 0.5) * angleStep);
      if (i == 0) path.moveTo(outerX, outerY); else path.lineTo(outerX, outerY);
      path.lineTo(innerX, innerY);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LargeShieldPainter old) => false;
}

// ─── Titre ────────────────────────────────────────────────────────────────────

class _TitleSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

// ─── Boutons ──────────────────────────────────────────────────────────────────

class _ButtonsSection extends StatelessWidget {
  final VoidCallback onGoogleSignIn;
  final AuthService auth;

  const _ButtonsSection({
    required this.onGoogleSignIn,
    required this.auth,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // SE CONNECTER
          _SplashButton(
            label: 'SE CONNECTER',
            onTap: () => Get.toNamed(Routes.LOGIN),
            backgroundColor: AppTheme.yellow,
            textColor: AppTheme.darkBlue,
            icon: Icons.login_rounded,
          ),

          const SizedBox(height: 12),

          // S'INSCRIRE
          _SplashButton(
            label: "S'INSCRIRE",
            onTap: () => Get.toNamed(Routes.REGISTER),
            backgroundColor: Colors.white.withOpacity(0.15),
            textColor: Colors.white,
            icon: Icons.person_add_rounded,
            hasBorder: true,
          ),

          const SizedBox(height: 20),

          // Séparateur
          Row(
            children: [
              Expanded(child: Divider(color: Colors.white.withOpacity(0.2), thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  'OU',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.5),
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Expanded(child: Divider(color: Colors.white.withOpacity(0.2), thickness: 1)),
            ],
          ),

          const SizedBox(height: 16),

          // Continuer avec Google
          Obx(() {
            final loading = auth.isGoogleLoading.value;
            return GestureDetector(
              onTap: loading ? null : onGoogleSignIn,
              child: Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (loading)
                      const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppTheme.primaryGreen),
                      )
                    else
                      const FaIcon(FontAwesomeIcons.google,
                          size: 16, color: Color(0xFFDB4437)),
                    const SizedBox(width: 10),
                    Text(
                      loading ? 'Connexion...' : 'Continuer avec Google',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkBlue,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SplashButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;
  final bool hasBorder;

  const _SplashButton({
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.textColor,
    required this.icon,
    this.hasBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: hasBorder
              ? Border.all(color: Colors.white.withOpacity(0.5), width: 1.5)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: textColor, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}