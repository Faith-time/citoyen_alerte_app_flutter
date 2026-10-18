import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────
///  ALERTE CITOYEN — Système de design « Bleu néomorphique »
///  Palette mesurée sur la maquette : fonds bleu glacier, boutons dégradés
///  bleu royal, texte bleu nuit, cartes blanches en relief doux
///  (lumière haut-gauche, ombre bleutée bas-droite).
///
///  Tous les anciens noms (primaryGreen, darkGreen, yellow, coral, cardShadow…)
///  sont conservés : les écrans existants adoptent la palette sans modification.
/// ─────────────────────────────────────────────────────────────────────────
class AppTheme {
  // ── Palette bleue (mesurée sur la maquette) ─────────────────────────────
  static const Color primary = Color(0xFF186DCC); // bleu bouton
  static const Color primaryDark = Color(0xFF0D52B9); // bleu profond (nav active)
  static const Color primaryLight = Color(0xFF3F8EE6); // bleu clair (haut du dégradé)
  static const Color navy = Color(0xFF023270); // titres, texte fort
  static const Color slate = Color(0xFF5B76A0); // texte secondaire
  static const Color mist = Color(0xFFDDE9F8); // bordures / séparateurs
  static const Color surface = Color(0xFFFFFFFF); // cartes
  static const Color canvas = Color(0xFFE9F3FE); // fond d'écran
  static const Color canvasLight = Color(0xFFF3F9FF);
  static const Color accentAmber = Color(0xFFF5A524); // ampoule / alerte
  static const Color accentRose = Color(0xFFE5574A); // urgent
  static const Color accentTeal = Color(0xFF2FA77A); // succès

  // ── Anciens noms (compatibilité) ─────────────────────────────────────────
  static const Color primaryGreen = primary;
  static const Color darkGreen = primaryDark;
  static const Color lightGreen = primaryLight;
  static const Color yellow = accentAmber;
  static const Color coral = accentRose;

  static const Color darkBlue = navy;
  static const Color greyMedium = slate;
  static const Color greyLight = mist;
  static const Color white = Color(0xFFFFFFFF);

  static const Color success = accentTeal;
  static const Color warning = Color(0xFFF5A524);
  static const Color error = accentRose;
  static const Color info = Color(0xFF3980D7);
  static const Color purple = Color(0xFF5B6CE0);

  static const Color background = canvas;
  static const Color black = navy;
  static const Color grey = slate;

  static const Color senegalGreen = primary;
  static const Color senegalYellow = accentAmber;
  static const Color senegalRed = accentRose;
  static const Color primaryYellow = accentAmber;
  static const Color primaryRed = accentRose;

  // ── Typographie ──────────────────────────────────────────────────────────
  static const String fontFamily = 'Poppins';

