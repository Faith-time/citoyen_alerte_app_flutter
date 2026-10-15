import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/services/dashboard_service.dart';
import 'package:citoyen_alerte_app_backup/core/services/auth_service.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/data/models/dashboard_model.dart';
import 'package:citoyen_alerte_app_backup/routes/app_pages.dart';

// ════════════════════════════════════════════════════════════════════════════
//  HELPERS
// ════════════════════════════════════════════════════════════════════════════

extension _ColorAlpha on Color {
  /// Remplace `withOpacity` (déprécié).
  Color op(double v) => withValues(alpha: v);
}

String _str(dynamic v, [String fallback = '']) {
  if (v == null) return fallback;
  final s = v.toString();
  return s.isEmpty ? fallback : s;
}

int? _asInt(dynamic v) => v is num ? v.toInt() : null;

String _categoryName(dynamic cat, [String fallback = 'Autre']) {
  if (cat is Map) return _str(cat['name'], fallback);
  return fallback;
}

String _firstPhoto(dynamic report, List<String> keys) {
  for (final k in keys) {
    final v = report[k];
    if (v is String && v.isNotEmpty) return v;
  }
  return '';
}

// ════════════════════════════════════════════════════════════════════════════
//  MODÈLES LOCAUX
// ════════════════════════════════════════════════════════════════════════════

class AdminTrendPoint {
  final String label;
  final int count;
  const AdminTrendPoint({required this.label, required this.count});
}

/// Signalement résolu affiché dans l'onglet Actualités (construit localement).
class AdminNewsEntry {
  final String title;
  final String communeName;
  final String category;
  final String zone;
  final String authority;
  final String beforePhotoUrl;
  final String afterPhotoUrl;
  final DateTime? date;

  const AdminNewsEntry({
    required this.title,
    required this.communeName,
    required this.category,
    required this.zone,
    required this.authority,
    required this.beforePhotoUrl,
    required this.afterPhotoUrl,
    required this.date,
  });

  bool get hasAfterPhoto => afterPhotoUrl.isNotEmpty;

