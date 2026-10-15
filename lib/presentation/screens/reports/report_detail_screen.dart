// lib/presentation/screens/reports/report_detail_screen.dart
//
// Reprend l'écran existant à l'identique pour la structure générale ;
// seule la section "Photos" change : miniatures plus grandes et un tap
// ouvre une visionneuse plein écran (zoom, swipe entre les photos).
//
// NOTE : cette version affiche toutes les photos du signalement sans les
// distinguer par type (avant/après), car je n'ai pas la définition exacte
// de ton `ReportImageModel` (je ne sais pas s'il expose un champ `type`).
// Si tu veux séparer "Avant" / "Après" avec des étiquettes ici aussi,
// partage-moi `report_model.dart` et j'ajusterai cette section précisément.

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/data/models/report_model.dart';
import 'edit_report_screen.dart';

// ─── CONTROLLER (inchangé) ───────────────────────────────────────────────────

class ReportDetailController extends GetxController {
  final ApiService _api = Get.find<ApiService>();
  final int reportId;
  ReportDetailController({required this.reportId});

  final isLoading  = true.obs;
  final isDeleting = false.obs;
  final report     = Rx<ReportModel?>(null);

  @override
  void onInit() { super.onInit(); loadReport(); }

  Future<void> loadReport() async {
    try {
      isLoading.value = true;
      final response = await _api.getReportById(reportId);
      if (response.data != null) {
        final raw = response.data;
        Map<String, dynamic>? map;
        if (raw is Map<String, dynamic> && raw.containsKey('id')) { map = raw; }
        else if (raw is Map<String, dynamic> && raw['data'] is Map)  { map = raw['data'] as Map<String, dynamic>; }
        if (map != null) report.value = ReportModel.fromJson(map);
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de charger le signalement',
          snackPosition: SnackPosition.BOTTOM, backgroundColor: AppTheme.error,
          colorText: Colors.white, margin: const EdgeInsets.all(16), borderRadius: 12);
    } finally { isLoading.value = false; }
  }

  Future<void> deleteReport() async {
    try {
      isDeleting.value = true;
      final response = await _api.deleteReport(reportId);
      if (response.success) {
        Get.back(result: 'deleted');
        Get.snackbar('Supprimé ✓', 'Signalement supprimé', snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppTheme.success, colorText: Colors.white, margin: const EdgeInsets.all(16), borderRadius: 12);
      }
    } catch (_) {
      Get.snackbar('Erreur', 'Impossible de supprimer', snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.error, colorText: Colors.white, margin: const EdgeInsets.all(16), borderRadius: 12);
    } finally { isDeleting.value = false; }
  }

