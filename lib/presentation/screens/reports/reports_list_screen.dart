// lib/presentation/screens/reports/reports_list_screen.dart

import 'package:citoyen_alerte_app_backup/presentation/screens/reports/report_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/data/models/report_model.dart';

// ─── CONTROLLER ──────────────────────────────────────────────────────────────

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

  Color getSeverityColor(String s) {
    switch (s) {
      case 'high':   return AppTheme.error;
      case 'medium': return AppTheme.warning;
      case 'low':    return AppTheme.success;
      default:       return AppTheme.greyMedium;
    }
  }

  Color getStatusColor(String s) {
    switch (s) {
      case 'pending':     return AppTheme.warning;
      case 'routed':      return const Color(0xFF3B82F6);
      case 'in_progress': return const Color(0xFF8B5CF6);
      case 'resolved':    return AppTheme.success;
      default:            return AppTheme.greyMedium;
    }
  }

  String getStatusLabel(String s) {
    switch (s) {
      case 'pending':     return 'En attente';
      case 'routed':      return 'Routé';
      case 'in_progress': return 'En cours';
      case 'resolved':    return 'Résolu';
      default:            return s;
    }
  }

  String getSeverityLabel(String s) {
    switch (s) {
      case 'low':    return 'Faible';
      case 'medium': return 'Moyen';
      case 'high':   return 'Élevé';
      default:       return s;
    }
  }

  String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30)    return '${(diff.inDays / 30).floor()}mois';
    if (diff.inDays > 0)     return 'Il y a ${diff.inDays}j';
    if (diff.inHours > 0)    return 'Il y a ${diff.inHours}h';
    if (diff.inMinutes > 0)  return 'Il y a ${diff.inMinutes}min';
    return 'À l\'instant';
  }
}

// ─── SCREEN ──────────────────────────────────────────────────────────────────

class ReportsListScreen extends StatelessWidget {
  const ReportsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl       = Get.put(ReportsListController());
    final searchCtrl = TextEditingController();
    final scrollCtrl = ScrollController();

    scrollCtrl.addListener(() {
      if (scrollCtrl.position.pixels >= scrollCtrl.position.maxScrollExtent - 200) {
        ctrl.loadMore();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.background,
      // ── AppBar vert ──────────────────────────────────────────────────────
      appBar: _GreenAppBar(
        title: 'Tous les signalements',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: () => ctrl.loadReports(refresh: true),
          ),
        ],
      ),
      body: Column(
        children: [

          // ── Barre de recherche ───────────────────────────────────────────
          _SearchBar(
            controller: searchCtrl,
            onChanged: ctrl.setSearch,
            onClear: () { searchCtrl.clear(); ctrl.setSearch(''); },
            queryObs: ctrl.searchQuery,
          ),

          // ── Filtres statut ───────────────────────────────────────────────
          Container(
            color: AppTheme.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Obx(() => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _FilterChip(label: 'Tous',       isSelected: ctrl.selectedFilter.value == 'all',         onTap: () => ctrl.setStatusFilter('all')),
                const SizedBox(width: 8),
                _FilterChip(label: 'En attente', color: AppTheme.warning,        isSelected: ctrl.selectedFilter.value == 'pending',     onTap: () => ctrl.setStatusFilter('pending')),
                const SizedBox(width: 8),
                _FilterChip(label: 'Routé',      color: const Color(0xFF3B82F6), isSelected: ctrl.selectedFilter.value == 'routed',      onTap: () => ctrl.setStatusFilter('routed')),
                const SizedBox(width: 8),
                _FilterChip(label: 'En cours',   color: const Color(0xFF8B5CF6), isSelected: ctrl.selectedFilter.value == 'in_progress', onTap: () => ctrl.setStatusFilter('in_progress')),
                const SizedBox(width: 8),
                _FilterChip(label: 'Résolus',    color: AppTheme.success,        isSelected: ctrl.selectedFilter.value == 'resolved',    onTap: () => ctrl.setStatusFilter('resolved')),
              ]),
            )),
          ),

          // ── Filtres sévérité ─────────────────────────────────────────────
          Container(
            color: AppTheme.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Obx(() => Row(children: [
              _SevChip(label: 'Toutes',    isSelected: ctrl.selectedSeverity.value == 'all',    onTap: () => ctrl.setSeverityFilter('all')),
              const SizedBox(width: 8),
              _SevChip(label: '🟢 Faible', color: AppTheme.success, isSelected: ctrl.selectedSeverity.value == 'low',    onTap: () => ctrl.setSeverityFilter('low')),
              const SizedBox(width: 8),
              _SevChip(label: '🟡 Moyen',  color: AppTheme.warning, isSelected: ctrl.selectedSeverity.value == 'medium', onTap: () => ctrl.setSeverityFilter('medium')),
              const SizedBox(width: 8),
              _SevChip(label: '🔴 Élevé',  color: AppTheme.error,   isSelected: ctrl.selectedSeverity.value == 'high',   onTap: () => ctrl.setSeverityFilter('high')),
            ])),
          ),

          const Divider(height: 1, color: AppTheme.greyLight),