  factory AdminNewsEntry.fromReport(Map<String, dynamic> r) {
    final auth = r['authority'];
    final authName = auth is Map
        ? _str(auth['name'])
        : _str(r['authority_name'], 'Autorité');
    final commune = _str(r['commune_name']);
    return AdminNewsEntry(
      title: _str(r['title'], 'Signalement'),
      communeName: commune,
      category: _categoryName(r['category']),
      zone: _str(r['region'], commune.isNotEmpty ? commune : 'Autres zones'),
      authority: authName.isEmpty ? 'Autorité' : authName,
      beforePhotoUrl:
      _firstPhoto(r, ['before_photo_url', 'photo_url', 'image_url']),
      afterPhotoUrl: _firstPhoto(r, ['after_photo_url', 'resolved_photo_url']),
      date: DateTime.tryParse(
          _str(r['resolved_at'], _str(r['updated_at'], _str(r['created_at'])))),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  CONTROLLER
// ════════════════════════════════════════════════════════════════════════════

class AdminDashboardController extends GetxController {
  final DashboardService _service = Get.find<DashboardService>();
  final ApiService _api = Get.find<ApiService>();

  // ── Navigation ────────────────────────────────────────────────────────────
  final currentIndex = 0.obs;
  final isMairie = false.obs;
  final mairieName = ''.obs;
  final mairieZone = ''.obs;

  // ── Filtres période ───────────────────────────────────────────────────────
  final selectedPeriod = 'month'.obs;
  static const Map<String, String> periods = {
    'day': "Aujourd'hui",
    'week': 'Cette semaine',
    'month': 'Ce mois',
    'year': 'Cette année',
  };

  // ── Filtre local pour les graphiques ──────────────────────────────────────
  final chartPeriod = 'week'.obs;
  static const Map<String, String> chartPeriods = {
    'day': '24h',
    'week': '7j',
    'month': '30j',
    'year': '1an',
  };

  final selectedCategory = ''.obs; // '' = toutes

  // ── Données ───────────────────────────────────────────────────────────────
  AdminDashboardModel? get data => _service.adminDashboard.value;
  bool get isLoading => _service.isLoadingAdmin.value;
  String get error => _service.adminError.value;

  // Accès tolérants (le modèle peut avoir des champs nullables ou non)
  dynamic get _d => data;

  AdminOverviewModel? get overview {
    final o = _d?.overview;
    return o is AdminOverviewModel ? o : null;
  }

  int? get apiTotalReports => _asInt(_d?.overview?.totalReports);
  int get apiNewUsers => _asInt(_d?.recentPeriod?.newUsers) ?? 0;

  dynamic get apiReportsByStatus => _d?.reportsByStatus;

  int? apiSeverity(String key) {
    final sv = _d?.reportsBySeverity;
    if (sv == null) return null;
    final dynamic v = switch (key) {
      'low' => sv.low,
      'medium' => sv.medium,
      _ => sv.high,
    };
    return _asInt(v);
  }

  Map<String, int> get apiCategoryBreakdown {
    final list = _d?.reportsByCategory;
    if (list is! List) return {};
    return {
      for (final c in list) _str(c.name, 'Autre'): _asInt(c.count) ?? 0,
    };
  }

  List<AdminAgentPerformanceModel> get agents {
    final a = _d?.agentPerformance;
    if (a is List) return a.whereType<AdminAgentPerformanceModel>().toList();
    return const [];
  }

  final reports = <Map<String, dynamic>>[].obs;
  final authorities = <Map<String, dynamic>>[].obs;
  final isLoadingReports = false.obs;
  final isLoadingAuth = false.obs;
  final routingFilter = 'pending'.obs;
  final unreadNotifications = 0.obs;
  final lastUpdatedAt = Rx<DateTime?>(null);

  // ── Polling mairie ────────────────────────────────────────────────────────
  Timer? _pollTimer;
  static const Duration _pollInterval = Duration(seconds: 45);

  // ── Données filtrées ──────────────────────────────────────────────────────
  List<Map<String, dynamic>> get filteredReports {
    final f = routingFilter.value;
    if (f == 'all') return reports.toList();
    return reports.where((r) => r['status'] == f).toList();
  }

  List<Map<String, dynamic>> get chartReports {
    final now = DateTime.now();
    final period = chartPeriod.value;
    final cat = selectedCategory.value;
    return reports.where((r) {
      final raw = r['created_at'];
      if (raw == null) return false;
      final dt = DateTime.tryParse(raw.toString());
      if (dt == null) return false;
      final diff = now.difference(dt);
      final inPeriod = switch (period) {
        'day' => diff.inHours < 24,
        'week' => diff.inDays < 7,
        'month' => diff.inDays < 30,
        'year' => diff.inDays < 365,
        _ => true,
      };
      if (!inPeriod) return false;
      if (cat.isEmpty) return true;
      return _categoryName(r['category'], '') == cat;
    }).toList();
  }

  int countByStatus(String status) {
    if (status == 'pending') {
      return reports
          .where((r) => r['status'] == 'pending' || r['status'] == 'acknowledged')
          .length;
    }
    return reports.where((r) => r['status'] == status).length;
  }

  Map<String, int> get categoryBreakdown {
    final map = <String, int>{};
    for (final r in chartReports) {
      final name = _categoryName(r['category']);
      map[name] = (map[name] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get severityBreakdown {
    final map = <String, int>{'low': 0, 'medium': 0, 'high': 0};
    for (final r in chartReports) {
      final s = _str(r['severity'], 'low');
      if (map.containsKey(s)) map[s] = map[s]! + 1;
    }
    return map;
  }

  Map<String, int> get statusBreakdown {
    final map = <String, int>{
      'pending': 0,
      'routed': 0,
      'in_progress': 0,
      'resolved': 0,
    };
    for (final r in chartReports) {
      final s = _str(r['status']);
      final key = (s == 'acknowledged') ? 'pending' : s;
      if (map.containsKey(key)) map[key] = map[key]! + 1;
    }
    return map;
  }

  List<AdminTrendPoint> get trendData {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final period = chartPeriod.value;
    final int days = switch (period) {
      'day' => 1,
      'week' => 7,
      'month' => 30,
      _ => 52,
    };

    if (period == 'year') {
      final weeks = List<int>.filled(52, 0);
      for (final r in chartReports) {
        final dt = DateTime.tryParse(_str(r['created_at']));
        if (dt == null) continue;
        final diff =
            today.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
        final weekIdx = (diff / 7).floor();
        if (weekIdx >= 0 && weekIdx < 52) weeks[51 - weekIdx]++;
      }
      return List.generate(
          52, (i) => AdminTrendPoint(label: 'S${i + 1}', count: weeks[i]));
    }

    final counts = List<int>.filled(days, 0);
    for (final r in chartReports) {
      final dt = DateTime.tryParse(_str(r['created_at']));
      if (dt == null) continue;
      final diff = today.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
      if (diff >= 0 && diff < days) counts[days - 1 - diff]++;
    }

    const joursCourt = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return List.generate(days, (i) {
      final d = now.subtract(Duration(days: days - 1 - i));
      final label = days <= 7 ? joursCourt[d.weekday - 1] : '${d.day}/${d.month}';
      return AdminTrendPoint(label: label, count: counts[i]);
    });
  }

  List<String> get allCategories {
    final cats = <String>{};
    for (final r in reports) {
      final name = _categoryName(r['category'], '');
      if (name.isNotEmpty) cats.add(name);
    }
    return cats.toList()..sort();
  }

  // ── Actualités (signalements résolus) ─────────────────────────────────────
  List<AdminNewsEntry> get newsItems => reports
      .where((r) => r['status'] == 'resolved')
      .map(AdminNewsEntry.fromReport)
      .toList();

  int get totalResolved => reports.where((r) => r['status'] == 'resolved').length;

  int get resolvedThisWeek {
    final now = DateTime.now();
    return newsItems.where((n) {
      final d = n.date;
      return d != null && now.difference(d).inDays < 7;
    }).length;
  }

  /// zone → autorité → entrées
  Map<String, Map<String, List<AdminNewsEntry>>> get groupedNews {
    final out = <String, Map<String, List<AdminNewsEntry>>>{};
    for (final n in newsItems) {
      out.putIfAbsent(n.zone, () => {}).putIfAbsent(n.authority, () => []).add(n);
    }
    return out;
  }

  @override
  void onInit() {
    super.onInit();
    _detectRoleAndLoad();
  }

  @override
  void onClose() {
    _pollTimer?.cancel();
    super.onClose();
  }

  Future<void> _detectRoleAndLoad() async {
    final authorityId = AuthService.instance.userAuthorityId.value;
    isMairie.value = authorityId != null;
    debugPrint('[AdminDash] authorityId=$authorityId → isMairie=${isMairie.value}');

    if (isMairie.value) {
      await _loadMairieDashboard();
      _startPolling();
    } else {
      await _service.fetchAdminDashboard(period: selectedPeriod.value);
      await _loadAuthorities();
    }
    await loadReports();
    await _loadUnreadNotifications();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      _loadMairieDashboard(silent: true);
      loadReports();
      _loadUnreadNotifications();
    });
  }

  Future<void> _loadMairieDashboard({bool silent = false}) async {
    try {
      final resp = await _api.get('/dashboard/mairie');
      debugPrint('[AdminDash] mairie resp success=${resp.success}');
      if (resp.success && resp.data != null) {
        final d = resp.data;
        if (d is Map) {
          mairieName.value = _str(d['authority_name']);
          mairieZone.value = _str(d['region']);
        }
      }
      lastUpdatedAt.value = DateTime.now();
    } catch (e) {
      debugPrint('[AdminDash] _loadMairieDashboard error: $e');
    }
  }

  Future<void> loadReports() async {
    isLoadingReports.value = true;
    try {
      final dynamic resp;
      if (isMairie.value) {
        resp = await _api.get('/municipality/reports',
            queryParameters: {'per_page': 200});
      } else {
        resp = await _api.getReports(queryParameters: {
          'per_page': 200,
          'sort_by': 'created_at',
          'sort_order': 'desc',
        });
      }
      if (resp.success == true && resp.data != null) {
        final raw = resp.data;
        List items = [];
        if (raw is Map) {
          final inner = raw['data'] ?? raw['items'] ?? [];
          if (inner is List) items = inner;
        } else if (raw is List) {
          items = raw;
        }
        reports.assignAll(items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList());
      }
      lastUpdatedAt.value = DateTime.now();
    } catch (e) {
      debugPrint('[AdminDash] loadReports error: $e');
    } finally {
      isLoadingReports.value = false;
    }
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final resp = await _api.get('/notifications/unread/count');
      if (resp.success && resp.data != null) {
        final d = resp.data;
        final count = d is Map ? d['count'] : d;
        unreadNotifications.value = _asInt(count) ?? int.tryParse('$count') ?? 0;
      }
    } catch (_) {}
  }

  Future<void> _loadAuthorities() async {
    isLoadingAuth.value = true;
    try {
      final resp = await _api.getAuthorities();
      if (resp.success && resp.data != null) {
        final raw = resp.data;
        final dynamic list = raw is List ? raw : (raw is Map ? raw['data'] : null);
        if (list is List) {
          authorities.assignAll(list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList());
        }
      }
    } catch (e) {
      debugPrint('[AdminDash] _loadAuthorities error: $e');
    } finally {
      isLoadingAuth.value = false;
    }
  }

  @override
  Future<void> refresh() async {
    if (isMairie.value) {
      await _loadMairieDashboard();
    } else {
      await _service.fetchAdminDashboard(period: selectedPeriod.value);
      if (authorities.isEmpty) await _loadAuthorities();
    }
    await loadReports();
    await _loadUnreadNotifications();
  }

  Future<void> changePeriod(String p) async {
    selectedPeriod.value = p;
    await _service.fetchAdminDashboard(period: p);
  }

  void changePage(int i) => currentIndex.value = i;
  void setChartPeriod(String p) => chartPeriod.value = p;
  void setSelectedCategory(String cat) => selectedCategory.value = cat;

  Future<void> routeReport({
    required int reportId,
    required int authorityId,
    required String authorityName,
  }) async {
    try {
      final resp =
      await _api.createReportRouting(reportId, {'authority_id': authorityId});
      if (resp.success) {
        final idx = reports.indexWhere((r) => r['id'] == reportId);
        if (idx != -1) {
          reports[idx] = {...reports[idx], 'status': 'routed'};
          reports.refresh();
        }
        Get.snackbar('Routage effectué ✓', 'Assigné à $authorityName',
            backgroundColor: AppTheme.primaryGreen,
            colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM,
            margin: const EdgeInsets.all(16));
        await Future.wait([
          loadReports(),
          _service.fetchAdminDashboard(period: selectedPeriod.value),
        ]);
      } else {
        _showError(_str(resp.message, 'Le routage a échoué'));
      }
    } catch (e) {
      _showError('Erreur : $e');
    }
  }

  void _showError(String msg) {
    Get.snackbar('Erreur', msg,
        backgroundColor: AppTheme.coral,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(16));
  }

  static Color statusColor(String s) => switch (s) {
    'pending' => AppTheme.warning,
    'acknowledged' => AppTheme.warning,
    'routed' => AppTheme.info,
    'in_progress' => AppTheme.purple,
    'resolved' => AppTheme.success,
    _ => AppTheme.greyMedium,
  };

  static String statusLabel(String s) => switch (s) {
    'pending' => 'En attente',
    'acknowledged' => 'En attente',
    'routed' => 'Routé',
    'in_progress' => 'En cours',
    'resolved' => 'Résolu',
    _ => s,
  };

  static Color severityColor(String s) => switch (s) {
    'high' => AppTheme.coral,
    'medium' => AppTheme.warning,
    'low' => AppTheme.success,
    _ => AppTheme.greyMedium,
  };

  static String severityLabel(String s) => switch (s) {
    'high' => 'ÉLEVÉ',
    'medium' => 'MOYEN',
    'low' => 'FAIBLE',
    _ => s.toUpperCase(),
  };
}

// ════════════════════════════════════════════════════════════════════════════
//  SCREEN PRINCIPAL
// ════════════════════════════════════════════════════════════════════════════

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(AdminDashboardController());

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Obx(() => IndexedStack(
        index: ctrl.currentIndex.value,
        children: ctrl.isMairie.value
            ? const [
          _MairieHomePage(),
          _MairieSupervisionPage(),
          _MairieNewsTab(),
          _AdminSettingsPage(),
        ]
            : const [
          _AdminHomePage(),
          _AdminRoutingPage(),
          _AdminAgentsPage(),
          _AdminUsersPage(),
          _AdminSettingsPage(),
        ],
      )),
      bottomNavigationBar: Obx(() => _AdminBottomNav(
        isMairie: ctrl.isMairie.value,
        currentIndex: ctrl.currentIndex.value,
        onTap: ctrl.changePage,
        pendingCount: ctrl.countByStatus('pending'),
      )),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  BOTTOM NAV
// ════════════════════════════════════════════════════════════════════════════

class _AdminBottomNav extends StatelessWidget {
  final bool isMairie;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int pendingCount;

  const _AdminBottomNav({
    required this.isMairie,
    required this.currentIndex,
    required this.onTap,
    required this.pendingCount,
  });

  @override
  Widget build(BuildContext context) {
    const accent = AppTheme.primaryGreen;
    final items = isMairie
        ? [
      const _NavDef(Icons.account_balance_outlined, Icons.account_balance, 'Accueil', 0),
      const _NavDef(Icons.visibility_outlined, Icons.visibility, 'Suivi', 0),
      const _NavDef(Icons.newspaper_outlined, Icons.newspaper, 'Actualités', 0),
      const _NavDef(Icons.settings_outlined, Icons.settings, 'Paramètres', 0),
    ]
        : [
      const _NavDef(Icons.dashboard_outlined, Icons.dashboard, 'Accueil', 0),
      _NavDef(Icons.route_outlined, Icons.route, 'Routage', pendingCount),
      const _NavDef(Icons.support_agent_outlined, Icons.support_agent, 'Agents', 0),
      const _NavDef(Icons.people_outline, Icons.people, 'Utilisateurs', 0),
      const _NavDef(Icons.settings_outlined, Icons.settings, 'Paramètres', 0),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: AppTheme.darkBlue.op(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final active = currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Stack(clipBehavior: Clip.none, children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: active ? accent.op(0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(active ? item.activeIcon : item.icon,
                              color: active ? accent : AppTheme.greyMedium, size: 20),
                        ),
                        if (item.badge > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 16),
                              height: 16,
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.warning,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white, width: 1.5),
                              ),
                              child: Center(
                                  child: Text('${item.badge}',
                                      style: const TextStyle(
                                          color: AppTheme.darkBlue,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold))),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 2),
                      Text(item.label,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 9,
                            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                            color: active ? accent : AppTheme.greyMedium,
                          )),
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

class _NavDef {
  final IconData icon, activeIcon;
  final String label;
  final int badge;
  const _NavDef(this.icon, this.activeIcon, this.label, this.badge);
}

// ════════════════════════════════════════════════════════════════════════════
//  PAGE ADMIN SYSTÈME — ACCUEIL
// ════════════════════════════════════════════════════════════════════════════

class _AdminHomePage extends StatelessWidget {
  const _AdminHomePage();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminDashboardController>();

    return Obx(() {
      if (ctrl.isLoading && ctrl.data == null && ctrl.reports.isEmpty) {
        return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGreen));
      }
      return RefreshIndicator(
        onRefresh: ctrl.refresh,
        color: AppTheme.primaryGreen,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _AdminHeader(ctrl: ctrl)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Obx(() {
                      final n = ctrl.countByStatus('pending');
                      if (n == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _PendingBanner(count: n, onTap: () => ctrl.changePage(1)),
                      );
                    }),

                    Obx(() {
                      final total = ctrl.reports.length;
                      final resolved = ctrl.countByStatus('resolved');
                      return _KpiRow(items: [
                        _KpiItem('${ctrl.apiTotalReports ?? total}', 'Signalements',
                            Icons.add_alert_outlined, AppTheme.yellow),
                        _KpiItem('$resolved', 'Résolus', Icons.check_circle_outline,
                            AppTheme.success),
                        _KpiItem('${ctrl.apiNewUsers}', 'Nouveaux\nutilisateurs',
                            Icons.person_add_outlined, AppTheme.info),
                      ]);
                    }),
                    const SizedBox(height: 22),

                    const _DashSectionTitle(title: 'Utilisateurs', icon: Icons.people_outline),
                    const SizedBox(height: 10),
                    Obx(() => _UsersRow(overview: ctrl.overview)),
                    const SizedBox(height: 22),

                    const _DashSectionTitle(
                        title: 'Tendance des signalements', icon: Icons.show_chart_rounded),
                    const SizedBox(height: 6),
                    _ChartPeriodSelector(ctrl: ctrl),
                    const SizedBox(height: 10),
                    Obx(() => _TrendLineChart(
                        points: ctrl.trendData, period: ctrl.chartPeriod.value)),
                    const SizedBox(height: 22),

                    const _DashSectionTitle(
                        title: 'Répartition par statut', icon: Icons.bar_chart_outlined),
                    const SizedBox(height: 10),
                    Obx(() => _StatusBreakdownCard(
                        byStatus: ctrl.apiReportsByStatus,
                        localCounts: ctrl.statusBreakdown)),
                    const SizedBox(height: 22),

                    Row(
                      children: [
                        const _DashSectionTitle(
                            title: 'Par catégorie', icon: Icons.pie_chart_outline),
                        const Spacer(),
                        _CategoryFilterChip(ctrl: ctrl),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Obx(() {
                      final api = ctrl.apiCategoryBreakdown;
                      // Le filtre catégorie s'applique aux données locales.
                      final useApi = api.isNotEmpty && ctrl.selectedCategory.value.isEmpty;
                      return _CategoryChart(data: useApi ? api : ctrl.categoryBreakdown);
                    }),
                    const SizedBox(height: 22),

                    const _DashSectionTitle(
                        title: 'Sévérité', icon: Icons.warning_amber_outlined),
                    const SizedBox(height: 10),
                    Obx(() {
                      final local = ctrl.severityBreakdown;
                      return _SeverityCards(
                        low: ctrl.apiSeverity('low') ?? local['low'] ?? 0,
                        medium: ctrl.apiSeverity('medium') ?? local['medium'] ?? 0,
                        high: ctrl.apiSeverity('high') ?? local['high'] ?? 0,
                      );
                    }),
                    const SizedBox(height: 22),

                    Obx(() {
                      final agents = ctrl.agents;
                      if (agents.isEmpty) return const SizedBox.shrink();
                      return Column(children: [
                        const _DashSectionTitle(
                            title: 'Top agents', icon: Icons.emoji_events_outlined),
                        const SizedBox(height: 10),
                        _AgentPodium(agents: agents),
                        const SizedBox(height: 22),
                      ]);
                    }),

                    const SizedBox(height: 40),
                  ])),
            ),
          ],
        ),
      );
    });
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  HEADER ADMIN SYSTÈME
// ════════════════════════════════════════════════════════════════════════════

