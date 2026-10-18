// lib/core/theme/neo_kit.dart
//
// Kit de composants « maquette Alerte Citoyen » : fond bleu glacier,
// cartes néomorphiques, bannière bleue, barre de navigation arrondie.
// Indépendant d'app_theme.dart (couleurs codées ici) pour éviter tout conflit.

import 'package:flutter/material.dart';

class Neo {
  Neo._();
  static const Color blue = Color(0xFF1F5FD6);
  static const Color blueDark = Color(0xFF0F3A9E);
  static const Color blueLight = Color(0xFF4F8EF7);
  static const Color ink = Color(0xFF12294F);
  static const Color muted = Color(0xFF6B7C99);
  static const Color line = Color(0xFFDCE6F5);
  static const Color bg = Color(0xFFEAF1FC);
  static const Color surface = Color(0xFFF7FAFF);
  static const Color inset = Color(0xFFE3ECF9);
  static const Color shadow = Color(0xFFB4C6E6);
  static const Color success = Color(0xFF1FA86B);
  static const Color warning = Color(0xFFF5A524);
  static const Color danger = Color(0xFFE5604F);
  static const Color info = Color(0xFF3B82F6);
  static const Color purple = Color(0xFF7A5AF8);
  static const String font = 'Poppins';

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF1F5FD6), Color(0xFF3F86F2)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> relief() => [
        BoxShadow(
            color: shadow.withOpacity(0.55),
            blurRadius: 18,
            offset: const Offset(6, 8)),
        const BoxShadow(
            color: Colors.white, blurRadius: 16, offset: Offset(-6, -6)),
      ];

  static List<BoxShadow> softRelief() => [
        BoxShadow(
            color: shadow.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(3, 4)),
        const BoxShadow(
            color: Colors.white, blurRadius: 10, offset: Offset(-3, -3)),
      ];

  static TextStyle t(double size,
          {FontWeight w = FontWeight.w400, Color c = ink, double? h}) =>
      TextStyle(
          fontFamily: font, fontSize: size, fontWeight: w, color: c, height: h);

  static String ago(DateTime date) {
    final d = DateTime.now().difference(date);
    if (d.inDays > 30) return 'Il y a ${(d.inDays / 30).floor()} mois';
    if (d.inDays > 0) return 'Il y a ${d.inDays}j';
    if (d.inHours > 0) return 'Il y a ${d.inHours}h';
    if (d.inMinutes > 0) return 'Il y a ${d.inMinutes}min';
    return "À l'instant";
  }
}

// ── Fond ────────────────────────────────────────────────────────────────────
class NeoBackdrop extends StatelessWidget {
  final Widget child;
  const NeoBackdrop({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF3F8FF), Color(0xFFE6EFFB)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Stack(children: [
        Positioned(left: -90, top: -60, child: _halo(260, Neo.blueLight.withOpacity(0.16))),
        Positioned(right: -110, bottom: -80, child: _halo(320, Neo.blue.withOpacity(0.09))),
        child,
      ]),
    );
  }

  static Widget _halo(double s, Color c) => IgnorePointer(
        child: Container(
            width: s, height: s, decoration: BoxDecoration(shape: BoxShape.circle, color: c)),
      );
}

// ── Appui animé ─────────────────────────────────────────────────────────────
class NeoPressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  const NeoPressable({super.key, required this.child, this.onTap, this.scale = 0.97});
  @override
  State<NeoPressable> createState() => _NeoPressableState();
}

class _NeoPressableState extends State<NeoPressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

// ── Apparition ──────────────────────────────────────────────────────────────
class NeoReveal extends StatelessWidget {
  final Widget child;
  final int delayMs;
  const NeoReveal({super.key, required this.child, this.delayMs = 0});
  @override
  Widget build(BuildContext context) {
    final total = 520 + delayMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delayMs / total, 1, curve: Curves.easeOutCubic),
      builder: (_, v, c) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: c),
      ),
      child: child,
    );
  }
}

