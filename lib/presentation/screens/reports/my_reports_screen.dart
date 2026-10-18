// lib/presentation/screens/reports/my_reports_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/core/theme/neo_kit.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/core/services/auth_service.dart';
import 'package:citoyen_alerte_app_backup/data/models/report_model.dart';
import 'package:citoyen_alerte_app_backup/presentation/screens/reports/report_detail_screen.dart';
import 'create_report_screen.dart';
import 'edit_report_screen.dart';
import 'report_neo_widgets.dart';

// ─── CONTROLLER (logique inchangée) ──────────────────────────────────────────

class MyReportsController extends GetxController {
  final ApiService _api = Get.find<ApiService>();
  final AuthService _auth = AuthService.instance;

  final isLoading = true.obs;
  final isDeletingId = Rx<int?>(null);
  final myReports = <ReportModel>[].obs;
  final filteredReports = <ReportModel>[].obs;
  final selectedFilter = 'all'.obs;
  final searchQuery = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadMyReports();
  }

  Future<void> loadMyReports() async {
    try {
      isLoading.value = true;
      final userId = _auth.userId.value ?? '';

      final response = await _api.getUserReports(userId);

      if (response.success && response.data != null) {
        final raw = response.data;
        List items = [];
        if (raw is Map<String, dynamic>) {
          items = (raw['data'] as List?) ?? [];
        } else if (raw is List) {
          items = raw;
        }
        myReports.assignAll(items.map((e) => ReportModel.fromJson(e as Map<String, dynamic>)));
        _applyFilter();
      }
    } catch (e) {
      debugPrint('❌ MyReports: $e');
      Get.snackbar('Erreur', 'Impossible de charger vos signalements',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.error,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16));
    } finally {
      isLoading.value = false;
    }
  }

  void setFilter(String filter) {
    selectedFilter.value = filter;
    _applyFilter();
  }

  void setSearch(String q) {
    searchQuery.value = q;
    _applyFilter();
  }

  void _applyFilter() {
    var list = myReports.toList();

    if (selectedFilter.value != 'all') {
      list = list.where((r) => r.status == selectedFilter.value).toList();
    }

    if (searchQuery.value.isNotEmpty) {
      final q = searchQuery.value.toLowerCase();
      list = list
          .where((r) =>
      r.title.toLowerCase().contains(q) ||
          r.reference.toLowerCase().contains(q) ||
          r.address.toLowerCase().contains(q))
          .toList();
    }

    filteredReports.assignAll(list);
  }

  Future<void> deleteReport(int id) async {
    try {
      isDeletingId.value = id;
      final response = await _api.deleteReport(id);
      if (response.success) {
        myReports.removeWhere((r) => r.id == id);
        _applyFilter();
        Get.snackbar('Supprimé ✓', 'Signalement supprimé',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppTheme.success,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16));
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de supprimer',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.error,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16));
    } finally {
      isDeletingId.value = null;
    }
  }

  // Statistiques
  int get total => myReports.length;
  int get pending => myReports.where((r) => r.status == 'pending').length;
  int get routed => myReports.where((r) => r.status == 'routed').length;
  int get inProgress => myReports.where((r) => r.status == 'in_progress').length;
  int get resolved => myReports.where((r) => r.status == 'resolved').length;

  // Helpers d'affichage (centralisés dans ReportUi, noms conservés)
  Color  getSeverityColor(String s) => ReportUi.severityColor(s);
  Color  getStatusColor(String s)   => ReportUi.statusColor(s);
  String getStatusLabel(String s)   => ReportUi.statusLabel(s);
  String getSeverityLabel(String s) => ReportUi.severityLabel(s);
  String timeAgo(DateTime date)     => ReportUi.timeAgo(date);
}