class _AdminHeader extends StatelessWidget {
  final AdminDashboardController ctrl;
  const _AdminHeader({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: 186 + topInset,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(AppTheme.radiusXl),
              bottomRight: Radius.circular(AppTheme.radiusXl),
            ),
            child: SizedBox.expand(
              child: Container(
                decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
                child: const SenegalPatternBackground(),
              ),
            ),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(AppTheme.radiusXl),
                bottomRight: Radius.circular(AppTheme.radiusXl),
              ),
              child: FlagStripe(),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topInset + 14, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.op(0.16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.op(0.25)),
                      ),
                      child: const Icon(Icons.admin_panel_settings_outlined,
                          color: AppTheme.yellow, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Administration',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold)),
                      Text('Citoyen Alerte — Sénégal',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: Colors.white70,
                              fontSize: 11)),
                    ]),
                    const Spacer(),
                    Obx(() => _NotifBell(count: ctrl.unreadNotifications.value)),
                  ]),
                  const SizedBox(height: 16),
                  _PeriodScrollBar(ctrl: ctrl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PAGE MAIRIE — ACCUEIL
// ════════════════════════════════════════════════════════════════════════════

class _MairieHomePage extends StatelessWidget {
  const _MairieHomePage();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminDashboardController>();

    return Obx(() {
      if (ctrl.isLoadingReports.value && ctrl.reports.isEmpty) {
        return const Center(
            child: CircularProgressIndicator(color: AppTheme.primaryGreen));
      }
      return RefreshIndicator(
        onRefresh: ctrl.refresh,
        color: AppTheme.primaryGreen,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _MairieHeader(ctrl: ctrl)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Obx(() {
                      final n = ctrl.countByStatus('pending');
                      if (n == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _PendingBanner(count: n, onTap: () => ctrl.changePage(1)),
                      );
                    }),

                    Obx(() => _MairieStatsGrid(
                      total: ctrl.reports.length,
                      pending: ctrl.countByStatus('pending'),
                      routed: ctrl.countByStatus('routed'),
                      resolved: ctrl.countByStatus('resolved'),
                    )),
                    const SizedBox(height: 6),

                    Obx(() {
                      final t = ctrl.lastUpdatedAt.value;
                      if (t == null) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(left: 2, bottom: 14),
                        child: Row(children: [
                          const Icon(Icons.sync_rounded, size: 11, color: AppTheme.greyMedium),
                          const SizedBox(width: 4),
                          Text(
                              'Mis à jour à ${t.hour.toString().padLeft(2, '0')}:'
                                  '${t.minute.toString().padLeft(2, '0')} · auto',
                              style: AppTheme.caption),
                        ]),
                      );
                    }),

                    Row(children: [
                      Expanded(child: _ChartPeriodSelector(ctrl: ctrl)),
                      const SizedBox(width: 8),
                      _CategoryFilterChip(ctrl: ctrl),
                    ]),
                    const SizedBox(height: 16),

                    const _DashSectionTitle(title: 'Tendance', icon: Icons.show_chart_rounded),
                    const SizedBox(height: 10),
                    Obx(() => _TrendLineChart(
                        points: ctrl.trendData, period: ctrl.chartPeriod.value)),
                    const SizedBox(height: 22),

                    const _DashSectionTitle(
                        title: 'Répartition par statut', icon: Icons.bar_chart_outlined),
                    const SizedBox(height: 10),
                    Obx(() => _StatusBreakdownCard(
                        byStatus: null, localCounts: ctrl.statusBreakdown)),
                    const SizedBox(height: 22),

                    const _DashSectionTitle(
                        title: 'Par catégorie', icon: Icons.pie_chart_outline_rounded),
                    const SizedBox(height: 10),
                    Obx(() => _CategoryChart(data: ctrl.categoryBreakdown)),
                    const SizedBox(height: 22),

                    const _DashSectionTitle(
                        title: 'Sévérité', icon: Icons.warning_amber_outlined),
                    const SizedBox(height: 10),
                    Obx(() {
                      final sv = ctrl.severityBreakdown;
                      return _SeverityCards(
                          low: sv['low'] ?? 0,
                          medium: sv['medium'] ?? 0,
                          high: sv['high'] ?? 0);
                    }),
                    const SizedBox(height: 22),

                    const _DashSectionTitle(title: 'Récents', icon: Icons.history_outlined),
                    const SizedBox(height: 10),
                    Obx(() {
                      final items = ctrl.chartReports.take(5).toList();
                      if (items.isEmpty) {
                        return const _EmptyState(
                          icon: Icons.inbox_outlined,
                          message: 'Aucun signalement sur cette période',
                        );
                      }
                      return Column(
                        children: items.map((r) => _ReportMiniCard(report: r)).toList(),
                      );
                    }),
                    const SizedBox(height: 40),
                  ])),
            ),
          ],
        ),
      );
    });
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  HEADER MAIRIE
// ════════════════════════════════════════════════════════════════════════════