// ── Carte en relief ─────────────────────────────────────────────────────────
class NeoCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final VoidCallback? onTap;
  final Color? borderColor;
  const NeoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.radius = 20,
    this.onTap,
    this.borderColor,
  });
  @override
  Widget build(BuildContext context) {
    final box = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Neo.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? Colors.white.withOpacity(0.9)),
        boxShadow: Neo.relief(),
      ),
      child: child,
    );
    return onTap == null ? box : NeoPressable(onTap: onTap, child: box);
  }
}

// ── Pastille d'icône ────────────────────────────────────────────────────────
class NeoIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const NeoIconBadge({super.key, required this.icon, this.color = Neo.blue, this.size = 44});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withOpacity(0.10), Neo.surface),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: Colors.white.withOpacity(0.95)),
        boxShadow: Neo.softRelief(),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

// ── Pastille de statut ──────────────────────────────────────────────────────
class NeoPill extends StatelessWidget {
  final String label;
  final Color color;
  const NeoPill({super.key, required this.label, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(color.withOpacity(0.12), Neo.surface),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label, style: Neo.t(10.5, w: FontWeight.w600, c: color)),
      ]),
    );
  }
}

// ── Titre de section ────────────────────────────────────────────────────────
class NeoSectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final IconData? icon;
  const NeoSectionTitle(this.title, {super.key, this.action, this.onAction, this.icon});
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      if (icon != null) ...[Icon(icon, size: 17, color: Neo.blue), const SizedBox(width: 7)],
      Expanded(child: Text(title, style: Neo.t(16, w: FontWeight.w700))),
      if (action != null)
        GestureDetector(
          onTap: onAction,
          child: Text(action!, style: Neo.t(12.5, w: FontWeight.w600, c: Neo.blue)),
        ),
    ]);
  }
}

// ── En-tête « Bonjour, Fatime » ─────────────────────────────────────────────
class NeoGreetingHeader extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final int notifications;
  final VoidCallback? onBell;
  final String greeting;
  const NeoGreetingHeader({
    super.key,
    required this.name,
    this.avatarUrl,
    this.notifications = 0,
    this.onBell,
    this.greeting = 'Bonjour,',
  });
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 6),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Neo.surface,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: Neo.softRelief(),
          ),
          clipBehavior: Clip.antiAlias,
          child: (avatarUrl != null && avatarUrl!.isNotEmpty)
              ? Image.network(avatarUrl!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, color: Neo.blue))
              : const Icon(Icons.person_rounded, color: Neo.blue, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(greeting, style: Neo.t(12, c: Neo.muted)),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Neo.t(20, w: FontWeight.w700, h: 1.15)),
          ]),
        ),
        NeoIconButton(icon: Icons.notifications_none_rounded, badge: notifications, onTap: onBell),
      ]),
    );
  }
}

// ── Titre de page simple (sans bloc coloré) ─────────────────────────────────
class NeoTitleBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  const NeoTitleBar({super.key, required this.title, this.subtitle, this.leading, this.actions = const []});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 14, 20, 6),
      child: Row(children: [
        if (leading != null) ...[leading!, const SizedBox(width: 12)],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: Neo.t(22, w: FontWeight.w700, h: 1.15)),
            if (subtitle != null) Text(subtitle!, style: Neo.t(12, c: Neo.muted)),
          ]),
        ),
        for (final a in actions) ...[const SizedBox(width: 8), a],
      ]),
    );
  }
}

// ── Bouton rond (cloche, retour, rafraîchir) ────────────────────────────────
class NeoIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final int badge;
  final double size;
  const NeoIconButton({super.key, required this.icon, this.onTap, this.badge = 0, this.size = 44});
  @override
  Widget build(BuildContext context) {
    return NeoPressable(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Neo.surface,
            borderRadius: BorderRadius.circular(size * 0.34),
            border: Border.all(color: Colors.white),
            boxShadow: Neo.softRelief(),
          ),
          child: Icon(icon, color: Neo.ink, size: size * 0.48),
        ),
        if (badge > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Neo.danger,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Center(
                child: Text(badge > 9 ? '9+' : '$badge',
                    style: Neo.t(9, w: FontWeight.w700, c: Colors.white)),
              ),
            ),
          ),
      ]),
    );
  }
}

