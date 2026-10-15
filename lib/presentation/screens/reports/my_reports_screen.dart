import 'package:citoyen_alerte_app_backup/presentation/screens/reports/report_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/core/services/auth_service.dart';
import 'package:citoyen_alerte_app_backup/data/models/report_model.dart';
import 'create_report_screen.dart';
import 'edit_report_screen.dart';

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

      // ✅ Utilise l'endpoint dédié
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

    // Filtre statut
    if (selectedFilter.value != 'all') {
      list = list.where((r) => r.status == selectedFilter.value).toList();
    }

    // Recherche
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
  int get inProgress => myReports.where((r) => r.status == 'in_progress').length;
  int get resolved => myReports.where((r) => r.status == 'resolved').length;

  Color getSeverityColor(String s) {
    switch (s) {
      case 'high': return AppTheme.error;
      case 'medium': return AppTheme.warning;
      case 'low': return AppTheme.success;
      default: return AppTheme.grey;
    }
  }

  Color getStatusColor(String s) {
    switch (s) {
      case 'pending': return AppTheme.warning;
      case 'routed': return Colors.blue;
      case 'in_progress': return Colors.purple;
      case 'resolved': return AppTheme.success;
      default: return AppTheme.grey;
    }
  }

  String getStatusLabel(String s) {
    switch (s) {
      case 'pending': return 'En attente';
      case 'routed': return 'Routé';
      case 'in_progress': return 'En cours';
      case 'resolved': return 'Résolu';
      default: return s;
    }
  }

  String getSeverityLabel(String s) {
    switch (s) {
      case 'low': return 'Faible';
      case 'medium': return 'Moyen';
      case 'high': return 'Élevé';
      default: return s;
    }
  }

  String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()}mois';
    if (diff.inDays > 0) return 'Il y a ${diff.inDays}j';
    if (diff.inHours > 0) return 'Il y a ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'Il y a ${diff.inMinutes}min';
    return 'À l\'instant';
  }
}