          // ── Compteur ─────────────────────────────────────────────────────
          Obx(() => Container(
            color: AppTheme.background,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Text(
                '${ctrl.filteredReports.length} signalement${ctrl.filteredReports.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontFamily: 'Poppins', fontSize: 12,
                  color: AppTheme.greyMedium, fontWeight: FontWeight.w500,
                ),
              ),
            ]),
          )),

          // ── Liste ────────────────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ctrl.loadReports(refresh: true),
              color: AppTheme.primaryGreen,
              child: Obx(() {
                if (ctrl.isLoading.value) {
                  return const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen));
                }
                if (ctrl.filteredReports.isEmpty) {
                  return _EmptyList();
                }
                return ListView.builder(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: ctrl.filteredReports.length + (ctrl.isLoadingMore.value ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == ctrl.filteredReports.length) {
                      return const Center(
                        child: Padding(padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
                      );
                    }
                    return _ReportCard(report: ctrl.filteredReports[i], ctrl: ctrl);
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── REPORT CARD ─────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final ReportModel report;
  final ReportsListController ctrl;
  const _ReportCard({required this.report, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final sevColor    = ctrl.getSeverityColor(report.severity);
    final statusColor = ctrl.getStatusColor(report.status);
    final hasPhoto = report.images != null && report.images!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Get.to(() => ReportDetailScreen(reportId: report.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (hasPhoto) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    report.images!.first.url,
                    width: 56, height: 56, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(

                      width: 56, height: 56, color: AppTheme.greyLight,
                      child: const Icon(Icons.broken_image_outlined, size: 20, color: AppTheme.greyMedium),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ] else ...[
                Container(
                  width: 4, height: 44,
                  decoration: BoxDecoration(color: sevColor, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(report.title,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.darkBlue),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Row(children: [
                  Text(report.reference,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppTheme.greyMedium)),
                  if (report.category != null) ...[
                    const Text(' · ', style: TextStyle(color: AppTheme.greyMedium)),
                    Text(report.category!.name,
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppTheme.greyMedium)),
                  ],
                ]),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _StatusPill(label: ctrl.getStatusLabel(report.status), color: statusColor),
                const SizedBox(height: 4),
                Text(ctrl.timeAgo(report.createdAt),

                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppTheme.greyMedium)),
              ]),
            ]),
            const SizedBox(height: 8),
            Text(report.description,
                maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.greyMedium, height: 1.5)),
            const SizedBox(height: 10),
            Row(children: [
              const Icon(Icons.location_on_outlined, size: 13, color: AppTheme.greyMedium),
              const SizedBox(width: 4),
              Expanded(child: Text(
                '${report.communeName}, ${report.regionName}',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppTheme.greyMedium),
                overflow: TextOverflow.ellipsis,
              )),
              Icon(Icons.warning_amber_rounded, size: 13, color: sevColor),
              const SizedBox(width: 4),
              Text(ctrl.getSeverityLabel(report.severity),
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: sevColor, fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
      ),
    );
  }
}
// ─── SHARED WIDGETS ──────────────────────────────────────────────────────────

/// AppBar vert avec coins arrondis en bas
class _GreenAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  const _GreenAppBar({required this.title, this.actions, this.showBack = true});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.primaryGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(children: [
            if (showBack && Get.previousRoute.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                onPressed: () => Get.back(),
              ),
            const SizedBox(width: 4),
            Expanded(child: Text(title,
                style: const TextStyle(
                    fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white))),
            if (actions != null) ...actions!,
          ]),
        ),
      ),
    );
  }
}

/// Barre de recherche
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final RxString queryObs;
  const _SearchBar({required this.controller, required this.onChanged, required this.onClear, required this.queryObs});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppTheme.darkBlue),
        decoration: InputDecoration(
          hintText: 'Rechercher un signalement...',
          hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppTheme.greyMedium),
          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppTheme.greyMedium),
          suffixIcon: Obx(() => queryObs.value.isNotEmpty
              ? IconButton(icon: const Icon(Icons.clear, size: 18, color: AppTheme.greyMedium), onPressed: onClear)
              : const SizedBox.shrink()),
          filled: true,
          fillColor: AppTheme.background,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.greyLight)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.greyLight)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5)),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;
  const _FilterChip({required this.label, required this.isSelected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primaryGreen;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? c : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? c : AppTheme.greyLight),
        ),
        child: Text(label, style: TextStyle(
            fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.greyMedium)),
      ),
    );
  }
}

class _SevChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;
  const _SevChip({required this.label, required this.isSelected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.greyMedium;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? c.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? c : AppTheme.greyLight),
        ),
        child: Text(label, style: TextStyle(
            fontFamily: 'Poppins', fontSize: 11,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.normal,
            color: isSelected ? c : AppTheme.greyMedium)),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label, style: TextStyle(
          fontFamily: 'Poppins', fontSize: 10, color: color, fontWeight: FontWeight.w700)),
    );
  }
}

class _EmptyList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.search_off_rounded, size: 72, color: AppTheme.greyMedium.withOpacity(0.3)),
      const SizedBox(height: 16),
      const Text('Aucun signalement', style: TextStyle(
          fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.darkBlue)),
      const SizedBox(height: 8),
      const Text('Essayez de modifier vos filtres', style: TextStyle(
          fontFamily: 'Poppins', fontSize: 13, color: AppTheme.greyMedium)),
    ]));
  }
}