// ─── SCREEN ──────────────────────────────────────────────────────────────────

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  late final MyReportsController ctrl;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(MyReportsController());
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Neo.bg,
      floatingActionButton: _NewReportFab(onTap: () async {
        final result = await Get.to(() => const CreateReportScreen());
        if (result == true) ctrl.loadMyReports();
      }),
      body: NeoBackdrop(
        child: Column(children: [
          NeoTitleBar(
            title: 'Mes signalements',
            subtitle: "Suivez l'avancement de vos alertes",
            leading: NeoIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Get.back()),
            actions: [NeoIconButton(icon: Icons.refresh_rounded, onTap: ctrl.loadMyReports)],
          ),
          const SizedBox(height: 8),

          // Stats rapides
          Obx(() {
            if (ctrl.isLoading.value) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: NeoStatsStrip(items: [
                NeoStat('${ctrl.total}', 'Total'),
                NeoStat('${ctrl.pending}', 'Attente', Neo.warning),
                NeoStat('${ctrl.inProgress}', 'En cours', Neo.purple),
                NeoStat('${ctrl.resolved}', 'Résolus', Neo.success),
              ]),
            );
          }),

          // Recherche
          ReportSearchField(
            controller: _searchCtrl,
            onChanged: ctrl.setSearch,
            onClear: () {
              _searchCtrl.clear();
              ctrl.setSearch('');
            },
            queryObs: ctrl.searchQuery,
          ),

          // Filtres statut (avec compteurs)
          ReportFilterChips(
            filters: ReportUi.statusFilters,
            selected: ctrl.selectedFilter,
            onSelect: ctrl.setFilter,
            counts: () => {
              'all': ctrl.total,
              'pending': ctrl.pending,
              'routed': ctrl.routed,
              'in_progress': ctrl.inProgress,
              'resolved': ctrl.resolved,
            },
          ),
          const SizedBox(height: 8),

          // Liste
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadMyReports,
              color: Neo.blue,
              child: Obx(() {
                if (ctrl.isLoading.value) return const NeoLoading();

                final list = ctrl.filteredReports;
                if (list.isEmpty) {
                  final isSearch = ctrl.searchQuery.value.isNotEmpty;
                  return NeoEmpty(
                    icon: isSearch ? Icons.search_off_rounded : Icons.inbox_outlined,
                    title: isSearch
                        ? 'Aucun résultat pour "${ctrl.searchQuery.value}"'
                        : 'Aucun signalement',
                    message: isSearch
                        ? "Essayez avec d'autres mots-clés."
                        : ctrl.selectedFilter.value == 'all'
                        ? 'Créez votre premier signalement avec le bouton Nouveau.'
                        : 'Aucun signalement dans cette catégorie.',
                  );
                }

                return ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final r = list[i];
                    return NeoReveal(
                      delayMs: (i % 8) * 40,
                      child: ReportNeoCard(
                        report: r,
                        onTap: () async {
                          final result = await Get.to(() => ReportDetailScreen(reportId: r.id));
                          if (result == 'deleted') ctrl.loadMyReports();
                        },
                        footer: r.status == 'pending' ? _PendingActions(report: r, ctrl: ctrl) : null,
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── ACTIONS (signalement en attente) ────────────────────────────────────────

class _PendingActions extends StatelessWidget {
  final ReportModel report;
  final MyReportsController ctrl;
  const _PendingActions({required this.report, required this.ctrl});

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await neoConfirm(
      context,
      title: 'Supprimer',
      message: 'Supprimer "${report.title}" ?',
      confirm: 'Supprimer',
    );
    if (ok) ctrl.deleteReport(report.id);
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.end, children: [
      _ActionLink(
        icon: Icons.edit_outlined,
        label: 'Modifier',
        color: Neo.blue,
        onTap: () async {
          final result = await Get.to(() => EditReportScreen(report: report));
          if (result == true) ctrl.loadMyReports();
        },
      ),
      const SizedBox(width: 16),
      Obx(() {
        final deleting = ctrl.isDeletingId.value == report.id;
        return _ActionLink(
          icon: Icons.delete_outline_rounded,
          label: 'Supprimer',
          color: Neo.danger,
          loading: deleting,
          onTap: deleting ? null : () => _confirmDelete(context),
        );
      }),
    ]);
  }
}

class _ActionLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback? onTap;
  const _ActionLink({
    required this.icon,
    required this.label,
    required this.color,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          loading
              ? SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: color),
          )
              : Icon(icon, size: 16, color: color),
          const SizedBox(width: 5),
          Text(label, style: Neo.t(12, w: FontWeight.w600, c: color)),
        ]),
      ),
    );
  }
}

// ─── BOUTON FLOTTANT ─────────────────────────────────────────────────────────

class _NewReportFab extends StatelessWidget {
  final VoidCallback onTap;
  const _NewReportFab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return NeoPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Neo.blue, Neo.blueLight]),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Neo.blue.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text('Nouveau', style: Neo.t(14, w: FontWeight.w700, c: Colors.white)),
        ]),
      ),
    );
  }
}