// ─── SCREEN ──────────────────────────────────────────────────────────────────

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(MyReportsController());
    final searchCtrl = TextEditingController();

    return Scaffold(
      backgroundColor: AppTheme.greyLight.withOpacity(0.3),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(65),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withOpacity(0.85)],
            ),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Get.back(),
                  ),
                  const Expanded(
                    child: Text(
                      'Mes signalements',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: ctrl.loadMyReports,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Get.to(() => const CreateReportScreen());
          if (result == true) ctrl.loadMyReports();
        },
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouveau',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Stats rapides
          Obx(() {
            if (ctrl.isLoading.value) return const SizedBox.shrink();
            return Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _QuickStat(value: '${ctrl.total}', label: 'Total', color: AppTheme.primaryGreen),
                  _Divider(),
                  _QuickStat(value: '${ctrl.pending}', label: 'Attente', color: AppTheme.warning),
                  _Divider(),
                  _QuickStat(value: '${ctrl.inProgress}', label: 'En cours', color: Colors.purple),
                  _Divider(),
                  _QuickStat(value: '${ctrl.resolved}', label: 'Résolus', color: AppTheme.success),
                ],
              ),
            );
          }),

          // Barre de recherche
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: searchCtrl,
              onChanged: ctrl.setSearch,
              decoration: InputDecoration(
                hintText: 'Rechercher un signalement...',
                prefixIcon: const Icon(Icons.search, size: 18, color: AppTheme.grey),
                suffixIcon: Obx(() => ctrl.searchQuery.value.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 18, color: AppTheme.grey),
                  onPressed: () {
                    searchCtrl.clear();
                    ctrl.setSearch('');
                  },
                )
                    : const SizedBox.shrink()),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.greyLight),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppTheme.greyLight),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryGreen),
                ),
                filled: true,
                fillColor: AppTheme.greyLight.withOpacity(0.4),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                hintStyle: TextStyle(color: AppTheme.grey.withOpacity(0.6), fontSize: 13),
              ),
            ),
          ),

          // Filtres
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Obx(() => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _Chip(label: 'Tous', isSelected: ctrl.selectedFilter.value == 'all', onTap: () => ctrl.setFilter('all')),
                  const SizedBox(width: 8),
                  _Chip(label: 'En attente', color: AppTheme.warning, isSelected: ctrl.selectedFilter.value == 'pending', onTap: () => ctrl.setFilter('pending')),
                  const SizedBox(width: 8),
                  _Chip(label: 'Routé', color: Colors.blue, isSelected: ctrl.selectedFilter.value == 'routed', onTap: () => ctrl.setFilter('routed')),
                  const SizedBox(width: 8),
                  _Chip(label: 'En cours', color: Colors.purple, isSelected: ctrl.selectedFilter.value == 'in_progress', onTap: () => ctrl.setFilter('in_progress')),
                  const SizedBox(width: 8),
                  _Chip(label: 'Résolus', color: AppTheme.success, isSelected: ctrl.selectedFilter.value == 'resolved', onTap: () => ctrl.setFilter('resolved')),
                ],
              ),
            )),
          ),

          const Divider(height: 1),

          // Liste
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.loadMyReports,
              color: AppTheme.primaryGreen,
              child: Obx(() {
                if (ctrl.isLoading.value) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                  );
                }

                if (ctrl.filteredReports.isEmpty) {
                  return _EmptyState(
                    query: ctrl.searchQuery.value,
                    filter: ctrl.selectedFilter.value,
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  itemCount: ctrl.filteredReports.length,
                  itemBuilder: (_, i) => _ReportTile(
                    report: ctrl.filteredReports[i],
                    ctrl: ctrl,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── REPORT TILE ─────────────────────────────────────────────────────────────

class _ReportTile extends StatelessWidget {
  final ReportModel report;
  final MyReportsController ctrl;

  const _ReportTile({required this.report, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final hasPhoto = report.images != null && report.images!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final result =
          await Get.to(() => ReportDetailScreen(reportId: report.id));
          if (result == 'deleted') ctrl.loadMyReports();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                children: [
                  if (hasPhoto)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        report.images!.first.url,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: AppTheme.greyLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.broken_image_outlined,
                              size: 18, color: AppTheme.greyMedium),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ctrl.getSeverityColor(report.severity).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.warning_amber,
                          color: ctrl.getSeverityColor(report.severity), size: 22),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(report.title,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(report.reference,
                                style: TextStyle(fontSize: 11, color: AppTheme.grey)),
                            if (report.category != null) ...[
                              Text(' · ', style: TextStyle(color: AppTheme.grey)),
                              Text(report.category!.name,
                                  style: TextStyle(fontSize: 11, color: AppTheme.grey)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(
                    label: ctrl.getStatusLabel(report.status),
                    color: ctrl.getStatusColor(report.status),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Description courte
              Text(report.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: AppTheme.grey, height: 1.4)),

              const SizedBox(height: 10),

              // Pied: localisation + temps
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 13, color: AppTheme.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${report.communeName}, ${report.regionName}',
                      style: TextStyle(fontSize: 11, color: AppTheme.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(ctrl.timeAgo(report.createdAt),
                      style: TextStyle(fontSize: 11, color: AppTheme.grey)),
                ],
              ),

              // Actions (si en attente)
              if (report.status == 'pending') ...[
                const SizedBox(height: 10),
                const Divider(height: 1),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        final result =
                        await Get.to(() => EditReportScreen(report: report));
                        if (result == true) ctrl.loadMyReports();
                      },
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      label: const Text('Modifier', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Obx(() => TextButton.icon(
                      onPressed: ctrl.isDeletingId.value == report.id
                          ? null
                          : () => _confirmDelete(context),
                      icon: ctrl.isDeletingId.value == report.id
                          ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.error))
                          : const Icon(Icons.delete_outline, size: 15),
                      label: const Text('Supprimer',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    )),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    Get.defaultDialog(
      title: 'Supprimer',
      middleText: 'Supprimer "${report.title}" ?',
      textCancel: 'Annuler',
      textConfirm: 'Supprimer',
      confirmTextColor: Colors.white,
      buttonColor: AppTheme.error,
      onConfirm: () {
        Get.back();
        ctrl.deleteReport(report.id);
      },
    );
  }
}
// ─── WIDGETS ─────────────────────────────────────────────────────────────────

class _QuickStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _QuickStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 11, color: AppTheme.grey)),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 32, color: AppTheme.greyLight);
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _Chip({required this.label, required this.isSelected, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primaryGreen;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? c : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? c : AppTheme.greyLight),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppTheme.grey)),
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
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String query;
  final String filter;
  const _EmptyState({required this.query, required this.filter});

  @override
  Widget build(BuildContext context) {
    final isSearch = query.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSearch ? Icons.search_off : Icons.warning_amber_outlined,
              size: 80,
              color: AppTheme.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              isSearch ? 'Aucun résultat pour "$query"' : 'Aucun signalement',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              isSearch
                  ? 'Essayez avec d\'autres mots-clés'
                  : filter == 'all'
                  ? 'Créez votre premier signalement en appuyant sur le bouton +'
                  : 'Aucun signalement dans cette catégorie',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.grey, fontSize: 13, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}