  static const TextStyle h1 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: navy,
    height: 1.15,
    letterSpacing: -0.4,
  );
  static const TextStyle h2 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: navy,
  );
  static const TextStyle h3 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: navy,
  );
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: navy,
    height: 1.4,
  );
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: slate,
  );
  static const TextStyle label = TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: slate,
    letterSpacing: 0.6,
  );

  // ── Rayons & espacements ─────────────────────────────────────────────────
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 22;
  static const double radiusXl = 30;
  static const double gap = 16;

  // ── Ombres néomorphiques ─────────────────────────────────────────────────
  static List<BoxShadow> neuShadow({double depth = 1, Color? tint}) {
    final t = tint ?? const Color(0xFF7FA3D6);
    return [
      BoxShadow(
        color: Colors.white.withOpacity(0.95),
        blurRadius: 12 * depth,
        offset: Offset(-5 * depth, -5 * depth),
      ),
      BoxShadow(
        color: t.withOpacity(0.34),
        blurRadius: 18 * depth,
        offset: Offset(6 * depth, 9 * depth),
      ),
    ];
  }

  /// Compatibilité : ancienne ombre de carte → maintenant néomorphique.
  static List<BoxShadow> cardShadow({Color? tint, double opacity = 0.06}) =>
      neuShadow(depth: 0.8, tint: tint);

  /// Ombre colorée sous les boutons / éléments d'action.
  static List<BoxShadow> elevatedShadow(Color color) => [
        BoxShadow(
          color: color.withOpacity(0.35),
          blurRadius: 18,
          offset: const Offset(0, 9),
        ),
        BoxShadow(
          color: Colors.white.withOpacity(0.6),
          blurRadius: 6,
          offset: const Offset(-2, -2),
        ),
      ];

  // ── Dégradés ─────────────────────────────────────────────────────────────
  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF3980D7), Color(0xFF186DCC), Color(0xFF0D52B9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient ctaGradient = LinearGradient(
    colors: [Color(0xFF3980D7), Color(0xFF1060C2)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    colors: [Color(0xFF2F75C4), Color(0xFF5398E4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Ancien dégradé « drapeau » : devient un dégradé bleu monochrome.
  static const LinearGradient flagGradient = LinearGradient(
    colors: [Color(0xFF0D52B9), Color(0xFF3980D7), Color(0xFF7DB4F0)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const LinearGradient canvasGradient = LinearGradient(
    colors: [Color(0xFFF3F9FF), Color(0xFFE3EFFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── ThemeData global ─────────────────────────────────────────────────────
  static ThemeData get themeData => ThemeData(
        useMaterial3: true,
        fontFamily: fontFamily,
        scaffoldBackgroundColor: canvas,
        primaryColor: primary,
        splashFactory: InkRipple.splashFactory,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primary,
          primary: primary,
          secondary: accentAmber,
          error: error,
          surface: surface,
          brightness: Brightness.light,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: canvas,
          foregroundColor: navy,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: navy),
          titleTextStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: navy,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: white,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            elevation: 3,
            shadowColor: primary.withOpacity(0.45),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            backgroundColor: surface,
            side: const BorderSide(color: mist, width: 1.2),
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radiusMd),
            ),
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: primary,
            textStyle: const TextStyle(
              fontFamily: fontFamily,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: primary,
          foregroundColor: white,
          elevation: 6,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: mist),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: mist),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: primary, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: accentRose),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radiusMd),
            borderSide: const BorderSide(color: accentRose, width: 1.6),
          ),
          hintStyle: TextStyle(
            fontFamily: fontFamily,
            color: slate.withOpacity(0.7),
            fontSize: 13,
          ),
          labelStyle: const TextStyle(
            fontFamily: fontFamily,
            color: slate,
            fontSize: 13,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: primary,
          unselectedItemColor: slate,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: TextStyle(
            fontFamily: fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(fontFamily: fontFamily, fontSize: 11),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: surface,
          indicatorColor: primary.withOpacity(0.12),
          elevation: 0,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              fontFamily: fontFamily,
              fontSize: 11,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w600
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected) ? primary : slate,
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: surface,
          selectedColor: primary.withOpacity(0.12),
          side: const BorderSide(color: mist),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          labelStyle: const TextStyle(
            fontFamily: fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: navy,
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: surface,
          modalBackgroundColor: surface,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(radiusXl)),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: navy,
          contentTextStyle: const TextStyle(
            fontFamily: fontFamily,
            color: white,
            fontSize: 13,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: primary,
          linearTrackColor: mist,
        ),
        dividerTheme:
            const DividerThemeData(color: mist, thickness: 1, space: 1),
      );
}

// ═════════════════════════════════════════════════════════════════════════
//  DÉCOR : halos lumineux doux
// ═════════════════════════════════════════════════════════════════════════

/// Fond décoratif des en-têtes. Nom conservé pour compatibilité.
class SenegalPatternBackground extends StatelessWidget {
  const SenegalPatternBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StudsPainter(),
      child: const SizedBox.expand(),
    );
  }
}

/// Alias au nom neutre.
typedef StudsBackground = SenegalPatternBackground;

class _StudsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    // Grands halos lumineux (comme les cercles doux de la maquette)
    canvas.drawCircle(
      Offset(w * 0.95, h * 0.0),
      w * 0.38,
      Paint()..color = Colors.white.withOpacity(0.14),
    );
    canvas.drawCircle(
      Offset(w * 0.0, h * 1.05),
      w * 0.30,
      Paint()..color = Colors.white.withOpacity(0.10),
    );
    canvas.drawCircle(
      Offset(w * 0.78, h * 0.95),
      w * 0.16,
      Paint()..color = Colors.white.withOpacity(0.08),
    );
  }

  @override
  bool shouldRepaint(_StudsPainter old) => false;
}