class _MairieHeader extends StatelessWidget {
  final AdminDashboardController ctrl;
  const _MairieHeader({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return SizedBox(
      height: 140 + topInset,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(AppTheme.radiusXl),
              bottomRight: Radius.circular(AppTheme.radiusXl),
            ),
            child: SizedBox.expand(
              child: Container(
                decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
                child: const SenegalPatternBackground(),
              ),
            ),
          ),
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(AppTheme.radiusXl),
                bottomRight: Radius.circular(AppTheme.radiusXl),
              ),
              child: FlagStripe(),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, topInset + 14, 20, 20),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: Colors.white.op(0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.op(0.25)),
                  ),
                  child: const Icon(Icons.account_balance,
                      color: AppTheme.yellow, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(() => Text(
                        ctrl.mairieName.value.isNotEmpty
                            ? ctrl.mairieName.value
                            : 'Mairie',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      )),
                      Obx(() => Text(
                        ctrl.mairieZone.value.isNotEmpty
                            ? 'Zone : ${ctrl.mairieZone.value}'
                            : 'Suivi des signalements',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: Colors.white.op(0.8),
                            fontSize: 11),
                      )),
                    ],
                  ),
                ),
                Obx(() => _NotifBell(count: ctrl.unreadNotifications.value)),
                const SizedBox(width: 8),
                Obx(() => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.yellow.op(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.yellow.op(0.4)),
                  ),
                  child: Text('${ctrl.countByStatus('pending')} en attente',
                      style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: AppTheme.yellow,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                )),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  GRAPHIQUES fl_chart
// ════════════════════════════════════════════════════════════════════════════

class _TrendLineChart extends StatelessWidget {
  final List<AdminTrendPoint> points;
  final String period;
  const _TrendLineChart({required this.points, required this.period});

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return _emptyChart();

    final maxVal = points.fold<int>(0, (m, p) => p.count > m ? p.count : m);
    final maxY = (maxVal < 4 ? 4 : maxVal + 2).toDouble();
    final total = points.fold<int>(0, (s, p) => s + p.count);
    final showEvery = period == 'year' ? 13 : (period == 'month' ? 5 : 1);
    final interval = (maxY / 4).clamp(1.0, double.infinity).toDouble();

    final spots = List.generate(
        points.length, (i) => FlSpot(i.toDouble(), points[i].count.toDouble()));

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('$total signalement${total != 1 ? 's' : ''}',
                style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.darkBlue)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primaryGreen.op(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(AdminDashboardController.chartPeriods[period] ?? period,
                  style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: AppTheme.primaryGreen,
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ),
          ]),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            child: LineChart(LineChartData(
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: interval,
                getDrawingHorizontalLine: (_) =>
                    FlLine(color: AppTheme.greyLight.op(0.6), strokeWidth: 1),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: interval,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text('${v.toInt()}', style: AppTheme.caption),
                      ),
                    )),
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        if (i < 0 || i >= points.length) return const SizedBox.shrink();
                        if (i % showEvery != 0) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(points[i].label, style: AppTheme.caption),
                        );
                      },
                    )),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.35,
                  color: AppTheme.primaryGreen,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: points.length <= 14,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 3.5,
                      color: AppTheme.primaryGreen,
                      strokeWidth: 2,
                      strokeColor: Colors.white,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.primaryGreen.op(0.20),
                        AppTheme.primaryGreen.op(0.01),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }

  Widget _emptyChart() => Container(
    height: 130,
    decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.cardShadow()),
    child: const Center(
      child: _EmptyState(
          icon: Icons.show_chart_rounded, message: 'Pas encore de données'),
    ),
  );
}

class _CategoryChart extends StatefulWidget {
  final Map<String, int> data;
  const _CategoryChart({required this.data});

  @override
  State<_CategoryChart> createState() => _CategoryChartState();
}

class _CategoryChartState extends State<_CategoryChart> {
  int _touchedIndex = -1;

  static const _colors = [
    AppTheme.primaryGreen,
    AppTheme.info,
    AppTheme.warning,
    AppTheme.coral,
    AppTheme.purple,
    AppTheme.lightGreen,
    Color(0xFF0EA5E9),
    Color(0xFFF97316),
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty || widget.data.values.every((v) => v == 0)) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.cardShadow()),
        child: const _EmptyState(
            icon: Icons.pie_chart_outline, message: 'Pas de données catégorie'),
      );
    }

    final entries = (widget.data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value)))
        .take(8)
        .toList();
    final total = entries.fold<int>(0, (a, b) => a + b.value);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.cardShadow()),
      child: Column(children: [
        SizedBox(
          height: 160,
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 44,
            pieTouchData: PieTouchData(
              touchCallback: (e, resp) {
                setState(() {
                  _touchedIndex = (e is FlTapUpEvent)
                      ? -1
                      : resp?.touchedSection?.touchedSectionIndex ?? -1;
                });
              },
            ),
            sections: List.generate(entries.length, (i) {
              final e = entries[i];
              final pct = total > 0 ? (e.value / total * 100) : 0.0;
              final isTouched = i == _touchedIndex;
              return PieChartSectionData(
                value: e.value.toDouble(),
                color: _colors[i % _colors.length],
                title: isTouched ? '${pct.round()}%\n${e.key}' : '${pct.round()}%',
                radius: isTouched ? 46 : 34,
                titleStyle: TextStyle(
                  fontSize: isTouched ? 10 : 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            }),
          )),
        ),
        const SizedBox(height: 14),
        ...List.generate(entries.length, (i) {
          final e = entries[i];
          final color = _colors[i % _colors.length];
          final pct = total > 0 ? e.value / total : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(
                          child: Text(e.key,
                              style: AppTheme.body, overflow: TextOverflow.ellipsis)),
                      Text('${e.value}',
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: color)),
                      const SizedBox(width: 6),
                      SizedBox(
                          width: 30,
                          child: Text('${(pct * 100).round()}%', style: AppTheme.caption)),
                    ]),
                    const SizedBox(height: 3),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 4,
                        backgroundColor: color.op(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ])),
            ]),
          );
        }),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  WIDGETS FILTRES
// ════════════════════════════════════════════════════════════════════════════

class _PeriodScrollBar extends StatelessWidget {
  final AdminDashboardController ctrl;
  const _PeriodScrollBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() => SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: AdminDashboardController.periods.entries.map((e) {
          final sel = ctrl.selectedPeriod.value == e.key;
          return GestureDetector(
            onTap: () => ctrl.changePeriod(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: sel ? AppTheme.yellow : Colors.white.op(0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(e.value,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: sel ? AppTheme.darkBlue : Colors.white)),
            ),
          );
        }).toList(),
      ),
    ));
  }
}

class _ChartPeriodSelector extends StatelessWidget {
  final AdminDashboardController ctrl;
  const _ChartPeriodSelector({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Container(
      height: 32,
      decoration: BoxDecoration(
        color: AppTheme.greyLight.op(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: AdminDashboardController.chartPeriods.entries.map((e) {
          final sel = ctrl.chartPeriod.value == e.key;
          return GestureDetector(
            onTap: () => ctrl.setChartPeriod(e.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? AppTheme.primaryGreen : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(e.value,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : AppTheme.greyMedium,
                  )),
            ),
          );
        }).toList(),
      ),
    ));
  }
}

class _CategoryFilterChip extends StatelessWidget {
  final AdminDashboardController ctrl;
  const _CategoryFilterChip({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final cats = ctrl.allCategories;
      if (cats.isEmpty) return const SizedBox.shrink();
      final sel = ctrl.selectedCategory.value;

      return GestureDetector(
        onTap: () {
          Get.bottomSheet(
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXl)),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Filtrer par catégorie', style: AppTheme.h2),
                      const SizedBox(height: 14),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _CatPill('Toutes', '', ctrl),
                        ...cats.map((c) => _CatPill(c, c, ctrl)),
                      ]),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: sel.isEmpty ? AppTheme.greyLight.op(0.6) : AppTheme.primaryGreen.op(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: sel.isEmpty ? AppTheme.greyLight : AppTheme.primaryGreen.op(0.4),
            ),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.filter_list_rounded,
                size: 14,
                color: sel.isEmpty ? AppTheme.greyMedium : AppTheme.primaryGreen),
            const SizedBox(width: 4),
            Text(sel.isEmpty ? 'Catégorie' : sel,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: sel.isEmpty ? AppTheme.greyMedium : AppTheme.primaryGreen,
                )),
          ]),
        ),
      );
    });
  }
}

class _CatPill extends StatelessWidget {
  final String label, value;
  final AdminDashboardController ctrl;
  const _CatPill(this.label, this.value, this.ctrl);

