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
      statusBarIconBrightness: Brightness.dark,
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
      CurvedAnimation(
          parent: _mainCtrl,
          curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );
    _logoScale = Tween<double>(begin: 0.4, end: 1).animate(
      CurvedAnimation(
          parent: _mainCtrl,
          curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );
    _contentFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
          parent: _mainCtrl,
          curve: const Interval(0.45, 0.85, curve: Curves.easeOut)),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _mainCtrl,
        curve: const Interval(0.45, 0.85, curve: Curves.easeOut)));

    _mainCtrl.forward().then((_) => _checkAuthenticationStatus());
  }

  // ─── Logique inchangée ────────────────────────────────────────────────────
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
        try {
          await _auth.logout();
        } catch (_) {}
        if (mounted) setState(() => _isCheckingAuth = false);
      }
    }
  }

  void _navigateByRole(String role) {
    if (Get.isRegistered<CitizenDashboardController>()) {
      Get.delete<CitizenDashboardController>(force: true);
    }
    switch (role.toLowerCase()) {
      case 'admin':
        Get.offAllNamed(Routes.ADMIN_DASHBOARD);
        break;
      case 'agent':
        Get.offAllNamed(Routes.AGENT_DASHBOARD);
        break;
      case 'authority':
        Get.offAllNamed(Routes.AUTHORITY_DASHBOARD);
        break;
      default:
        Get.offAllNamed(Routes.CITIZEN_DASHBOARD);
        break;
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

  // ─── BUILD ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          const _SoftBackground(),
          SafeArea(
            child: Column(
              children: [
                // ── Logo + nom ──────────────────────────────────────────
                Expanded(
                  flex: 66,
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
                            child: _LargeLogo(width: size.width),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Boutons ─────────────────────────────────────────────
                Expanded(
                  flex: 34,
                  child: _isCheckingAuth
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.primary,
                            strokeWidth: 2.5,
                          ),
                        )
                      : FadeTransition(
                          opacity: _contentFade,
                          child: SlideTransition(
                            position: _contentSlide,
                            child: _ButtonsSection(
                              onGoogleSignIn: _handleGoogleSignIn,
                              auth: _auth,
                            ),
                          ),
                        ),
                ),

                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: AppTheme.slate.withOpacity(0.7),
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

// ─── Fond bleu glacier avec grands cercles doux ──────────────────────────────

class _SoftBackground extends StatelessWidget {
  const _SoftBackground();

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

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()
        ..shader = AppTheme.canvasGradient
            .createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    canvas.drawCircle(Offset(w * 0.02, h * 0.22), w * 0.36,
        Paint()..color = AppTheme.primaryLight.withOpacity(0.10));
    canvas.drawCircle(Offset(w * 1.0, h * 0.90), w * 0.42,
        Paint()..color = AppTheme.primaryLight.withOpacity(0.12));
    canvas.drawCircle(Offset(w * 0.95, h * 0.04), w * 0.22,
        Paint()..color = Colors.white.withOpacity(0.55));
  }

  @override
  bool shouldRepaint(_BgPainter old) => false;
}

// ─── Logo + titre + illustration ─────────────────────────────────────────────

class _LargeLogo extends StatelessWidget {
  final double width;
  const _LargeLogo({required this.width});

  @override
  Widget build(BuildContext context) {
    final shield = width * 0.20;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouclier en relief
            Container(
              width: shield + 22,
              height: shield + 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surface,
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: AppTheme.neuShadow(depth: 1.1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(11),
                child: const ShieldLogo(),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Alerte Citoyen',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppTheme.navy,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Ensemble pour\nun Sénégal plus sûr',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 14,
                height: 1.35,
                color: AppTheme.slate,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: width * 0.82,
              height: width * 0.82 * 0.62,
              child: CustomPaint(painter: _CityPinPainter()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Illustration : petite ville sur un socle clair + grande épingle bouclier.
class _CityPinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 300;
    final sy = size.height / 186;
    canvas.save();
    canvas.scale(sx, sy);

    // Socle (ellipse blanche en relief)
    final base = Rect.fromCenter(
        center: const Offset(150, 150), width: 270, height: 62);
    canvas.drawOval(
      base.shift(const Offset(0, 8)),
      Paint()
        ..color = AppTheme.primary.withOpacity(0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawOval(base, Paint()..color = Colors.white);
    canvas.drawOval(
      base.deflate(14),
      Paint()..color = AppTheme.canvas,
    );

    // Immeubles
    void building(Rect r, Color c1, Color c2) {
      final rr = RRect.fromRectAndRadius(r, const Radius.circular(7));
      canvas.drawRRect(
        rr,
        Paint()
          ..shader = LinearGradient(
            colors: [c1, c2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(r),
      );
      final win = Paint()..color = Colors.white.withOpacity(0.85);
      for (double y = r.top + 12; y < r.bottom - 14; y += 15) {
        for (double x = r.left + 10; x < r.right - 12; x += 14) {
          canvas.drawRRect(
              RRect.fromRectAndRadius(
                  Rect.fromLTWH(x, y, 7, 8), const Radius.circular(2)),
              win);
        }
      }
    }

    building(const Rect.fromLTWH(48, 52, 62, 90), const Color(0xFFA9CCF4),
        const Color(0xFF6FA6E6));
    building(const Rect.fromLTWH(104, 82, 48, 62), const Color(0xFFC6DDF8),
        const Color(0xFF8DBBEE));

    // Arbres
    void tree(double x, double y, double r) {
      canvas.drawRect(Rect.fromLTWH(x - 2, y, 4, r * 0.9),
          Paint()..color = const Color(0xFF6C93BC));
      canvas.drawCircle(Offset(x, y), r,
          Paint()..color = const Color(0xFF5BB5A2).withOpacity(0.95));
      canvas.drawCircle(Offset(x - r * 0.3, y - r * 0.3), r * 0.45,
          Paint()..color = Colors.white.withOpacity(0.25));
    }

    tree(36, 124, 15);
    tree(258, 120, 17);
    tree(246, 138, 11);

    // Épingle
    const c = Offset(196, 86);
    const r = 46.0;
    final pin = Path()
      ..moveTo(c.dx, c.dy + r + 40)
      ..cubicTo(c.dx - 14, c.dy + r + 8, c.dx - r, c.dy + r * 0.55,
          c.dx - r, c.dy)
      ..arcToPoint(Offset(c.dx + r, c.dy),
          radius: const Radius.circular(r), clockwise: true)
      ..cubicTo(c.dx + r, c.dy + r * 0.55, c.dx + 14, c.dy + r + 8, c.dx,
          c.dy + r + 40)
      ..close();
    canvas.drawPath(
      pin.shift(const Offset(0, 8)),
      Paint()
        ..color = AppTheme.primaryDark.withOpacity(0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.drawPath(
      pin,
      Paint()
        ..shader = const LinearGradient(
          colors: [AppTheme.primaryLight, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Rect.fromCircle(center: c, radius: r + 30)),
    );
    canvas.drawCircle(c, r * 0.64, Paint()..color = Colors.white);

    final sh = Path()
      ..moveTo(c.dx, c.dy - 21)
      ..lineTo(c.dx + 17, c.dy - 14)
      ..lineTo(c.dx + 17, c.dy + 4)
      ..quadraticBezierTo(c.dx + 17, c.dy + 17, c.dx, c.dy + 23)
      ..quadraticBezierTo(c.dx - 17, c.dy + 17, c.dx - 17, c.dy + 4)
      ..lineTo(c.dx - 17, c.dy - 14)
      ..close();
    canvas.drawPath(
      sh,
      Paint()
        ..shader = const LinearGradient(
          colors: [AppTheme.primaryLight, AppTheme.primaryDark],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(sh.getBounds()),
    );
    canvas.drawPath(
      sh.shift(Offset.zero),
      Paint()
        ..color = Colors.white.withOpacity(0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CityPinPainter old) => false;
}

// ─── Boutons ─────────────────────────────────────────────────────────────────

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
          PrimaryActionButton(
            label: 'Commencer',
            onTap: () => Get.toNamed(Routes.REGISTER),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () => Get.toNamed(Routes.LOGIN),
            child: const Text('Se connecter'),
          ),
          const SizedBox(height: 4),
          Obx(() {
            final loading = auth.isGoogleLoading.value;
            return NeuCard(
              padding: const EdgeInsets.symmetric(vertical: 13),
              radius: AppTheme.radiusMd,
              depth: 0.6,
              onTap: loading ? null : onGoogleSignIn,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primary),
                    )
                  else
                    const FaIcon(FontAwesomeIcons.google,
                        size: 16, color: Color(0xFFDB4437)),
                  const SizedBox(width: 10),
                  Text(
                    loading ? 'Connexion...' : 'Continuer avec Google',
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.navy,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
