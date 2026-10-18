// lib/presentation/screens/reports/report_neo_widgets.dart
//
// Widgets et helpers partagés par les écrans de signalements (design Neo).
// Remplace les _Chip / _FilterChip / _SevChip / _StatusPill / _SearchBar
// qui étaient dupliqués dans chaque écran.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/theme/neo_kit.dart';
import 'package:citoyen_alerte_app_backup/data/models/report_model.dart';

// ════════════════════════════════════════════════════════════════════════════
//  HELPERS (couleurs / libellés / dates)
// ════════════════════════════════════════════════════════════════════════════

class ReportUi {
  ReportUi._();

  static Color statusColor(String s) => switch (s) {
    'pending' || 'acknowledged' => Neo.warning,
    'routed' => Neo.info,
    'in_progress' => Neo.purple,
    'resolved' => Neo.success,
    _ => Neo.muted,
  };

  static String statusLabel(String s) => switch (s) {
    'pending' || 'acknowledged' => 'En attente',
    'routed' => 'Routé',
    'in_progress' => 'En cours',
    'resolved' => 'Résolu',
    _ => s,
  };

  static Color severityColor(String s) => switch (s) {
    'high' => Neo.danger,
    'medium' => Neo.warning,
    'low' => Neo.success,
    _ => Neo.muted,
  };

  static String severityLabel(String s) => switch (s) {
    'low' => 'Faible',
    'medium' => 'Moyen',
    'high' => 'Élevé',
    _ => s,
  };

  static String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return 'Il y a ${(diff.inDays / 30).floor()} mois';
    if (diff.inDays > 0) return 'Il y a ${diff.inDays}j';
    if (diff.inHours > 0) return 'Il y a ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'Il y a ${diff.inMinutes}min';
    return "À l'instant";
  }

  /// (clé, libellé, couleur)
  static const List<(String, String, Color)> statusFilters = [
    ('all', 'Tous', Neo.blue),
    ('pending', 'En attente', Neo.warning),
    ('routed', 'Routés', Neo.info),
    ('in_progress', 'En cours', Neo.purple),
    ('resolved', 'Résolus', Neo.success),
  ];

  static const List<(String, String, Color)> severityFilters = [
    ('all', 'Toutes', Neo.blue),
    ('low', 'Faible', Neo.success),
    ('medium', 'Moyen', Neo.warning),
    ('high', 'Élevé', Neo.danger),
  ];
}

// ════════════════════════════════════════════════════════════════════════════
//  FILTRES
// ════════════════════════════════════════════════════════════════════════════

/// Rangée de chips (statut ou sévérité). `counts` est évalué dans un Obx :
/// il peut donc lire des observables.
class ReportFilterChips extends StatelessWidget {
  final List<(String, String, Color)> filters;
  final RxString selected;
  final ValueChanged<String> onSelect;
  final Map<String, int> Function()? counts;

  const ReportFilterChips({
    super.key,
    required this.filters,
    required this.selected,
    required this.onSelect,
    this.counts,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final active = selected.value;
      final c = counts?.call();
      return NeoChipRow(
        chips: filters
            .map((f) => NeoChip(
          label: f.$2,
          color: f.$3,
          count: c?[f.$1],
          selected: active == f.$1,
          onTap: () => onSelect(f.$1),
        ))
            .toList(),
      );
    });
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CHAMPS
// ════════════════════════════════════════════════════════════════════════════

class ReportSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final RxString queryObs;
  final String hint;

  const ReportSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.queryObs,
    this.hint = 'Rechercher un signalement...',
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Neo.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white),
          boxShadow: Neo.softRelief(),
        ),
        child: Row(children: [
          const Icon(Icons.search_rounded, size: 20, color: Neo.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              cursorColor: Neo.blue,
              style: Neo.t(14),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
                hintStyle: Neo.t(13, c: Neo.muted),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          Obx(() => queryObs.value.isEmpty
              ? const SizedBox.shrink()
              : GestureDetector(
            onTap: onClear,
            child: const Padding(
              padding: EdgeInsets.only(left: 6),
              child: Icon(Icons.close_rounded, size: 18, color: Neo.muted),
            ),
          )),
        ]),
      ),
    );
  }
}

/// Champ de saisie Neo (formulaire de signalement).
class ReportNeoField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;

  const ReportNeoField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final multi = maxLines > 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Neo.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white),
        boxShadow: Neo.softRelief(),
      ),
      child: Row(
        crossAxisAlignment: multi ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: multi ? 14 : 0),
            child: Icon(icon, size: 20, color: Neo.blue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              maxLines: maxLines,
              cursorColor: Neo.blue,
              style: Neo.t(14),
              decoration: InputDecoration(
                border: InputBorder.none,
                isDense: true,
                hintText: hint,
                hintStyle: Neo.t(13, c: Neo.muted),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CARTE SIGNALEMENT (liste complète + mes signalements)
// ════════════════════════════════════════════════════════════════════════════

class ReportNeoCard extends StatelessWidget {
  final ReportModel report;
  final VoidCallback? onTap;
  final Widget? footer;

  const ReportNeoCard({super.key, required this.report, this.onTap, this.footer});

  @override
  Widget build(BuildContext context) {
    final sev = ReportUi.severityColor(report.severity);
    final st = ReportUi.statusColor(report.status);
    final imgs = report.images;
    final String? photo = (imgs != null && imgs.isNotEmpty) ? imgs.first.url : null;

    final catName = report.category?.name;
    final subtitle = (catName != null && catName.isNotEmpty)
        ? '${report.reference} · $catName'
        : report.reference;

    final Widget lead = photo != null
        ? ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        photo,
        width: 54,
        height: 54,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: 54,
          height: 54,
          color: Neo.inset,
          child: const Icon(Icons.broken_image_outlined, size: 20, color: Neo.muted),
        ),
      ),
    )
        : NeoIconBadge(icon: Icons.report_gmailerrorred_rounded, color: sev, size: 46);

    return NeoCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          lead,
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(report.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Neo.t(14, w: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Neo.t(11, c: Neo.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          NeoPill(label: ReportUi.statusLabel(report.status), color: st),
        ]),
        if (report.description.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(report.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Neo.t(12, c: Neo.muted)),
        ],
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.location_on_outlined, size: 13, color: Neo.muted),
          const SizedBox(width: 4),
          Expanded(
            child: Text('${report.communeName}, ${report.regionName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Neo.t(11, c: Neo.muted)),
          ),
          const SizedBox(width: 8),
          Icon(Icons.warning_amber_rounded, size: 13, color: sev),
          const SizedBox(width: 3),
          Text(ReportUi.severityLabel(report.severity),
              style: Neo.t(11, w: FontWeight.w600, c: sev)),
          const SizedBox(width: 10),
          Text(ReportUi.timeAgo(report.createdAt), style: Neo.t(10.5, c: Neo.muted)),
        ]),
        if (footer != null) ...[
          const SizedBox(height: 10),
          Divider(height: 1, color: Neo.line),
          const SizedBox(height: 8),
          footer!,
        ],
      ]),
    );
  }
}