/// Ancien bandeau drapeau : supprimé visuellement (nom conservé pour compat).
class FlagStripe extends StatelessWidget {
  final double height;
  const FlagStripe({super.key, this.height = 4});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

// ═════════════════════════════════════════════════════════════════════════
//  COMPOSANTS RÉUTILISABLES
// ═════════════════════════════════════════════════════════════════════════

/// En-tête d'écran : bloc bleu dégradé arrondi, halos doux, titre blanc.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final double height;
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

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusXl),
          bottomRight: Radius.circular(AppTheme.radiusXl),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.30),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusXl),
          bottomRight: Radius.circular(AppTheme.radiusXl),
        ),
        child: Container(
          constraints: BoxConstraints(minHeight: clampedHeight + topInset),
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: AppTheme.heroGradient),
                  child: SenegalPatternBackground(),
                ),
              ),
              const Positioned(
                  bottom: 0, left: 0, right: 0, child: FlagStripe(height: 3)),
              Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: topInset + 14,
                  bottom: 18,
                ),
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
                              fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

/// Carte néomorphique universelle (relief doux, coins généreux, tap animé).
class NeuCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;
  final double depth;
  final Gradient? gradient;

  const NeuCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = AppTheme.radiusLg,
    this.onTap,
    this.color,
    this.depth = 1,
    this.gradient,
  });

  @override
  State<NeuCard> createState() => _NeuCardState();
}

class _NeuCardState extends State<NeuCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      padding: widget.padding,
      decoration: BoxDecoration(
        color:
            widget.gradient == null ? (widget.color ?? AppTheme.surface) : null,
        gradient: widget.gradient,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: Colors.white.withOpacity(0.9), width: 1),
        boxShadow: AppTheme.neuShadow(
            depth: _pressed ? widget.depth * 0.4 : widget.depth),
      ),
      child: widget.child,
    );

    if (widget.onTap == null) return box;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 140),
        child: box,
      ),
    );
  }
}

/// Tuile d'icône : carré arrondi blanc en relief, icône colorée.
class BrickIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const BrickIcon({
    super.key,
    required this.icon,
    this.color = AppTheme.primary,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.32),
        gradient: LinearGradient(
          colors: [Colors.white, color.withOpacity(0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white, width: 1.2),
        boxShadow: AppTheme.neuShadow(depth: 0.45, tint: color),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(icon, color: color, size: size * 0.46),
        ],
      ),
    );
  }
}

/// Badge pastille de statut.
class StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const StatusPill({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte statistique (icône en brique + valeur + libellé).
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
    return NeuCard(
      padding: const EdgeInsets.all(14),
      radius: AppTheme.radiusMd + 2,
      depth: 0.8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BrickIcon(icon: icon, color: color, size: 38),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTheme.caption),
        ],
      ),
    );
  }
}

/// Bouton principal : dégradé bleu, reflet, enfoncement animé au toucher.
class PrimaryActionButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  const PrimaryActionButton({
    super.key,
    required this.label,
    this.icon,
    required this.onTap,
  });

  @override
  State<PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<PrimaryActionButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: AppTheme.ctaGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: Colors.white.withOpacity(0.25), width: 1),
            boxShadow: _down
                ? [
                    BoxShadow(
                      color: AppTheme.primary.withOpacity(0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : AppTheme.elevatedShadow(AppTheme.primary),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                widget.label,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Titre de section (« Catégories ………… Tout voir »).
class SectionTitle extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  const SectionTitle({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: AppTheme.h3)),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionLabel!,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

/// État vide harmonisé (liste sans résultat, aucune notification…).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrickIcon(icon: icon, size: 76),
            const SizedBox(height: 22),
            Text(title, style: AppTheme.h2, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: AppTheme.body.copyWith(color: AppTheme.slate),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 22), action!],
          ],
        ),
      ),
    );
  }
}

/// Logo de l'app : bouclier bleu dégradé (remplace l'ancien logo image).
class ShieldLogo extends StatelessWidget {
  final double? size;
  const ShieldLogo({super.key, this.size});

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(painter: _ShieldLogoPainter());
    if (size == null) return paint;
    return SizedBox(width: size, height: size, child: paint);
  }
}

