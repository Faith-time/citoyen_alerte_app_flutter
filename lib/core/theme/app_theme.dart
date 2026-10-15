import 'package:flutter/material.dart';

class AppTheme {
  // ── Couleurs principales (palette Sénégal) ───────────────────────────────
  static const Color primaryGreen = Color(0xFF137A3D); // Vert Sénégal
  static const Color darkGreen = Color(0xFF0D5C2E); // Vert profond (headers)
  static const Color lightGreen = Color(0xFF2FAE63); // Vert Clair
  static const Color yellow = Color(0xFFF2C94C); // Jaune Lumière
  static const Color coral = Color(0xFFE05A47); // Corail Doux

  // ── Couleurs neutres ─────────────────────────────────────────────────────
  static const Color darkBlue = Color(0xFF1F2937); // Bleu Foncé (texte fort)
  static const Color greyMedium = Color(0xFF6B7280); // Gris Moyen (texte secondaire)
  static const Color greyLight = Color(0xFFE5E7EB); // Gris Clair (bordures)
  static const Color white = Color(0xFFFFFFFF);

  // ── Couleurs d'état ──────────────────────────────────────────────────────
  static const Color success = Color(0xFF27AE60);
  static const Color warning = Color(0xFFF2C94C);
  static const Color error = Color(0xFFE05A47);
  static const Color info = Color(0xFF3B82F6);
  static const Color purple = Color(0xFF8B5CF6);

  // ── Alias ────────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF5F7F9);
  static const Color black = darkBlue;
  static const Color grey = greyMedium;

  // ── Typographie ──────────────────────────────────────────────────────────
  static const String fontFamily = 'Poppins';

  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    color: darkBlue,
    height: 1.15,
  );
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: darkBlue,
  );
  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: darkBlue,
  );
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: darkBlue,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: greyMedium,
  );
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: greyMedium,
    letterSpacing: 0.6,
  );

  // ── Rayons & espacements standard ────────────────────────────────────────
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 28;
  static const double gap = 16;

  // ── Ombres standard ──────────────────────────────────────────────────────
  static List<BoxShadow> cardShadow({Color? tint, double opacity = 0.06}) => [
    BoxShadow(
      color: (tint ?? Colors.black).withOpacity(opacity),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> elevatedShadow(Color color) => [
    BoxShadow(
      color: color.withOpacity(0.30),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ];

  // ── Dégradés artistiques ─────────────────────────────────────────────────
  static const LinearGradient heroGradient = LinearGradient(
    colors: [darkGreen, primaryGreen, lightGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ctaGradient = LinearGradient(
    colors: [darkGreen, primaryGreen],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [primaryGreen, yellow],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient flagGradient = LinearGradient(
    colors: [primaryGreen, yellow, coral],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ── Compatibilité avec l'ancien thème ────────────────────────────────────
  static const Color senegalGreen = primaryGreen;
  static const Color senegalYellow = yellow;
  static const Color senegalRed = coral;
  static const Color primaryYellow = yellow;
  static const Color primaryRed = coral;

  // ── ThemeData global Flutter ─────────────────────────────────────────────
  static ThemeData get themeData => ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: background,
    primaryColor: primaryGreen,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      primary: primaryGreen,
      secondary: yellow,
      error: error,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primaryGreen,
      foregroundColor: white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: white,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: white,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
        ),
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
        elevation: 0,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: greyLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: BorderSide(color: greyLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMd),
        borderSide: const BorderSide(color: primaryGreen, width: 1.6),
      ),
      hintStyle: const TextStyle(
        fontFamily: fontFamily,
        color: greyMedium,
        fontSize: 13,
      ),
    ),
  );
}

/// Pattern de fond (réutilisable). S'étend sur la taille du parent.
class SenegalPatternBackground extends StatelessWidget {
  const SenegalPatternBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _PatternPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    canvas.drawCircle(
      Offset(w * 0.88, h * 0.15),
      w * 0.28,
      Paint()..color = AppTheme.yellow.withOpacity(0.08),
    );
    canvas.drawCircle(
      Offset(w * 0.85, h * 0.12),
      w * 0.16,
      Paint()..color = Colors.white.withOpacity(0.06),
    );

    final paint = Paint()..color = Colors.white.withOpacity(0.045);
    const double d = 20;
    for (double x = -10; x < w; x += 36) {
      for (double y = 0; y < h; y += 30) {
        final path = Path()
          ..moveTo(x + d / 2, y)
          ..lineTo(x + d, y + d * 0.45)
          ..lineTo(x + d / 2, y + d * 0.9)
          ..lineTo(x, y + d * 0.45)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PatternPainter old) => false;
}

/// Bandeau "drapeau" 3 couleurs (vert / jaune / corail)
class FlagStripe extends StatelessWidget {
  final double height;
  const FlagStripe({super.key, this.height = 4});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          Expanded(child: Container(color: AppTheme.primaryGreen.withOpacity(0.85))),
          Expanded(child: Container(color: AppTheme.yellow)),
          Expanded(child: Container(color: AppTheme.coral)),
        ],
      ),
    );
  }
}

/// SectionHeader — responsive : utilise minHeight au lieu de forcer une taille intérieure.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  /// Hauteur "visuelle" souhaitée (sans la status bar). Par défaut ~96.
  final double height;

  /// Hauteur minimale et maximale (visuelle).
  final double minHeight;
  final double maxHeight;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.height = 96,
    this.minHeight = 72,
    this.maxHeight = 140,
  });

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top;
    final double clampedHeight = height.clamp(minHeight, maxHeight);

  return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(AppTheme.radiusXl),
        bottomRight: Radius.circular(AppTheme.radiusXl),
      ),
      child: Container(
        // minHeight = hauteur visuelle + topInset ; le container peut être plus grand si requis
        constraints: BoxConstraints(minHeight: clampedHeight + topInset),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
                child: const SenegalPatternBackground(),
              ),
            ),
            const Positioned(bottom: 0, left: 0, right: 0, child: FlagStripe()),

            // On gère explicitement le padding top pour tenir compte du notch/status bar
            Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: topInset + 14, // status bar + marge interne
                bottom: 14,
              ),
              // IMPORTANT: ne PAS forcer une taille fixe ici ; laisser Column s'adapter.
              child: Row(
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Badge pastille de statut réutilisable
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

/// Carte statistique homogène (icône + valeur + libellé).
class StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.cardShadow(),
        border: Border.all(color: AppTheme.greyLight.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTheme.caption),
        ],
      ),
    );
  }
}

/// Bouton primaire plein, dégradé vert, avec icône — pour tous les CTA.
class PrimaryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          gradient: AppTheme.ctaGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.elevatedShadow(AppTheme.primaryGreen),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}