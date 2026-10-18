// lib/presentation/screens/reports/report_detail_screen.dart
//
// Design Neo. La logique du controller est inchangée.
// Photos : miniatures + visionneuse plein écran (zoom, swipe).

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/core/theme/neo_kit.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/data/models/report_model.dart';
import 'edit_report_screen.dart';
import 'report_neo_widgets.dart';

// ─── CONTROLLER (logique inchangée) ──────────────────────────────────────────

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

  // Helpers d'affichage (centralisés dans ReportUi, noms conservés)
  Color  getSeverityColor(String s) => ReportUi.severityColor(s);
  Color  getStatusColor(String s)   => ReportUi.statusColor(s);
  String getStatusLabel(String s)   => ReportUi.statusLabel(s);
  String getSeverityLabel(String s) => ReportUi.severityLabel(s);
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
      backgroundColor: Neo.bg,
      body: NeoBackdrop(
        child: Obx(() {
          final loading = ctrl.isLoading.value;
          final r = ctrl.report.value;

          if (loading) {
            return const _Shell(child: NeoLoading());
          }
          if (r == null) {
            return const _Shell(
              child: NeoEmpty(
                icon: Icons.search_off_rounded,
                title: 'Signalement introuvable',
                message: 'Il a peut-être été supprimé.',
              ),
            );
          }

          final isPending = r.status == 'pending';
          final photos = r.images ?? const [];

          return Column(children: [
            NeoTitleBar(
              title: 'Signalement',
              subtitle: r.reference,
              leading: NeoIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Get.back()),
              actions: [
                if (isPending)
                  NeoIconButton(icon: Icons.edit_outlined, onTap: () => _edit(r, ctrl)),
              ],
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                children: [
                  // Photos — en premier : c'est l'info la plus parlante
                  if (photos.isNotEmpty) ...[
                    NeoSectionTitle('Photos (${photos.length})', icon: Icons.photo_library_outlined),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 130,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: photos.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => GestureDetector(
                          onTap: () => _openGallery(context, photos.map((img) => img.url).toList(), i),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: Neo.softRelief(),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(17),
                              child: Image.network(
                                photos[i].url,
                                width: 124,
                                height: 124,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 124,
                                  height: 124,
                                  color: Neo.inset,
                                  child: const Icon(Icons.broken_image_outlined, color: Neo.muted),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Titre + badges
                  NeoCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.title, style: Neo.t(17, w: FontWeight.w700)),
                      const SizedBox(height: 12),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        NeoPill(label: ctrl.getStatusLabel(r.status), color: ctrl.getStatusColor(r.status)),
                        NeoPill(
                          label: 'Gravité ${ctrl.getSeverityLabel(r.severity).toLowerCase()}',
                          color: ctrl.getSeverityColor(r.severity),
                        ),
                        if (r.category != null) NeoPill(label: r.category!.name, color: Neo.blue),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 16),

                  // Avancement
                  _ProgressTimeline(status: r.status),
                  const SizedBox(height: 20),

                  // Description
                  const NeoSectionTitle('Description', icon: Icons.description_outlined),
                  const SizedBox(height: 12),
                  NeoCard(
                    padding: const EdgeInsets.all(16),
                    child: Text(r.description, style: Neo.t(13)),
                  ),
                  const SizedBox(height: 20),

                  // Localisation
                  NeoGroup(title: 'LOCALISATION', children: [
                    NeoRow(icon: Icons.signpost_outlined, label: 'Adresse', value: r.address),
                    NeoRow(icon: Icons.location_city_outlined, label: 'Commune', value: r.communeName),
                    NeoRow(icon: Icons.map_outlined, label: 'Région', value: r.regionName),
                    NeoRow(
                      icon: Icons.gps_fixed,
                      label: 'Coordonnées',
                      value: '${r.latitude.toStringAsFixed(5)}, ${r.longitude.toStringAsFixed(5)}',
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // Informations
                  NeoGroup(title: 'INFORMATIONS', children: [
                    NeoRow(icon: Icons.calendar_today_outlined, label: 'Créé le', value: ctrl.formatDate(r.createdAt)),
                    NeoRow(icon: Icons.update, label: 'Mis à jour', value: ctrl.formatDate(r.updatedAt)),
                    if (r.resolvedAt != null)
                      NeoRow(icon: Icons.check_circle_outline, label: 'Résolu le', value: ctrl.formatDate(r.resolvedAt!)),
                    NeoRow(icon: Icons.privacy_tip_outlined, label: 'Anonyme', value: r.isAnonymous ? 'Oui' : 'Non'),
                  ]),

                  // Routages
                  if (r.routings != null && r.routings!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    NeoGroup(
                      title: 'ROUTAGES (${r.routings!.length})',
                      children: r.routings!
                          .map((rt) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(children: [
                          const Icon(Icons.business_outlined, size: 16, color: Neo.muted),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              rt.authority?.name ?? 'Autorité #${rt.authorityId}',
                              style: Neo.t(13, w: FontWeight.w600),
                            ),
                          ),
                          NeoPill(label: rt.statusLabel, color: ReportUi.statusColor(rt.status)),
                        ]),
                      ))
                          .toList(),
                    ),
                  ],

                  // Actions
                  if (isPending) ...[
                    const SizedBox(height: 24),
                    Row(children: [
                      Expanded(
                        child: NeoButton(label: 'Modifier', outlined: true, onTap: () => _edit(r, ctrl)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Obx(() => _DangerButton(
                          label: 'Supprimer',
                          loading: ctrl.isDeleting.value,
                          onTap: () => _confirmDelete(context, ctrl),
                        )),
                      ),
                    ]),
                  ],
                ],
              ),
            ),
          ]);
        }),
      ),
    );
  }

  Future<void> _edit(ReportModel r, ReportDetailController ctrl) async {
    final result = await Get.to(() => EditReportScreen(report: r));
    if (result == true) ctrl.loadReport();
  }

  void _openGallery(BuildContext context, List<String> urls, int initialIndex) {
    Navigator.of(context).push(PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black87,
      pageBuilder: (_, __, ___) => _FullscreenGallery(urls: urls, initialIndex: initialIndex),
    ));
  }

  Future<void> _confirmDelete(BuildContext context, ReportDetailController ctrl) async {
    final ok = await neoConfirm(
      context,
      title: 'Supprimer',
      message: 'Voulez-vous vraiment supprimer ce signalement ?',
      confirm: 'Supprimer',
    );
    if (ok) ctrl.deleteReport();
  }
}