// ── Bannière bleue ──────────────────────────────────────────────────────────
class NeoHero extends StatelessWidget {
  final String title;
  final String subtitle;
  final String buttonLabel;
  final IconData icon;
  final VoidCallback onTap;
  const NeoHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onTap,
    this.icon = Icons.shield_outlined,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: Neo.heroGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Neo.blue.withOpacity(0.35), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(children: [
        Positioned(
          right: -20,
          top: -30,
          child: IgnorePointer(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)),
            ),
          ),
        ),
        Column(children: [
          Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: Neo.t(15.5, w: FontWeight.w700, c: Colors.white)),
                const SizedBox(height: 2),
                Text(subtitle, style: Neo.t(11.5, c: Colors.white.withOpacity(0.85))),
              ]),
            ),
          ]),
          const SizedBox(height: 14),
          NeoPressable(
            onTap: onTap,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(children: [
                Expanded(
                  child: Text(buttonLabel,
                      textAlign: TextAlign.center, style: Neo.t(13.5, w: FontWeight.w600, c: Neo.blue)),
                ),
                const Icon(Icons.chevron_right_rounded, color: Neo.blue, size: 22),
              ]),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Boutons ─────────────────────────────────────────────────────────────────
class NeoButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool outlined;
  final Color color;
  final bool loading;
  const NeoButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.outlined = false,
    this.color = Neo.blue,
    this.loading = false,
  });
  @override
  State<NeoButton> createState() => _NeoButtonState();
}

class _NeoButtonState extends State<NeoButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null && !widget.loading;
    final fg = widget.outlined ? widget.color : Colors.white;
    final dark = Color.lerp(widget.color, Colors.black, 0.28)!;
    final lift = _down ? 1.0 : 4.0;
    return Opacity(
      opacity: enabled || widget.loading ? 1 : 0.5,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: enabled ? widget.onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: widget.outlined ? Neo.shadow : dark,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            margin: EdgeInsets.only(bottom: lift),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: widget.outlined
                  ? const LinearGradient(colors: [Colors.white, Color(0xFFEFF5FF)], begin: Alignment.topCenter, end: Alignment.bottomCenter)
                  : LinearGradient(colors: [Color.lerp(widget.color, Colors.white, 0.18)!, widget.color], begin: Alignment.topCenter, end: Alignment.bottomCenter),
            ),
            child: widget.loading
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: fg))
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    if (widget.icon != null) ...[Icon(widget.icon, color: fg, size: 18), const SizedBox(width: 8)],
                    Flexible(child: Text(widget.label, overflow: TextOverflow.ellipsis, style: Neo.t(14.5, w: FontWeight.w600, c: fg))),
                  ]),
          ),
        ),
      ),
    );
  }
}

// ── Onglets segmentés (Toutes / Mes signalements) ───────────────────────────
class NeoTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const NeoTabs({super.key, required this.labels, required this.index, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Neo.inset.withOpacity(0.8), borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: List.generate(labels.length, (i) {
          final sel = i == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: sel ? const LinearGradient(colors: [Color(0xFF3A7BF0), Neo.blue], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
                  boxShadow: sel ? [BoxShadow(color: Neo.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : null,
                ),
                child: Text(labels[i], style: Neo.t(12.5, w: FontWeight.w600, c: sel ? Colors.white : Neo.muted)),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Puces de filtre défilantes ──────────────────────────────────────────────
class NeoChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final int? count;
  const NeoChip({super.key, required this.label, required this.selected, required this.onTap, this.color = Neo.blue, this.count});
  @override
  Widget build(BuildContext context) {
    return NeoPressable(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? null : Neo.surface,
          gradient: selected ? LinearGradient(colors: [Color.lerp(color, Colors.white, 0.18)!, color], begin: Alignment.topCenter, end: Alignment.bottomCenter) : null,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.white.withOpacity(0.9)),
          boxShadow: selected ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : Neo.softRelief(),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: Neo.t(12, w: FontWeight.w600, c: selected ? Colors.white : Neo.muted)),
          if (count != null) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withOpacity(0.25) : color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('$count', style: Neo.t(10, w: FontWeight.w700, c: selected ? Colors.white : color)),
            ),
          ],
        ]),
      ),
    );
  }
}