class _ShieldLogoPainter extends CustomPainter {
  Path _shield(double w, double h, double inset) {
    final l = inset, r = w - inset, t = inset, b = h - inset;
    final ww = r - l, hh = b - t;
    return Path()
      ..moveTo(l + ww * 0.5, t)
      ..lineTo(r, t + hh * 0.12)
      ..lineTo(r, t + hh * 0.58)
      ..quadraticBezierTo(r, t + hh * 0.86, l + ww * 0.5, b)
      ..quadraticBezierTo(l, t + hh * 0.86, l, t + hh * 0.58)
      ..lineTo(l, t + hh * 0.12)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final outer = _shield(w, h, 0);
    final rect = Rect.fromLTWH(0, 0, w, h);

    canvas.drawPath(
      outer.shift(const Offset(0, 3)),
      Paint()
        ..color = AppTheme.primaryDark.withOpacity(0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      outer,
      Paint()
        ..shader = const LinearGradient(
          colors: [AppTheme.primaryLight, AppTheme.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(rect),
    );
    canvas.drawPath(
      _shield(w, h, w * 0.20),
      Paint()..color = Colors.white.withOpacity(0.92),
    );
    canvas.drawPath(
      _shield(w, h, w * 0.31),
      Paint()
        ..shader = const LinearGradient(
          colors: [AppTheme.primaryLight, AppTheme.primary],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ShieldLogoPainter old) => false;
}


// ═════════════════════════════════════════════════════════════════════════
//  COMPOSANTS « MAQUETTE » (fond doux, en-tête clair, bannière, nav, cartes)
// ═════════════════════════════════════════════════════════════════════════

/// Fond bleu glacier avec grands cercles doux (identique au splash).
class SoftBackground extends StatelessWidget {
  final Widget child;
  const SoftBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.canvasGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _SoftBgPainter()),
          ),
          child,
        ],
      ),
    );
  }
}

class _SoftBgPainter extends CustomPainter {
  const _SoftBgPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawCircle(Offset(w * 0.02, h * 0.22), w * 0.36,
        Paint()..color = AppTheme.primaryLight.withOpacity(0.10));
    canvas.drawCircle(Offset(w * 1.0, h * 0.88), w * 0.42,
        Paint()..color = AppTheme.primaryLight.withOpacity(0.12));
    canvas.drawCircle(Offset(w * 0.95, h * 0.04), w * 0.22,
        Paint()..color = Colors.white.withOpacity(0.55));
  }

  @override
  bool shouldRepaint(_SoftBgPainter old) => false;
}

/// Bouton rond blanc en relief (cloche, retour, actualiser, ajouter…).
class NeuIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final int badge;
  final double size;
  const NeuIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.badge = 0,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        NeuCard(
          padding: EdgeInsets.zero,
          radius: 15,
          depth: 0.55,
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: AppTheme.primary, size: 21),
          ),
        ),
        if (badge > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentRose,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                child: Text(
                  badge > 99 ? '99+' : '$badge',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// En-tête d'écran clair, sans bloc coloré : « Bonjour, / Fatime » + actions.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool subtitleAbove;
  final Widget? leading;
  final Widget? trailing;
  const ScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleAbove = false,
    this.leading,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    const sub = TextStyle(
      fontFamily: AppTheme.fontFamily,
      fontSize: 12,
      color: AppTheme.slate,
    );
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (subtitle != null && subtitleAbove)
                    Text(subtitle!, style: sub),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                      height: 1.15,
                      letterSpacing: -0.3,
                    ),
                  ),
                  if (subtitle != null && !subtitleAbove) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: sub),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