  @override
  Widget build(BuildContext context) {
    final sel = ctrl.selectedCategory.value == value;
    return GestureDetector(
      onTap: () {
        ctrl.setSelectedCategory(value);
        Get.back();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? AppTheme.primaryGreen : AppTheme.greyLight.op(0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : AppTheme.darkBlue)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PAGE ROUTAGE / SUIVI
// ════════════════════════════════════════════════════════════════════════════

class _RFilter {
  final String key, label;
  final Color color;
  const _RFilter(this.key, this.label, this.color);
}

const List<_RFilter> _routingFilters = [
  _RFilter('pending', 'En attente', AppTheme.warning),
  _RFilter('routed', 'Routés', AppTheme.info),
  _RFilter('in_progress', 'En cours', AppTheme.purple),
  _RFilter('resolved', 'Résolus', AppTheme.success),
  _RFilter('all', 'Tous', AppTheme.greyMedium),
];

class _AdminRoutingPage extends StatelessWidget {
  const _AdminRoutingPage();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminDashboardController>();
    return Column(children: [
      SectionHeader(
        title: 'Gestion des Signalements',
        height: 78,
        leading: const Icon(Icons.assignment_outlined, color: Colors.white, size: 22),
        trailing: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: ctrl.loadReports,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints()),
      ),
      _FilterBar(filters: _routingFilters, ctrl: ctrl),
      Expanded(
        child: Obx(() {
          if (ctrl.isLoadingReports.value) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen));
          }
          final list = ctrl.filteredReports;
          if (list.isEmpty) return _EmptyRoutingState(filter: ctrl.routingFilter.value);
          final auths = ctrl.authorities.toList();
          final loadingAuth = ctrl.isLoadingAuth.value;
          return RefreshIndicator(
            onRefresh: ctrl.loadReports,
            color: AppTheme.primaryGreen,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) => _RoutingCard(
                report: list[i],
                ctrl: ctrl,
                authorities: auths,
                isLoadingAuth: loadingAuth,
              ),
            ),
          );
        }),
      ),
    ]);
  }
}

class _MairieSupervisionPage extends StatelessWidget {
  const _MairieSupervisionPage();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminDashboardController>();
    return Column(children: [
      SectionHeader(
        title: 'Suivi des Signalements',
        height: 78,
        leading: const Icon(Icons.visibility, color: Colors.white, size: 22),
        trailing: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: ctrl.loadReports,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints()),
      ),
      _FilterBar(filters: _routingFilters, ctrl: ctrl),
      Expanded(
        child: Obx(() {
          if (ctrl.isLoadingReports.value) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen));
          }
          final list = ctrl.filteredReports;
          if (list.isEmpty) return _EmptyRoutingState(filter: ctrl.routingFilter.value);
          return RefreshIndicator(
            onRefresh: ctrl.loadReports,
            color: AppTheme.primaryGreen,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) => _ReportMiniCard(report: list[i]),
            ),
          );
        }),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  ONGLET ACTUALITÉS MAIRIE
// ════════════════════════════════════════════════════════════════════════════

class _MairieNewsTab extends StatelessWidget {
  const _MairieNewsTab();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminDashboardController>();

    return RefreshIndicator(
      onRefresh: ctrl.loadReports,
      color: AppTheme.primaryGreen,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Actualités — Impact en images',
              height: 78,
              leading: const Icon(Icons.newspaper, color: Colors.white, size: 22),
              trailing: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  onPressed: ctrl.loadReports,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints()),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Obx(() => Row(children: [
                Expanded(
                    child: StatTile(
                        value: '${ctrl.totalResolved}',
                        label: 'Résolus',
                        color: AppTheme.success,
                        icon: Icons.check_circle_outline)),
                const SizedBox(width: 10),
                Expanded(
                    child: StatTile(
                        value: '${ctrl.resolvedThisWeek}',
                        label: 'Cette semaine',
                        color: AppTheme.primaryGreen,
                        icon: Icons.trending_up_rounded)),
              ])),
            ),
          ),
          Obx(() {
            if (ctrl.isLoadingReports.value && ctrl.reports.isEmpty) {
              return const SliverFillRemaining(
                  child: Center(
                      child: CircularProgressIndicator(color: AppTheme.primaryGreen)));
            }
            final grouped = ctrl.groupedNews;
            if (grouped.isEmpty) {
              return const SliverFillRemaining(
                  child: _EmptyState(
                    icon: Icons.photo_library_outlined,
                    message:
                    "Pas encore de succès à afficher.\nDès qu'un signalement sera résolu, il apparaîtra ici.",
                  ));
            }
            final myRegion = ctrl.mairieZone.value;
            final zones = grouped.keys.toList()
              ..sort((a, b) {
                final aM = myRegion.isNotEmpty && a.contains(myRegion);
                final bM = myRegion.isNotEmpty && b.contains(myRegion);
                if (aM && !bM) return -1;
                if (!aM && bM) return 1;
                return a.compareTo(b);
              });

            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    for (final zone in zones) ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 6),
                        child: Row(children: [
                          Icon(Icons.location_city_rounded,
                              size: 15,
                              color: (myRegion.isNotEmpty && zone.contains(myRegion))
                                  ? AppTheme.primaryGreen
                                  : AppTheme.greyMedium),
                          const SizedBox(width: 6),
                          Text(zone, style: AppTheme.h3),
                        ]),
                      ),
                      for (final e in grouped[zone]!.entries)
                        _NewsAuthorityBlock(authority: e.key, items: e.value),
                      const SizedBox(height: 8),
                    ],
                  ])),
            );
          }),
        ],
      ),
    );
  }
}

class _NewsAuthorityBlock extends StatelessWidget {
  final String authority;
  final List<AdminNewsEntry> items;
  const _NewsAuthorityBlock({required this.authority, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_outlined, size: 12, color: AppTheme.greyMedium),
          const SizedBox(width: 5),
          Text(authority,
              style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.greyMedium)),
        ]),
        const SizedBox(height: 8),
        ...items.map((item) => _NewsCard(item: item)),
      ]),
    );
  }
}

class _NewsCard extends StatelessWidget {
  final AdminNewsEntry item;
  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final photo = item.hasAfterPhoto ? item.afterPhotoUrl : item.beforePhotoUrl;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.cardShadow()),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: photo.isNotEmpty
              ? Image.network(photo,
              width: 54,
              height: 54,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(width: 54, height: 54, color: AppTheme.greyLight))
              : Container(
              width: 54,
              height: 54,
              color: AppTheme.greyLight,
              child: const Icon(Icons.image_outlined,
                  color: AppTheme.greyMedium, size: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.title, style: AppTheme.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Text('${item.communeName} · ${item.category}',
                  style: AppTheme.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
            ])),
        const SizedBox(width: 8),
        const StatusPill(label: 'Résolu', color: AppTheme.success),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PAGE AGENTS
// ════════════════════════════════════════════════════════════════════════════

class _AdminAgentsPage extends StatelessWidget {
  const _AdminAgentsPage();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminDashboardController>();
    return Column(children: [
      const SectionHeader(title: 'Performance Agents', height: 78),
      Expanded(child: Obx(() {
        final agents = ctrl.agents;
        if (ctrl.isLoading && agents.isEmpty) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen));
        }
        if (agents.isEmpty) {
          return const _EmptyState(
              icon: Icons.support_agent, message: 'Aucun agent enregistré');
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: agents.length,
          itemBuilder: (_, i) => _AgentCard(agent: agents[i], rank: i + 1),
        );
      })),
    ]);
  }
}

class _AgentPodium extends StatelessWidget {
  final List<AdminAgentPerformanceModel> agents;
  const _AgentPodium({required this.agents});

  @override
  Widget build(BuildContext context) {
    final top = agents.take(5).toList();
    const medals = ['🥇', '🥈', '🥉'];
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.cardShadow()),
      child: Column(
        children: top.asMap().entries.map((e) {
          final i = e.key;
          final a = e.value;
          final isLast = i == top.length - 1;
          final rc = a.resolutionRate >= 80
              ? AppTheme.success
              : a.resolutionRate >= 50
              ? AppTheme.warning
              : AppTheme.coral;
          return Column(children: [
            ListTile(
              leading: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                      color: i == 0
                          ? AppTheme.yellow.op(0.15)
                          : AppTheme.greyLight.op(0.5),
                      shape: BoxShape.circle),
                  child: Center(
                      child: Text(i < 3 ? medals[i] : '${i + 1}',
                          style: TextStyle(fontSize: i < 3 ? 14 : 11)))),
              title: Text(a.name, style: AppTheme.h3),
              subtitle: Text('${a.totalAssigned} ass. · ${a.totalResolved} rés.',
                  style: AppTheme.caption),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: rc.op(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('${a.resolutionRate.round()}%',
                    style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: rc)),
              ),
            ),
            if (!isLast)
              Divider(height: 1, color: AppTheme.greyLight.op(0.7), indent: 52),
          ]);
        }).toList(),
      ),
    );
  }
}

class _AgentCard extends StatelessWidget {
  final AdminAgentPerformanceModel agent;
  final int rank;
  const _AgentCard({required this.agent, required this.rank});