  Color getSeverityColor(String s) {
    switch (s) { case 'high': return AppTheme.error; case 'medium': return AppTheme.warning; case 'low': return AppTheme.success; default: return AppTheme.greyMedium; }
  }
  Color getStatusColor(String s) {
    switch (s) { case 'pending': return AppTheme.warning; case 'routed': return const Color(0xFF3B82F6); case 'in_progress': return const Color(0xFF8B5CF6); case 'resolved': return AppTheme.success; default: return AppTheme.greyMedium; }
  }
  String getStatusLabel(String s) {
    switch (s) { case 'pending': return 'En attente'; case 'routed': return 'Routé'; case 'in_progress': return 'En cours'; case 'resolved': return 'Résolu'; default: return s; }
  }
  String getSeverityLabel(String s) {
    switch (s) { case 'low': return 'Faible'; case 'medium': return 'Moyen'; case 'high': return 'Élevé'; default: return s; }
  }
  String formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ─── SCREEN ──────────────────────────────────────────────────────────────────

class ReportDetailScreen extends StatelessWidget {
  final int reportId;
  const ReportDetailScreen({super.key, required this.reportId});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(ReportDetailController(reportId: reportId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Obx(() {
        if (ctrl.isLoading.value) {
          return Scaffold(
            appBar: AppBar(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white,
                title: const Text('Détail', style: TextStyle(fontFamily: 'Poppins'))),
            body: const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
          );
        }
        if (ctrl.report.value == null) {
          return Scaffold(
            appBar: AppBar(backgroundColor: AppTheme.primaryGreen, foregroundColor: Colors.white),
            body: const Center(child: Text('Signalement introuvable', style: TextStyle(fontFamily: 'Poppins'))),
          );
        }

        final r = ctrl.report.value!;
        return Scaffold(
          backgroundColor: AppTheme.background,
          body: CustomScrollView(slivers: [
            SliverAppBar(
              expandedHeight: 150,
              pinned: true,
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () => Get.back(),
              ),
              actions: [
                if (r.status == 'pending')
                  IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () async {
                    final result = await Get.to(() => EditReportScreen(report: r));
                    if (result == true) ctrl.loadReport();
                  }),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onSelected: (v) { if (v == 'delete') _confirmDelete(context, ctrl); },
                  itemBuilder: (_) => [
                    if (r.status == 'pending')
                      const PopupMenuItem(value: 'delete',
                          child: Row(children: [
                            Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                            SizedBox(width: 10),
                            Text('Supprimer', style: TextStyle(fontFamily: 'Poppins', color: AppTheme.error)),
                          ])),
                  ],
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryGreen, AppTheme.lightGreen],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.end, children: [
                      Text(r.title, style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(r.reference, style: TextStyle(fontFamily: 'Poppins', color: Colors.white.withOpacity(0.8), fontSize: 12)),
                    ]),
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                  // Photos — EN PREMIER : c'est l'info la plus parlante pour tous
                  if (r.images != null && r.images!.isNotEmpty) ...[
                    _Section(icon: Icons.photo_library_outlined, title: 'Photos (${r.images!.length})',
                        child: SizedBox(
                          height: 130,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: r.images!.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 10),
                            itemBuilder: (_, i) => GestureDetector(
                              onTap: () => _openGallery(context, r.images!.map((img) => img.url).toList(), i),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.network(r.images![i].url, width: 130, height: 130, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Container(width: 130, height: 130, color: AppTheme.greyLight,
                                        child: const Icon(Icons.broken_image_outlined, color: AppTheme.greyMedium))),
                              ),
                            ),
                          ),
                        )),
                    const SizedBox(height: 12),
                  ],

                  // Badges
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    _Badge(label: ctrl.getStatusLabel(r.status),   color: ctrl.getStatusColor(r.status),   icon: _statusIcon(r.status)),
                    _Badge(label: ctrl.getSeverityLabel(r.severity), color: ctrl.getSeverityColor(r.severity), icon: Icons.warning_amber_rounded),
                    if (r.category != null) _Badge(label: r.category!.name, color: const Color(0xFF3B82F6), icon: Icons.category_outlined),
                  ]),

                  const SizedBox(height: 16),

                  // Timeline
                  _ProgressTimeline(status: r.status),

                  const SizedBox(height: 14),

                  // Description
                  _Section(icon: Icons.description_outlined, title: 'Description',
                      child: Text(r.description, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, height: 1.6, color: Colors.black87))),

                  const SizedBox(height: 12),

                  // Localisation
                  _Section(icon: Icons.location_on_outlined, title: 'Localisation',
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _InfoRow(icon: Icons.signpost_outlined,       label: 'Adresse',    value: r.address),
                        const SizedBox(height: 8),
                        _InfoRow(icon: Icons.location_city_outlined,  label: 'Commune',    value: r.communeName),
                        const SizedBox(height: 8),
                        _InfoRow(icon: Icons.map_outlined,             label: 'Région',     value: r.regionName),
                        const SizedBox(height: 8),
                        _InfoRow(icon: Icons.gps_fixed,               label: 'Coordonnées',
                            value: '${r.latitude.toStringAsFixed(5)}, ${r.longitude.toStringAsFixed(5)}'),
                      ])),

                  const SizedBox(height: 12),

                  // Infos
                  _Section(icon: Icons.info_outline, title: 'Informations',
                      child: Column(children: [
                        _InfoRow(icon: Icons.calendar_today_outlined, label: 'Créé le',    value: ctrl.formatDate(r.createdAt)),
                        const SizedBox(height: 8),
                        _InfoRow(icon: Icons.update,                  label: 'Mis à jour', value: ctrl.formatDate(r.updatedAt)),
                        if (r.resolvedAt != null) ...[
                          const SizedBox(height: 8),
                          _InfoRow(icon: Icons.check_circle_outline,  label: 'Résolu le',  value: ctrl.formatDate(r.resolvedAt!)),
                        ],
                        const SizedBox(height: 8),
                        _InfoRow(icon: Icons.privacy_tip_outlined,    label: 'Anonyme',    value: r.isAnonymous ? 'Oui' : 'Non'),
                      ])),

                  // Routages
                  if (r.routings != null && r.routings!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _Section(icon: Icons.route_outlined, title: 'Routages (${r.routings!.length})',
                        child: Column(children: r.routings!.map((rt) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.background, borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.greyLight),
                          ),
                          child: Row(children: [
                            const Icon(Icons.business_outlined, size: 16, color: AppTheme.greyMedium),
                            const SizedBox(width: 8),
                            Expanded(child: Text(rt.authority?.name ?? 'Autorité #${rt.authorityId}',
                                style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkBlue))),
                            _Badge(label: rt.statusLabel, color: ctrl.getStatusColor(rt.status), icon: Icons.circle, small: true),
                          ]),
                        )).toList())),
                  ],

                  const SizedBox(height: 24),

                  // Boutons action
                  if (r.status == 'pending')
                    Row(children: [
                      Expanded(child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Get.to(() => EditReportScreen(report: r));
                          if (result == true) ctrl.loadReport();
                        },
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Modifier', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primaryGreen,
                          side: const BorderSide(color: AppTheme.primaryGreen),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: Obx(() => ElevatedButton.icon(
                        onPressed: ctrl.isDeleting.value ? null : () => _confirmDelete(context, ctrl),
                        icon: ctrl.isDeleting.value
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.delete_outline, size: 16),
                        label: const Text('Supprimer', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.error, foregroundColor: Colors.white,
                          elevation: 0, padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ))),
                    ]),

                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ]),
        );
      }),
    );
  }

  void _openGallery(BuildContext context, List<String> urls, int initialIndex) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _FullscreenGallery(urls: urls, initialIndex: initialIndex),
    ));
  }

  IconData _statusIcon(String s) {
    switch (s) { case 'pending': return Icons.hourglass_empty; case 'routed': return Icons.route; case 'in_progress': return Icons.sync; case 'resolved': return Icons.check_circle; default: return Icons.help_outline; }
  }

  void _confirmDelete(BuildContext ctx, ReportDetailController ctrl) {
    Get.defaultDialog(
      title: 'Supprimer',
      titleStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700),
      middleText: 'Voulez-vous vraiment supprimer ce signalement ?',
      middleTextStyle: const TextStyle(fontFamily: 'Poppins'),
      textCancel: 'Annuler', textConfirm: 'Supprimer',
      confirmTextColor: Colors.white, buttonColor: AppTheme.error,
      radius: 16,
      onConfirm: () { Get.back(); ctrl.deleteReport(); },
    );
  }
}