/// Bannière bleue dégradée (« Un problème à signaler ? ») avec bouton blanc.
class HeroBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onTap;
  const HeroBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.elevatedShadow(AppTheme.primary),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A9AEE), Color(0xFF1B6BCB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -34,
                top: -46,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.10),
                  ),
                ),
              ),
              Positioned(
                left: -26,
                bottom: -56,
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.07),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.35)),
                          ),
                          child: Icon(icon, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  color: Colors.white,
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  color: Colors.white.withOpacity(0.88),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: onTap,
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        height: 46,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryDark.withOpacity(0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              buttonLabel,
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: AppTheme.primary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_ios_rounded,
                                size: 13, color: AppTheme.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Entrée de la barre de navigation.
class NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
  const NavItem(this.icon, this.activeIcon, this.label, {this.badge = 0});
}

/// Barre de navigation blanche, coins hauts arrondis, ombre bleutée.
class NeuBottomNav extends StatelessWidget {
  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  const NeuBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withOpacity(0.14),
            blurRadius: 26,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final active = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 48,
                            height: 32,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: active
                                  ? LinearGradient(
                                      colors: [
                                        AppTheme.primaryLight.withOpacity(0.22),
                                        AppTheme.primary.withOpacity(0.10),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    )
                                  : null,
                            ),
                            child: Icon(
                              active ? item.activeIcon : item.icon,
                              size: 22,
                              color: active
                                  ? AppTheme.primaryDark
                                  : AppTheme.slate.withOpacity(0.75),
                            ),
                          ),
                          if (item.badge > 0)
                            Positioned(
                              top: -3,
                              right: 0,
                              child: Container(
                                constraints:
                                    const BoxConstraints(minWidth: 16),
                                height: 16,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentRose,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Colors.white, width: 1.5),
                                ),
                                child: Center(
                                  child: Text(
                                    item.badge > 99 ? '99+' : '${item.badge}',
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10.5,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          color: active
                              ? AppTheme.primaryDark
                              : AppTheme.slate.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// Pastille de filtre / onglet (actif : dégradé bleu ; inactif : blanc en relief).
class PillChip extends StatelessWidget {
  final String label;
  final int? count;
  final bool active;
  final Color? color;
  final VoidCallback onTap;
  const PillChip({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.count,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(
          gradient: active ? AppTheme.ctaGradient : null,
          color: active ? null : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: active ? Colors.white.withOpacity(0.3) : Colors.white),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ]
              : AppTheme.neuShadow(depth: 0.45),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppTheme.slate,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 7),
              Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white.withOpacity(0.25)
                      : c.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: active ? Colors.white : c,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Carte de liste (« Mes signalements », notifications) : tuile d'icône,
/// titre, lignes de détail, pastille à droite.
class NeuListCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> lines;
  final Widget? trailing;
  final VoidCallback? onTap;
  const NeuListCard({
    super.key,
    required this.icon,
    required this.title,
    this.color = AppTheme.primary,
    this.lines = const [],
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.all(14),
      radius: 20,
      depth: 0.7,
      onTap: onTap,
      child: Row(
        children: [
          BrickIcon(icon: icon, color: color, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navy,
                  ),
                ),
                for (final l in lines) ...[
                  const SizedBox(height: 3),
                  Text(
                    l,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: AppTheme.slate,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
        ],
      ),
    );
  }
}

/// Une statistique de la bande « 5 Signalements | 3 En cours | 2 Clôturés ».
class StripStat {
  final String value;
  final String label;
  final Color? color;
  const StripStat(this.value, this.label, {this.color});
}

/// Bande de statistiques dans une carte blanche en relief (comme le profil).
class StatsStrip extends StatelessWidget {
  final List<StripStat> stats;
  const StatsStrip({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
      radius: 22,
      depth: 0.8,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < stats.length; i++) ...[
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      stats[i].value,
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: stats[i].color ?? AppTheme.navy,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      stats[i].label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: AppTheme.slate,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < stats.length - 1)
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: AppTheme.mist,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Groupe de lignes dans une carte (« Mes informations, Mes favoris… »).
class NeuGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  const NeuGroup({super.key, this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 8),
            child: Text(
              title!,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.slate,
                letterSpacing: 0.4,
              ),
            ),
          ),
        NeuCard(
          padding: EdgeInsets.zero,
          radius: 22,
          depth: 0.8,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  const Divider(height: 1, indent: 62, endIndent: 14),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Ligne d'un [NeuGroup] : tuile d'icône, libellé, valeur ou chevron.
class NeuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final bool isAction;
  final VoidCallback? onTap;
  final Color color;
  const NeuRow({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
    this.isAction = false,
    this.onTap,
    this.color = AppTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            BrickIcon(icon: icon, color: color, size: 36),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.navy,
                ),
              ),
            ),
            if (trailing != null)
              Flexible(child: trailing!)
            else if (isAction)
              const Icon(Icons.chevron_right_rounded,
                  color: AppTheme.slate, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Tuile de catégorie (Sécurité, Nuisances, Voirie…) : icône + libellé.
class CategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const CategoryTile({
    super.key,
    required this.icon,
    required this.label,
    this.color = AppTheme.primary,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NeuCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      radius: 20,
      depth: 0.7,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          BrickIcon(icon: icon, color: color, size: 46),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.navy,
            ),
          ),
        ],
      ),
    );
  }
}