  @override
  Widget build(BuildContext context) {
    final rate = agent.resolutionRate;
    final rc = rate >= 80
        ? AppTheme.success
        : rate >= 50
        ? AppTheme.warning
        : AppTheme.coral;
    const medals = ['🥇', '🥈', '🥉'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: rank == 1
            ? Border.all(color: AppTheme.yellow.op(0.5), width: 1.5)
            : Border.all(color: AppTheme.greyLight.op(0.8)),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                color: rank <= 3 ? AppTheme.yellow.op(0.1) : AppTheme.greyLight.op(0.5),
                shape: BoxShape.circle),
            child: Center(
                child: Text(rank <= 3 ? medals[rank - 1] : '$rank',
                    style: TextStyle(
                        fontSize: rank <= 3 ? 20 : 15, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(agent.name, style: AppTheme.h3),
                Text('${agent.totalAssigned} assigné · ${agent.totalResolved} résolu',
                    style: AppTheme.caption),
              ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration:
            BoxDecoration(color: rc.op(0.1), borderRadius: BorderRadius.circular(12)),
            child: Text('${rate.round()}%',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: rc)),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (rate / 100).clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            backgroundColor: rc.op(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(rc),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PAGE UTILISATEURS
// ════════════════════════════════════════════════════════════════════════════

class _AdminUsersPage extends StatelessWidget {
  const _AdminUsersPage();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminDashboardController>();
    return Column(children: [
      const SectionHeader(title: 'Utilisateurs', height: 78),
      Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Obx(() {
              final ov = ctrl.overview;
              return Column(children: [
                _UsersRow(overview: ov),
                const SizedBox(height: 20),
                if (ov != null && ov.totalUsers > 0) _UserDonut(overview: ov),
              ]);
            }),
          )),
    ]);
  }
}

class _UserDonut extends StatelessWidget {
  final AdminOverviewModel overview;
  const _UserDonut({required this.overview});

  @override
  Widget build(BuildContext context) {
    final total = overview.totalUsers == 0 ? 1 : overview.totalUsers;
    final items = [
      _Seg('Citoyens', overview.totalCitizens, AppTheme.primaryGreen),
      _Seg('Agents', overview.totalAgents, AppTheme.info),
      _Seg('Admins', total - overview.totalCitizens - overview.totalAgents,
          AppTheme.purple),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.cardShadow()),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Répartition', style: AppTheme.h3),
        const SizedBox(height: 12),
        SizedBox(
            height: 130,
            child: PieChart(PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 38,
              sections: items
                  .where((s) => s.count > 0)
                  .map((s) => PieChartSectionData(
                value: s.count.toDouble(),
                color: s.color,
                title: '${(s.count / total * 100).round()}%',
                radius: 30,
                titleStyle: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ))
                  .toList(),
            ))),
        const SizedBox(height: 12),
        ...items.map((s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(s.label, style: AppTheme.body)),
            Text('${s.count}',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.bold,
                    color: s.color,
                    fontSize: 12)),
          ]),
        )),
      ]),
    );
  }
}

class _Seg {
  final String label;
  final int count;
  final Color color;
  const _Seg(this.label, this.count, this.color);
}

// ════════════════════════════════════════════════════════════════════════════
//  PARAMÈTRES
// ════════════════════════════════════════════════════════════════════════════

class _AdminSettingsPage extends StatelessWidget {
  const _AdminSettingsPage();

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final ctrl = Get.find<AdminDashboardController>();
    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        child: Column(children: [
          SizedBox(
            height: 224 + topInset,
            child: Stack(children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppTheme.radiusXl),
                    bottomRight: Radius.circular(AppTheme.radiusXl)),
                child: SizedBox.expand(
                    child: Container(
                        decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
                        child: const SenegalPatternBackground())),
              ),
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(AppTheme.radiusXl),
                      bottomRight: Radius.circular(AppTheme.radiusXl)),
                  child: FlagStripe(),
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, topInset + 16, 20, 28),
                  child: Obx(() {
                    final isMairie = ctrl.isMairie.value;
                    final roleLabel = isMairie ? 'Mairie' : 'Administrateur Système';
                    final iconData =
                    isMairie ? Icons.account_balance : Icons.admin_panel_settings;
                    final displayName = isMairie
                        ? _str(ctrl.mairieName.value, _str(auth.userName.value, 'Mairie'))
                        : _str(auth.userName.value, 'Administrateur');
                    return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.op(0.15),
                                border: Border.all(
                                    color: AppTheme.yellow.op(0.6), width: 2.5)),
                            child: Icon(iconData, color: Colors.white, size: 38),
                          ),
                          const SizedBox(height: 12),
                          Text(displayName,
                              style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                            padding:
                            const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                                color: AppTheme.yellow.op(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: AppTheme.yellow.op(0.4))),
                            child: Text(roleLabel,
                                style: const TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    color: AppTheme.yellow,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ]);
                  }),
                ),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _SettingsSection(title: 'MON COMPTE', items: [
                _SettingsItem(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    trailing: Obx(() =>
                        Text(_str(auth.userEmail.value), style: AppTheme.caption))),
                _SettingsItem(
                    icon: Icons.shield_outlined,
                    label: 'Rôle',
                    trailing: Obx(() => Text(
                        ctrl.isMairie.value ? 'Mairie' : 'Administrateur Système',
                        style: AppTheme.caption))),
              ]),
              const SizedBox(height: 12),
              _SettingsSection(title: 'SÉCURITÉ', items: [
                _SettingsItem(
                    icon: Icons.lock_outline,
                    label: 'Changer le mot de passe',
                    isAction: true,
                    onTap: () {}),
                _SettingsItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    isAction: true,
                    onTap: () => Get.to(() => const MairieNotificationsScreen())),
              ]),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  final ok = await Get.dialog<bool>(AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
                    title: const Text('Déconnexion', style: AppTheme.h3),
                    content: const Text('Voulez-vous vraiment vous déconnecter ?',
                        style: AppTheme.body),
                    actions: [
                      TextButton(
                          onPressed: () => Get.back(result: false),
                          child: const Text('Annuler')),
                      ElevatedButton(
                          onPressed: () => Get.back(result: true),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.coral,
                              foregroundColor: Colors.white),
                          child: const Text('Déconnecter')),
                    ],
                  ));
                  if (ok == true) {
                    await AuthService.instance.logout();
                    Get.offAllNamed(Routes.SPLASH);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.coral.op(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.coral.op(0.4), width: 1.5),
                  ),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.logout_rounded, color: AppTheme.coral, size: 20),
                    SizedBox(width: 8),
                    Text('Se déconnecter',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.coral)),
                  ]),
                ),
              ),
              const SizedBox(height: 40),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  NOTIFICATIONS
// ════════════════════════════════════════════════════════════════════════════

class MairieNotificationsController extends GetxController {
  final ApiService _api = Get.find<ApiService>();
  final isLoading = true.obs;
  final items = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final resp = await _api.get('/notifications');
      if (resp.success && resp.data != null) {
        final raw = resp.data;
        final dynamic list = raw is List ? raw : (raw is Map ? raw['data'] : null);
        if (list is List) {
          items.assignAll(list
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList());
        }
      }
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      await _api.post('/notifications/$id/mark-as-read', data: {});
      final idx = items.indexWhere((n) => n['id'] == id);
      if (idx != -1) {
        items[idx] = {...items[idx], 'read_at': DateTime.now().toIso8601String()};
        items.refresh();
      }
      if (Get.isRegistered<AdminDashboardController>()) {
        final c = Get.find<AdminDashboardController>();
        if (c.unreadNotifications.value > 0) c.unreadNotifications.value--;
      }
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    try {
      await _api.post('/notifications/mark-all-as-read', data: {});
      await load();
      if (Get.isRegistered<AdminDashboardController>()) {
        Get.find<AdminDashboardController>().unreadNotifications.value = 0;
      }
    } catch (_) {}
  }
}

class MairieNotificationsScreen extends StatelessWidget {
  const MairieNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(MairieNotificationsController());
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(children: [
        SectionHeader(
          title: 'Notifications',
          height: 78,
          leading: const Icon(Icons.notifications, color: Colors.white, size: 22),
          trailing: IconButton(
              icon: const Icon(Icons.done_all_rounded, color: Colors.white70),
              onPressed: ctrl.markAllAsRead),
        ),
        Expanded(child: Obx(() {
          if (ctrl.isLoading.value) {
            return const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen));
          }
          if (ctrl.items.isEmpty) {
            return const _EmptyState(
                icon: Icons.notifications_none_rounded,
                message: 'Aucune notification pour le moment');
          }
          return RefreshIndicator(
            onRefresh: ctrl.load,
            color: AppTheme.primaryGreen,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: ctrl.items.length,
              itemBuilder: (_, i) {
                final n = ctrl.items[i];
                final isRead = n['read_at'] != null;
                final title = _str(n['title'], 'Notification');
                final body = _str(n['body'] ?? n['message']);
                final id = _asInt(n['id']);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isRead ? Colors.white : AppTheme.primaryGreen.op(0.06),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                        color: isRead
                            ? AppTheme.greyLight.op(0.7)
                            : AppTheme.primaryGreen.op(0.3)),
                    boxShadow: AppTheme.cardShadow(),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    onTap: id == null ? null : () => ctrl.markAsRead(id),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        if (!isRead)
                          Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 5, right: 8),
                              decoration: const BoxDecoration(
                                  color: AppTheme.primaryGreen, shape: BoxShape.circle)),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: AppTheme.h3),
                                  if (body.isNotEmpty) ...[
                                    const SizedBox(height: 3),
                                    Text(body, style: AppTheme.caption)
                                  ],
                                ])),
                      ]),
                    ),
                  ),
                );
              },
            ),
          );
        })),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  WIDGETS PARTAGÉS
