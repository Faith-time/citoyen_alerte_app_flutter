// lib/presentation/screens/reports/reports_list_screen.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/core/theme/neo_kit.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/data/models/report_model.dart';
import 'package:citoyen_alerte_app_backup/presentation/screens/reports/report_detail_screen.dart';
import 'report_neo_widgets.dart';

// ─── CONTROLLER (logique inchangée) ──────────────────────────────────────────

class ReportsListController extends GetxController {
  final ApiService _api = Get.find<ApiService>();

  final isLoading     = true.obs;
  final isLoadingMore = false.obs;
  final reports         = <ReportModel>[].obs;
  final filteredReports = <ReportModel>[].obs;
  final selectedFilter   = 'all'.obs;
  final selectedSeverity = 'all'.obs;
  final searchQuery      = ''.obs;

  int  _currentPage = 1;
  bool _hasMore     = true;
  static const _perPage = 20;

  @override
  void onInit() {
    super.onInit();
    loadReports(refresh: true);
  }

  Future<void> loadReports({bool refresh = false}) async {
    if (refresh) { _currentPage = 1; _hasMore = true; reports.clear(); }
    if (!_hasMore) return;
    try {
      if (refresh) isLoading.value = true;
      final response = await _api.getReports(queryParameters: {
        'page': _currentPage, 'per_page': _perPage,
        'sort_by': 'created_at', 'sort_order': 'desc',
      });
      if (response.success && response.data != null) {
        final data     = response.data as Map<String, dynamic>;
        final List items = data['data'] as List? ?? [];
        final lastPage = data['last_page'] as int? ?? 1;
        reports.addAll(items.map((e) => ReportModel.fromJson(e)));
        _hasMore = _currentPage < lastPage;
        _currentPage++;
        _applyFilter();
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de charger les signalements',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.error, colorText: Colors.white,
          margin: const EdgeInsets.all(16), borderRadius: 12);
    } finally {
      isLoading.value     = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> loadMore() async {
    if (isLoadingMore.value || !_hasMore) return;
    isLoadingMore.value = true;
    await loadReports();
  }

  void setStatusFilter(String f)   { selectedFilter.value   = f; _applyFilter(); }
  void setSeverityFilter(String f) { selectedSeverity.value = f; _applyFilter(); }
  void setSearch(String q)         { searchQuery.value       = q; _applyFilter(); }

  void _applyFilter() {
    var list = reports.toList();
    if (selectedFilter.value   != 'all') list = list.where((r) => r.status   == selectedFilter.value).toList();
    if (selectedSeverity.value != 'all') list = list.where((r) => r.severity == selectedSeverity.value).toList();
    if (searchQuery.value.isNotEmpty) {
      final q = searchQuery.value.toLowerCase();
      list = list.where((r) =>
      r.title.toLowerCase().contains(q) ||
          r.address.toLowerCase().contains(q) ||
          r.communeName.toLowerCase().contains(q)).toList();
    }
    filteredReports.assignAll(list);
  }

  // Helpers d'affichage (centralisés dans ReportUi, noms conservés)
  Color  getSeverityColor(String s) => ReportUi.severityColor(s);
  Color  getStatusColor(String s)   => ReportUi.statusColor(s);
  String getStatusLabel(String s)   => ReportUi.statusLabel(s);
  String getSeverityLabel(String s) => ReportUi.severityLabel(s);
  String timeAgo(DateTime date)     => ReportUi.timeAgo(date);
}

// ─── SCREEN ──────────────────────────────────────────────────────────────────

class ReportsListScreen extends StatefulWidget {
  const ReportsListScreen({super.key});

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen> {
  late final ReportsListController ctrl;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(ReportsListController());
    _scrollCtrl.addListener(() {
      if (_scrollCtrl.hasClients &&
          _scrollCtrl.position.pixels >= _scrollCtrl.position.maxScrollExtent - 200) {
        ctrl.loadMore();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canBack = Get.previousRoute.isNotEmpty;

    return Scaffold(
      backgroundColor: Neo.bg,
      body: NeoBackdrop(
        child: Column(children: [
          Obx(() {
            final n = ctrl.filteredReports.length;
            return NeoTitleBar(
              title: 'Tous les signalements',
              subtitle: '$n signalement${n > 1 ? 's' : ''}',
              leading: canBack
                  ? NeoIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Get.back())
                  : null,
              actions: [
                NeoIconButton(icon: Icons.refresh_rounded, onTap: () => ctrl.loadReports(refresh: true)),
              ],
            );
          }),
          ReportSearchField(
            controller: _searchCtrl,
            onChanged: ctrl.setSearch,
            onClear: () {
              _searchCtrl.clear();
              ctrl.setSearch('');
            },
            queryObs: ctrl.searchQuery,
          ),
          ReportFilterChips(
            filters: ReportUi.statusFilters,
            selected: ctrl.selectedFilter,
            onSelect: ctrl.setStatusFilter,
          ),
          const SizedBox(height: 8),
          ReportFilterChips(
            filters: ReportUi.severityFilters,
            selected: ctrl.selectedSeverity,
            onSelect: ctrl.setSeverityFilter,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ctrl.loadReports(refresh: true),
              color: Neo.blue,
              child: Obx(() {
                if (ctrl.isLoading.value) return const NeoLoading();
                final list = ctrl.filteredReports;
                if (list.isEmpty) {
                  return const NeoEmpty(
                    icon: Icons.search_off_rounded,
                    title: 'Aucun signalement',
                    message: 'Essayez de modifier vos filtres.',
                  );
                }
                final more = ctrl.isLoadingMore.value;
                return ListView.builder(
                  controller: _scrollCtrl,
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  itemCount: list.length + (more ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == list.length) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Neo.blue),
                          ),
                        ),
                      );
                    }
                    final r = list[i];
                    return NeoReveal(
                      delayMs: (i % 8) * 40,
                      child: ReportNeoCard(
                        report: r,
                        onTap: () => Get.to(() => ReportDetailScreen(reportId: r.id)),
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