// ─── VISIONNEUSE PLEIN ÉCRAN ─────────────────────────────────────────────────

class _FullscreenGallery extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;
  const _FullscreenGallery({required this.urls, required this.initialIndex});

  @override
  State<_FullscreenGallery> createState() => _FullscreenGalleryState();
}

class _FullscreenGalleryState extends State<_FullscreenGallery> {
  late final PageController _pageCtrl = PageController(initialPage: widget.initialIndex);
  late int _current = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          PageView.builder(
            controller: _pageCtrl,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Center(
                child: Image.network(widget.urls[i], fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 60)),
              ),
            ),
          ),
          Positioned(
            top: 8, right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          if (widget.urls.length > 1)
            Positioned(
              bottom: 20, left: 0, right: 0,
              child: Center(
                child: Text('${_current + 1} / ${widget.urls.length}',
                    style: const TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── TIMELINE ────────────────────────────────────────────────────────────────

class _ProgressTimeline extends StatelessWidget {
  final String status;
  const _ProgressTimeline({required this.status});

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('En attente', 'pending',     Icons.hourglass_empty),
      ('Routé',      'routed',      Icons.route),
      ('En cours',   'in_progress', Icons.sync),
      ('Résolu',     'resolved',    Icons.check_circle),
    ];
    final currentIdx = steps.indexWhere((s) => s.$2 == status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final done = (i ~/ 2) < currentIdx;
            return Expanded(child: Container(height: 2.5, color: done ? AppTheme.primaryGreen : AppTheme.greyLight));
          }
          final idx     = i ~/ 2;
          final done    = idx <= currentIdx;
          final current = idx == currentIdx;
          final step    = steps[idx];
          return Column(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: current ? AppTheme.primaryGreen : done ? AppTheme.lightGreen.withOpacity(0.2) : AppTheme.greyLight,
                shape: BoxShape.circle,
                border: current ? Border.all(color: AppTheme.primaryGreen, width: 2) : null,
              ),
              child: Icon(step.$3, size: 16,
                  color: current ? Colors.white : done ? AppTheme.primaryGreen : AppTheme.greyMedium),
            ),
            const SizedBox(height: 5),
            Text(step.$1, style: TextStyle(
                fontFamily: 'Poppins', fontSize: 9,
                fontWeight: current ? FontWeight.w700 : FontWeight.normal,
                color: done ? AppTheme.primaryGreen : AppTheme.greyMedium)),
          ]);
        }),
      ),
    );
  }
}

// ─── WIDGETS ─────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Section({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: AppTheme.primaryGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: AppTheme.primaryGreen)),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkBlue)),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1, color: AppTheme.greyLight),
        const SizedBox(height: 12),
        child,
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 15, color: AppTheme.greyMedium),
      const SizedBox(width: 8),
      Text('$label: ', style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.greyMedium, fontWeight: FontWeight.w500)),
      Expanded(child: Text(value, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.darkBlue))),
    ]);
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final bool small;
  const _Badge({required this.label, required this.color, required this.icon, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: small ? 6 : 10, vertical: small ? 3 : 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: small ? 10 : 12, color: color),
        SizedBox(width: small ? 3 : 5),
        Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: small ? 10 : 11, color: color, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}