// ════════════════════════════════════════════════════════════════════════════

class _DashSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  const _DashSectionTitle({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 17, color: AppTheme.primaryGreen),
      const SizedBox(width: 7),
      Text(title, style: AppTheme.h2),
    ]);
  }
}

class _KpiItem {
  final String value, label;
  final IconData icon;
  final Color color;
  const _KpiItem(this.value, this.label, this.icon, this.color);
}

class _KpiRow extends StatelessWidget {
  final List<_KpiItem> items;
  const _KpiRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.ctaGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.elevatedShadow(AppTheme.primaryGreen),
      ),
      child: Row(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          final item = e.value;
          return Expanded(
              child: Row(children: [
                Expanded(
                    child: Column(children: [
                      Icon(item.icon, color: item.color, size: 18),
                      const SizedBox(height: 5),
                      Text(item.value,
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: item.color,
                              fontSize: 22,
                              fontWeight: FontWeight.bold)),
                      Text(item.label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: Colors.white70,
                              fontSize: 9,
                              height: 1.3)),
                    ])),
                if (!isLast)
                  Container(
                      width: 1,
                      height: 40,
                      color: Colors.white.op(0.25),
                      margin: const EdgeInsets.symmetric(horizontal: 4)),
              ]));
        }).toList(),
      ),
    );
  }
}

class _MairieStatsGrid extends StatelessWidget {
  final int total, pending, routed, resolved;
  const _MairieStatsGrid(
      {required this.total,
        required this.pending,
        required this.routed,
        required this.resolved});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(
            child: StatTile(
                label: 'Total reçus',
                value: '$total',
                icon: Icons.assignment_outlined,
                color: AppTheme.primaryGreen)),
        const SizedBox(width: 12),
        Expanded(
            child: StatTile(
                label: 'En attente',
                value: '$pending',
                icon: Icons.pending_outlined,
                color: AppTheme.warning)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: StatTile(
                label: 'Routés',
                value: '$routed',
                icon: Icons.route_outlined,
                color: AppTheme.info)),
        const SizedBox(width: 12),
        Expanded(
            child: StatTile(
                label: 'Résolus',
                value: '$resolved',
                icon: Icons.check_circle_outline,
                color: AppTheme.success)),
      ]),
    ]);
  }
}

class _UsersRow extends StatelessWidget {
  final AdminOverviewModel? overview;
  const _UsersRow({this.overview});

  @override
  Widget build(BuildContext context) {
    final o = overview;
    return Row(children: [
      Expanded(
          child: StatTile(
              label: 'Total',
              value: '${o?.totalUsers ?? 0}',
              icon: Icons.people_outline,
              color: AppTheme.darkBlue)),
      const SizedBox(width: 10),
      Expanded(
          child: StatTile(
              label: 'Citoyens',
              value: '${o?.totalCitizens ?? 0}',
              icon: Icons.person_outline,
              color: AppTheme.primaryGreen)),
      const SizedBox(width: 10),
      Expanded(
          child: StatTile(
              label: 'Agents',
              value: '${o?.totalAgents ?? 0}',
              icon: Icons.support_agent_outlined,
              color: AppTheme.info)),
    ]);
  }
}

class _StatusBreakdownCard extends StatelessWidget {
  /// Objet API (pending, routed, inProgress, resolved, total) ou null.
  final dynamic byStatus;
  final Map<String, int> localCounts;
  const _StatusBreakdownCard({this.byStatus, required this.localCounts});

  @override
  Widget build(BuildContext context) {
    final pending = _asInt(byStatus?.pending) ?? localCounts['pending'] ?? 0;
    final routed = _asInt(byStatus?.routed) ?? localCounts['routed'] ?? 0;
    final inProgress = _asInt(byStatus?.inProgress) ?? localCounts['in_progress'] ?? 0;
    final resolved = _asInt(byStatus?.resolved) ?? localCounts['resolved'] ?? 0;
    final total =
        _asInt(byStatus?.total) ?? (pending + routed + inProgress + resolved);
    final safeTotal = total == 0 ? 1 : total;

    final items = [
      _StatusSegment('En attente', pending, AppTheme.warning),
      _StatusSegment('Routés', routed, AppTheme.info),
      _StatusSegment('En cours', inProgress, AppTheme.purple),
      _StatusSegment('Résolus', resolved, AppTheme.success),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.cardShadow()),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Répartition', style: AppTheme.h3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: AppTheme.primaryGreen.op(0.08),
                borderRadius: BorderRadius.circular(10)),
            child: Text('$total total',
                style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.primaryGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
          ),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: SizedBox(
              height: 10,
              child: Row(
                children: items
                    .map((item) => Expanded(
                    flex: item.count > 0 ? item.count : 1,
                    child: Container(
                        color: item.count > 0 ? item.color : AppTheme.greyLight)))
                    .toList(),
              )),
        ),
        const SizedBox(height: 14),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(item.label, style: AppTheme.body)),
            Text('${item.count}',
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.bold,
                    color: item.color,
                    fontSize: 12)),
            const SizedBox(width: 8),
            SizedBox(
                width: 36,
                child: Text('${((item.count / safeTotal) * 100).round()}%',
                    style: AppTheme.caption, textAlign: TextAlign.right)),
          ]),
        )),
      ]),
    );
  }
}

class _StatusSegment {
  final String label;
  final int count;
  final Color color;
  const _StatusSegment(this.label, this.count, this.color);
}

class _SeverityCards extends StatelessWidget {
  final int low, medium, high;
  const _SeverityCards({required this.low, required this.medium, required this.high});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: _SevCard('Faible', low, AppTheme.success, Icons.arrow_downward)),
      const SizedBox(width: 10),
      Expanded(child: _SevCard('Moyen', medium, AppTheme.warning, Icons.remove)),
      const SizedBox(width: 10),
      Expanded(child: _SevCard('Élevé', high, AppTheme.coral, Icons.priority_high)),
    ]);
  }
}

class _SevCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _SevCard(this.label, this.count, this.color, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.op(0.3), width: 1.5),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(children: [
        Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(color: color.op(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 16)),
        const SizedBox(height: 6),
        Text('$count',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color)),
        Text(label, style: AppTheme.caption),
      ]),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final List<_RFilter> filters;
  final AdminDashboardController ctrl;
  const _FilterBar({required this.filters, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final active = ctrl.routingFilter.value;
      final totalCount = ctrl.reports.length;
      return Container(
        height: 52,
        color: AppTheme.darkGreen,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final f = filters[i];
            final sel = active == f.key;
            final count = f.key == 'all' ? totalCount : ctrl.countByStatus(f.key);

            return GestureDetector(
              onTap: () => ctrl.routingFilter.value = f.key,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: sel ? Colors.white : Colors.white.op(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(f.label,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: sel ? AppTheme.darkGreen : Colors.white)),
                  const SizedBox(width: 5),
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: sel ? f.color.op(0.15) : Colors.white.op(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$count',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: sel ? f.color : Colors.white)),
                  ),
                ]),
              ),
            );
          },
        ),
      );
    });
  }
}

class _PendingBanner extends StatelessWidget {
  final int count;
  final VoidCallback onTap;
  const _PendingBanner({required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.warning.op(0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.warning.op(0.4), width: 1.5),
        ),
        child: Row(children: [
          Container(
              padding: const EdgeInsets.all(10),
              decoration:
              BoxDecoration(color: AppTheme.warning.op(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.pending_actions, color: AppTheme.warning, size: 22)),
          const SizedBox(width: 14),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('$count signalement${count > 1 ? 's' : ''} en attente',
                    style: AppTheme.h3),
                const Text('Toucher pour router', style: AppTheme.caption),
              ])),
          const Icon(Icons.arrow_forward_ios, color: AppTheme.warning, size: 14),
        ]),
      ),
    );
  }
}

class _NotifBell extends StatelessWidget {
  final int count;
  const _NotifBell({required this.count});