/// Barre de titre + contenu (états chargement / introuvable).
class _Shell extends StatelessWidget {
  final Widget child;
  const _Shell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      NeoTitleBar(
        title: 'Signalement',
        subtitle: 'Détail',
        leading: NeoIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Get.back()),
      ),
      Expanded(child: child),
    ]);
  }
}

// ─── BOUTON DANGER ───────────────────────────────────────────────────────────

class _DangerButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _DangerButton({required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return NeoPressable(
      onTap: loading ? () {} : onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Neo.danger.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Neo.danger.withValues(alpha: 0.35)),
        ),
        child: loading
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: Neo.danger),
        )
            : Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.delete_outline_rounded, size: 18, color: Neo.danger),
          const SizedBox(width: 6),
          Text(label, style: Neo.t(14, w: FontWeight.w700, c: Neo.danger)),
        ]),
      ),
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
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

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
                child: Image.network(
                  widget.urls[i],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) =>
                  const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 60),
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          if (widget.urls.length > 1)
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Text('${_current + 1} / ${widget.urls.length}',
                    style: Neo.t(13, w: FontWeight.w600, c: Colors.white)),
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
      ('En attente', 'pending', Icons.hourglass_empty),
      ('Routé', 'routed', Icons.route),
      ('En cours', 'in_progress', Icons.sync),
      ('Résolu', 'resolved', Icons.check_circle),
    ];
    final currentIdx = steps.indexWhere((s) => s.$2 == status);

    return NeoCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(steps.length * 2 - 1, (i) {
          if (i.isOdd) {
            final done = (i ~/ 2) < currentIdx;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 17),
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: done ? Neo.blue : Neo.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            );
          }
          final idx = i ~/ 2;
          final done = idx <= currentIdx;
          final current = idx == currentIdx;
          final step = steps[idx];
          return Column(children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: current
                    ? Neo.blue
                    : done
                    ? Neo.blue.withValues(alpha: 0.12)
                    : Neo.inset,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.5),
                boxShadow: current ? Neo.softRelief() : null,
              ),
              child: Icon(step.$3,
                  size: 17,
                  color: current
                      ? Colors.white
                      : done
                      ? Neo.blue
                      : Neo.muted),
            ),
            const SizedBox(height: 6),
            Text(step.$1,
                style: Neo.t(10,
                    w: current ? FontWeight.w700 : FontWeight.w500,
                    c: done ? Neo.blue : Neo.muted)),
          ]);
        }),
      ),
    );
  }
}