class NeoChipRow extends StatelessWidget {
  final List<Widget> chips;
  const NeoChipRow({super.key, required this.chips});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

// ── Bande de chiffres 5 | 3 | 2 ─────────────────────────────────────────────
class NeoStat {
  final String value;
  final String label;
  final Color color;
  const NeoStat(this.value, this.label, [this.color = Neo.ink]);
}

class NeoStatsStrip extends StatelessWidget {
  final List<NeoStat> items;
  const NeoStatsStrip({super.key, required this.items});
  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[];
    for (int i = 0; i < items.length; i++) {
      cells.add(Expanded(
        child: Column(children: [
          Text(items[i].value, style: Neo.t(22, w: FontWeight.w700, c: items[i].color, h: 1.1)),
          const SizedBox(height: 2),
          Text(items[i].label, textAlign: TextAlign.center, style: Neo.t(11, c: Neo.muted)),
        ]),
      ));
      if (i < items.length - 1) cells.add(Container(width: 1, height: 34, color: Neo.line));
    }
    return NeoCard(padding: const EdgeInsets.symmetric(vertical: 14), child: Row(children: cells));
  }
}

// ── Carte statistique (icône + valeur) ──────────────────────────────────────
class NeoStatTile extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  const NeoStatTile({super.key, required this.value, required this.label, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return NeoCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        NeoIconBadge(icon: icon, color: color, size: 38),
        const SizedBox(height: 12),
        Text(value, style: Neo.t(22, w: FontWeight.w700, c: color, h: 1.1)),
        const SizedBox(height: 2),
        Text(label, style: Neo.t(11, c: Neo.muted)),
      ]),
    );
  }
}

// ── Carte de liste (signalement, notification, intervention…) ───────────────
class NeoListCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final String? meta;
  final Widget? pill;
  final VoidCallback? onTap;
  final Widget? bottom;
  final Widget? leading;
  const NeoListCard({
    super.key,
    required this.icon,
    required this.title,
    this.color = Neo.blue,
    this.subtitle,
    this.meta,
    this.pill,
    this.onTap,
    this.bottom,
    this.leading,
  });
  @override
  Widget build(BuildContext context) {
    return NeoCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          leading ?? NeoIconBadge(icon: icon, color: color, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Neo.t(14, w: FontWeight.w600)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Neo.t(11, c: Neo.muted)),
              ],
              if (meta != null) ...[
                const SizedBox(height: 2),
                Text(meta!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Neo.t(10.5, c: Neo.muted)),
              ],
            ]),
          ),
          if (pill != null) ...[const SizedBox(width: 8), pill!],
        ]),
        if (bottom != null) ...[const SizedBox(height: 12), bottom!],
      ]),
    );
  }
}

// ── Tuile de catégorie ──────────────────────────────────────────────────────
class NeoCategoryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const NeoCategoryTile({super.key, required this.icon, required this.label, required this.color, this.onTap});
  @override
  Widget build(BuildContext context) {
    return NeoPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Neo.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.9)),
          boxShadow: Neo.softRelief(),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 7),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Neo.t(10.5, w: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ── Groupe de lignes (profil / paramètres) ──────────────────────────────────
class NeoGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  const NeoGroup({super.key, this.title, required this.children});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (title != null)
        Padding(
          padding: const EdgeInsets.only(left: 6, bottom: 8),
          child: Text(title!, style: Neo.t(11, w: FontWeight.w600, c: Neo.muted).copyWith(letterSpacing: 0.8)),
        ),
      NeoCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) Divider(height: 1, indent: 60, color: Neo.line.withOpacity(0.8)),
          ],
        ]),
      ),
    ]);
  }
}

class NeoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color color;
  const NeoRow({super.key, required this.icon, required this.label, this.value, this.trailing, this.onTap, this.color = Neo.blue});
  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        NeoIconBadge(icon: icon, color: color, size: 36),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: Neo.t(13.5, w: FontWeight.w600)),
            if (value != null && value!.isNotEmpty) Text(value!, style: Neo.t(11, c: Neo.muted)),
          ]),
        ),
        trailing ?? (onTap != null ? const Icon(Icons.chevron_right_rounded, color: Neo.muted) : const SizedBox.shrink()),
      ]),
    );
    return onTap == null ? row : InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: row);
  }
}

// ── Navigation basse ────────────────────────────────────────────────────────
class NeoNavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int badge;
  const NeoNavItem(this.icon, this.activeIcon, this.label, {this.badge = 0});
}

class NeoBottomNav extends StatelessWidget {
  final List<NeoNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  const NeoBottomNav({super.key, required this.items, required this.index, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Neo.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(color: Neo.shadow.withOpacity(0.55), blurRadius: 24, offset: const Offset(0, -6)),
          const BoxShadow(color: Colors.white, blurRadius: 12, offset: Offset(0, -3)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          child: Row(
            children: List.generate(items.length, (i) {
              final it = items[i];
              final sel = i == index;
              return Expanded(
                child: NeoPressable(
                  onTap: () => onChanged(i),
                  scale: 0.92,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Stack(clipBehavior: Clip.none, children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOutCubic,
                        width: 44,
                        height: 30,
                        decoration: BoxDecoration(
                          color: sel ? Neo.blue.withOpacity(0.12) : Colors.transparent,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(sel ? it.activeIcon : it.icon, size: 22, color: sel ? Neo.blue : Neo.muted),
                      ),
                      if (it.badge > 0)
                        Positioned(
                          right: -2,
                          top: -4,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                                color: Neo.warning,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white, width: 1.5)),
                            child: Center(child: Text('${it.badge}', style: Neo.t(9, w: FontWeight.w700))),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 3),
                    Text(it.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Neo.t(10.5, w: sel ? FontWeight.w700 : FontWeight.w500, c: sel ? Neo.blue : Neo.muted)),
                  ]),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ── États ───────────────────────────────────────────────────────────────────
class NeoEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const NeoEmpty({super.key, required this.icon, required this.title, required this.message, this.action});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Neo.surface,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: Neo.relief(),
            ),
            child: Icon(icon, size: 38, color: Neo.blueLight),
          ),
          const SizedBox(height: 20),
          Text(title, textAlign: TextAlign.center, style: Neo.t(16, w: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: Neo.t(12.5, c: Neo.muted, h: 1.5)),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ]),
      ),
    );
  }
}

class NeoLoading extends StatelessWidget {
  const NeoLoading({super.key});
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator(color: Neo.blue, strokeWidth: 2.6));
}

class NeoError extends StatelessWidget {
  final VoidCallback onRetry;
  final String message;
  const NeoError({super.key, required this.onRetry, this.message = 'Erreur de chargement'});
  @override
  Widget build(BuildContext context) => NeoEmpty(
        icon: Icons.cloud_off_rounded,
        title: message,
        message: 'Vérifiez votre connexion et réessayez.',
        action: SizedBox(width: 190, child: NeoButton(label: 'Réessayer', icon: Icons.refresh_rounded, onTap: onRetry)),
      );
}

/// Bouton « Se déconnecter » (corail).
class NeoLogoutButton extends StatelessWidget {
  final VoidCallback onTap;
  const NeoLogoutButton({super.key, required this.onTap});
  @override
  Widget build(BuildContext context) =>
      NeoButton(label: 'Se déconnecter', icon: Icons.logout_rounded, color: Neo.danger, onTap: onTap);
}

/// Dialogue de confirmation stylé.
Future<bool> neoConfirm(BuildContext context,
    {required String title, required String message, String confirm = 'Confirmer', Color color = Neo.danger}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: Neo.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(title, style: Neo.t(17, w: FontWeight.w700)),
      content: Text(message, style: Neo.t(13, c: Neo.muted, h: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white),
          child: Text(confirm),
        ),
      ],
    ),
  );
  return r == true;
}