  @override
  Widget build(BuildContext context) {
    return Stack(clipBehavior: Clip.none, children: [
      Material(
        color: Colors.white.op(0.16),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Get.to(() => const MairieNotificationsScreen()),
          child: const Padding(
              padding: EdgeInsets.all(9),
              child: Icon(Icons.notifications_outlined, color: Colors.white, size: 20)),
        ),
      ),
      if (count > 0)
        Positioned(
            top: -3,
            right: -3,
            child: Container(
              padding: const EdgeInsets.all(3),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration:
              const BoxDecoration(color: AppTheme.coral, shape: BoxShape.circle),
              child: Center(
                  child: Text(count > 9 ? '9+' : '$count',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
            )),
    ]);
  }
}

class _ReportMiniCard extends StatelessWidget {
  final Map<String, dynamic> report;
  const _ReportMiniCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final status = _str(report['status'], 'pending');
    final severity = _str(report['severity'], 'low');
    final title = _str(report['title'], 'Signalement');
    final commune = _str(report['commune_name']);
    final date = _fmtDate(report['created_at']);
    final statusClr = AdminDashboardController.statusColor(status);
    final sevClr = AdminDashboardController.severityColor(severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.cardShadow()),
      child: Row(children: [
        Container(
            width: 4,
            height: 48,
            decoration:
            BoxDecoration(color: sevClr, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: AppTheme.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 11, color: AppTheme.greyMedium),
                const SizedBox(width: 3),
                Expanded(
                    child: Text(commune,
                        style: AppTheme.caption, maxLines: 1, overflow: TextOverflow.ellipsis)),
                if (date.isNotEmpty) Text(date, style: AppTheme.caption),
              ]),
            ])),
        const SizedBox(width: 8),
        StatusPill(label: AdminDashboardController.statusLabel(status), color: statusClr),
      ]),
    );
  }

  static String _fmtDate(dynamic d) {
    if (d == null) return '';
    try {
      final dt = DateTime.parse(d.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}

class _RoutingCard extends StatelessWidget {
  final Map<String, dynamic> report;
  final AdminDashboardController ctrl;
  final List<Map<String, dynamic>> authorities;
  final bool isLoadingAuth;
  const _RoutingCard(
      {required this.report,
        required this.ctrl,
        required this.authorities,
        required this.isLoadingAuth});

  @override
  Widget build(BuildContext context) {
    final status = _str(report['status'], 'pending');
    final severity = _str(report['severity'], 'low');
    final isPending = status == 'pending' || status == 'acknowledged';
    final statusClr = AdminDashboardController.statusColor(status);
    final sevClr = AdminDashboardController.severityColor(severity);
    final title = _str(report['title'], 'Sans titre');
    final commune = _str(report['commune_name']);
    final reference = _str(report['reference']);
    final catName = _categoryName(report['category'], 'Inconnue');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: isPending
            ? Border.all(color: AppTheme.warning.op(0.5), width: 1.5)
            : Border.all(color: AppTheme.greyLight.op(0.8)),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                width: 4,
                height: 60,
                decoration:
                BoxDecoration(color: sevClr, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                        child: Text(title,
                            style: AppTheme.h3, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    StatusPill(
                        label: AdminDashboardController.statusLabel(status), color: statusClr),
                  ]),
                  const SizedBox(height: 5),
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.greyMedium),
                    const SizedBox(width: 3),
                    Expanded(
                        child: Text(
                          commune.isNotEmpty ? '$commune · $reference' : reference,
                          style: AppTheme.caption,
                          overflow: TextOverflow.ellipsis,
                        )),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.label_outline, size: 12, color: AppTheme.greyMedium),
                    const SizedBox(width: 3),
                    Expanded(
                        child: Text(catName,
                            style: AppTheme.caption, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: sevClr.op(0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(AdminDashboardController.severityLabel(severity),
                          style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: sevClr)),
                    ),
                  ]),
                ])),
          ]),
        ),
        if (isPending) ...[
          Container(
              height: 1,
              color: AppTheme.warning.op(0.15),
              margin: const EdgeInsets.symmetric(horizontal: 14)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                        color: AppTheme.warning.op(0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.route, size: 14, color: AppTheme.warning)),
                const SizedBox(width: 7),
                const Text('Choisir une autorité', style: AppTheme.h3),
              ]),
              const SizedBox(height: 8),
              if (isLoadingAuth)
                const SizedBox(
                    height: 32,
                    child: Center(
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppTheme.primaryGreen))))
              else if (authorities.isEmpty)
                const Text('Aucune autorité chargée', style: AppTheme.caption)
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: authorities.map((auth) {
                    final isRec = auth['recommended'] == true;
                    return GestureDetector(
                      onTap: () => _confirmRoute(report, auth, ctrl),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.op(isRec ? 0.1 : 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.primaryGreen.op(isRec ? 0.5 : 0.25),
                            width: isRec ? 1.5 : 1,
                          ),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.account_balance,
                              size: 12, color: AppTheme.primaryGreen),
                          const SizedBox(width: 5),
                          Text(_str(auth['name']),
                              style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryGreen)),
                          if (isRec) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding:
                              const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                  color: AppTheme.success,
                                  borderRadius: BorderRadius.circular(4)),
                              child: const Text('✓',
                                  style: TextStyle(color: Colors.white, fontSize: 8)),
                            ),
                          ],
                        ]),
                      ),
                    );
                  }).toList(),
                ),
            ]),
          ),
        ] else ...[
          Container(
              height: 1,
              color: AppTheme.greyLight.op(0.5),
              margin: const EdgeInsets.symmetric(horizontal: 14)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(children: [
              Icon(status == 'resolved' ? Icons.check_circle : Icons.schedule,
                  size: 13, color: statusClr),
              const SizedBox(width: 5),
              Text(AdminDashboardController.statusLabel(status),
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: statusClr,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(_fmtDate(report['created_at']), style: AppTheme.caption),
            ]),
          ),
        ],
      ]),
    );
  }

  void _confirmRoute(Map<String, dynamic> report, Map<String, dynamic> auth,
      AdminDashboardController ctrl) {
    final authName = _str(auth['name']);
    final reportTitle = _str(report['title'], 'Ce signalement');
    final reportId = _asInt(report['id']);
    final authId = _asInt(auth['id']);

    Get.dialog(Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.op(0.08),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.route, color: AppTheme.primaryGreen, size: 20)),
            const SizedBox(width: 10),
            const Text('Confirmer le routage', style: AppTheme.h2),
          ]),
          const SizedBox(height: 14),
          Text(reportTitle, style: AppTheme.h3, maxLines: 2),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppTheme.warning.op(0.08), borderRadius: BorderRadius.circular(10)),
                  child: const Column(children: [
                    Icon(Icons.pending_actions, color: AppTheme.warning, size: 18),
                    SizedBox(height: 4),
                    Text('En attente',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 10,
                            color: AppTheme.warning,
                            fontWeight: FontWeight.w600)),
                  ]),
                )),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.arrow_forward, color: AppTheme.primaryGreen, size: 22)),
            Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.op(0.08),
                      borderRadius: BorderRadius.circular(10)),
                  child: Column(children: [
                    const Icon(Icons.account_balance, color: AppTheme.primaryGreen, size: 18),
                    const SizedBox(height: 4),
                    Text(authName,
                        style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 10,
                            color: AppTheme.primaryGreen,
                            fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ]),
                )),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(
                child: OutlinedButton(
                  onPressed: () => Get.back(),
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppTheme.greyLight),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd))),
                  child: const Text('Annuler'),
                )),
            const SizedBox(width: 10),
            Expanded(
                child: ElevatedButton(
                  onPressed: (reportId == null || authId == null)
                      ? null
                      : () {
                    Get.back();
                    ctrl.routeReport(
                        reportId: reportId,
                        authorityId: authId,
                        authorityName: authName);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd))),
                  child: const Text('Router'),
                )),
          ]),
        ]),
      ),
    ));
  }

  static String _fmtDate(dynamic d) {
    if (d == null) return '';
    try {
      final dt = DateTime.parse(d.toString()).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

// ── États vides ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 64, color: AppTheme.greyLight),
            const SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.greyMedium,
                    fontSize: 14,
                    height: 1.5)),
          ]),
        ));
  }
}

class _EmptyRoutingState extends StatelessWidget {
  final String filter;
  const _EmptyRoutingState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
              padding: const EdgeInsets.all(20),
              decoration:
              BoxDecoration(color: AppTheme.success.op(0.08), shape: BoxShape.circle),
              child: Icon(Icons.check_circle_outline,
                  size: 52, color: AppTheme.success.op(0.5))),
          const SizedBox(height: 14),
          Text(filter == 'pending' ? 'Aucun signalement en attente ✅' : 'Aucun signalement ici',
              style: AppTheme.h3),
          const SizedBox(height: 6),
          Text(
              filter == 'pending'
                  ? 'Tous les signalements ont été routés'
                  : "Changez le filtre pour voir d'autres",
              style: AppTheme.caption),
        ]));
  }
}

// ── Paramètres — helpers ──────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;
  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: AppTheme.label)),
      Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.cardShadow()),
        child: Column(
          children: items.asMap().entries.map((e) {
            final isLast = e.key == items.length - 1;
            return Column(children: [
              e.value,
              if (!isLast)
                Divider(height: 1, color: AppTheme.greyLight.op(0.7), indent: 52),
            ]);
          }).toList(),
        ),
      ),
    ]);
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final bool isAction;
  final VoidCallback? onTap;
  const _SettingsItem(
      {required this.icon,
        required this.label,
        this.trailing,
        this.isAction = false,
        this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: AppTheme.primaryGreen.op(0.08), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppTheme.primaryGreen, size: 18)),
      title: Text(label,
          style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.darkBlue)),
      trailing: trailing ??
          (isAction
              ? const Icon(Icons.chevron_right, color: AppTheme.greyMedium, size: 18)
              : null),
    );
  }
}