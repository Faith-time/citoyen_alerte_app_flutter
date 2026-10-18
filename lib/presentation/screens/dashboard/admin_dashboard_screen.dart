import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/services/dashboard_service.dart';
import 'package:citoyen_alerte_app_backup/core/services/auth_service.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/core/theme/neo_kit.dart';
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
  if (cat is String && cat.isNotEmpty) return cat;
  return fallback;
}

String _firstPhoto(dynamic report, List<String> keys) {
  for (final k in keys) {
    final v = report[k];
    if (v is String && v.isNotEmpty) return v;
  }
  return '';
}

String _reportCategory(Map<String, dynamic> r, [String fallback = 'Autre']) {
  final fromCat = _categoryName(r['category'], '');
  if (fromCat.isNotEmpty) return fromCat;
  return _str(r['category_name'], fallback);
}

DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s)?.toLocal();
}

DateTime? _reportDate(Map<String, dynamic> r) =>
    _parseDate(r['created_at']) ??
        _parseDate(r['reported_at']) ??
        _parseDate(r['updated_at']);

String _normSeverity(dynamic v) {
  final s = _str(v).toLowerCase();
  if (const ['high', 'critical', 'urgent', 'élevé', 'eleve'].contains(s)) return 'high';
  if (const ['medium', 'moderate', 'moyen'].contains(s)) return 'medium';
  return 'low';
}

String _normStatus(dynamic v) {
  final s = _str(v).toLowerCase();
  switch (s) {
    case 'pending':
    case 'acknowledged':
      return 'pending';
    case 'routed':
      return 'routed';
    case 'in_progress':
    case 'in-progress':
    case 'assigned':
      return 'in_progress';
    case 'resolved':
    case 'closed':
      return 'resolved';
    default:
      return s;
  }
}

/// Extrait une liste d'une réponse API (liste, {data: [...]}, paginator imbriqué).
List _extractList(dynamic raw) {
  if (raw is List) return raw;
  if (raw is Map) {
    return _extractList(raw['data'] ?? raw['items'] ?? raw['reports']);
  }
  return const [];
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
      category: _reportCategory(r),      zone: _str(r['region'], commune.isNotEmpty ? commune : 'Autres zones'),
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
//  CONTROLLER — logique inchangée
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

  final chartPeriod = 'all'.obs; // "Tout" par défaut : plus de graphiques vides
  static const Map<String, String> chartPeriods = {
    'day': '24h',
    'week': '7j',
    'month': '30j',
    'year': '1an',
    'all': 'Tout',
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
  DateTime? get _chartStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    switch (chartPeriod.value) {
      case 'day':
        return DateTime(now.year, now.month, now.day, now.hour)
            .subtract(const Duration(hours: 23));
      case 'week':
        return today.subtract(const Duration(days: 6));
      case 'month':
        return today.subtract(const Duration(days: 29));
      case 'year':
        return DateTime(now.year, now.month - 11, 1);
      default:
        return null;
    }
  }

  List<Map<String, dynamic>> get chartReports {
    final start = _chartStart;
    final cat = selectedCategory.value;
    return reports.where((r) {
      if (start != null) {
        final dt = _reportDate(r);
        if (dt == null || dt.isBefore(start)) return false;
      }
      if (cat.isEmpty) return true;
      return _reportCategory(r, '') == cat;
    }).toList();
  }

  /// 5 derniers signalements (les plus récents d'abord).
  List<Map<String, dynamic>> get recentReports {
    final list = chartReports;
    list.sort((a, b) {
      final da = _reportDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = _reportDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    return list.take(5).toList();
  }

  /// L'API admin renvoie des totaux "tout l'historique" : on ne les utilise
  /// que si aucun filtre n'est actif, sinon on calcule en local.
  bool get useApiStats =>
      chartPeriod.value == 'all' && selectedCategory.value.isEmpty;

  Map<String, int> get categoryBreakdown {
    final map = <String, int>{};
    for (final r in chartReports) {
      final name = _reportCategory(r);
      map[name] = (map[name] ?? 0) + 1;
    }
    return map;
  }

  Map<String, int> get severityBreakdown {
    final map = <String, int>{'low': 0, 'medium': 0, 'high': 0};
    for (final r in chartReports) {
      final s = _normSeverity(r['severity']);
      map[s] = (map[s] ?? 0) + 1;
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
      final key = _normStatus(r['status']);
      if (map.containsKey(key)) map[key] = map[key]! + 1;
    }
    return map;
  }

  List<AdminTrendPoint> get trendData {
    final now = DateTime.now();
    final period = chartPeriod.value;
    final list = chartReports;

    // ── 24h : 24 points horaires ──────────────────────────────────────────
    if (period == 'day') {
      final start = _chartStart!;
      final counts = List<int>.filled(24, 0);
      for (final r in list) {
        final dt = _reportDate(r);
        if (dt == null) continue;
        final idx = dt.difference(start).inHours;
        if (idx >= 0 && idx < 24) counts[idx]++;
      }
      return List.generate(
        24,
            (i) => AdminTrendPoint(
          label: '${start.add(Duration(hours: i)).hour}h',
          count: counts[i],
        ),
      );
    }

    // ── 7j / 30j : un point par jour ──────────────────────────────────────
    if (period == 'week' || period == 'month') {
      final days = period == 'week' ? 7 : 30;
      final today = DateTime(now.year, now.month, now.day);
      final start = today.subtract(Duration(days: days - 1));
      final counts = List<int>.filled(days, 0);
      for (final r in list) {
        final dt = _reportDate(r);
        if (dt == null) continue;
        final d = DateTime(dt.year, dt.month, dt.day);
        final idx = (d.difference(start).inHours / 24).round();
        if (idx >= 0 && idx < days) counts[idx]++;
      }
      const joursCourt = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
      return List.generate(days, (i) {
        final d = DateTime(start.year, start.month, start.day + i);
        final label = days <= 7 ? joursCourt[d.weekday - 1] : '${d.day}/${d.month}';
        return AdminTrendPoint(label: label, count: counts[i]);
      });
    }

    // ── 1an : 12 mois ─────────────────────────────────────────────────────
    if (period == 'year') return _monthlyTrend(list, 12);

    // ── Tout : du plus ancien signalement à aujourd'hui (6 à 24 mois) ─────
    DateTime? first;
    for (final r in list) {
      final dt = _reportDate(r);
      if (dt != null && (first == null || dt.isBefore(first))) first = dt;
    }
    final span = first == null
        ? 1
        : (now.year - first.year) * 12 + now.month - first.month + 1;
    return _monthlyTrend(list, span.clamp(6, 24).toInt());
  }

  List<AdminTrendPoint> _monthlyTrend(List<Map<String, dynamic>> list, int n) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - (n - 1), 1);
    final counts = List<int>.filled(n, 0);
    for (final r in list) {
      final dt = _reportDate(r);
      if (dt == null) continue;
      final idx = (dt.year - start.year) * 12 + dt.month - start.month;
      if (idx >= 0 && idx < n) counts[idx]++;
    }
    const mois = ['Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin', 'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'];
    return List.generate(n, (i) {
      final m = DateTime(start.year, start.month + i, 1);
      return AdminTrendPoint(label: mois[m.month - 1], count: counts[i]);
    });
  }

  List<String> get allCategories {
    final cats = <String>{};
    for (final r in reports) {
      final name = _reportCategory(r, '');
      if (name.isNotEmpty) cats.add(name);
    }
    return cats.toList()..sort();
  }

  int countByStatus(String status) {
    if (status == 'pending') {
      return reports
          .where((r) => r['status'] == 'pending' || r['status'] == 'acknowledged')
          .length;
    }
    return reports.where((r) => r['status'] == status).length;
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
        final items = _extractList(resp.data);
        reports.assignAll(items
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList());
        if (reports.isNotEmpty) {
          final r = reports.first;
          debugPrint('[AdminDash] ${reports.length} reports | '
              'created_at=${r['created_at']} | status=${r['status']} | '
              'severity=${r['severity']} | category=${r['category']}');
        }
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
      backgroundColor: Neo.bg,
      body: NeoBackdrop(
        child: Obx(() => IndexedStack(
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
      ),
      bottomNavigationBar: Obx(() {
        final mairie = ctrl.isMairie.value;
        final pending = ctrl.countByStatus('pending');
        return NeoBottomNav(
          index: ctrl.currentIndex.value,
          onChanged: ctrl.changePage,
          items: mairie
              ? const [
            NeoNavItem(Icons.account_balance_outlined, Icons.account_balance, 'Accueil'),
            NeoNavItem(Icons.visibility_outlined, Icons.visibility, 'Suivi'),
            NeoNavItem(Icons.newspaper_outlined, Icons.newspaper, 'Actualités'),
            NeoNavItem(Icons.settings_outlined, Icons.settings, 'Paramètres'),
          ]
              : [
            const NeoNavItem(Icons.dashboard_outlined, Icons.dashboard, 'Accueil'),
            NeoNavItem(Icons.route_outlined, Icons.route, 'Routage', badge: pending),
            const NeoNavItem(Icons.support_agent_outlined, Icons.support_agent, 'Agents'),
            const NeoNavItem(Icons.people_outline, Icons.people, 'Utilisateurs'),
            const NeoNavItem(Icons.settings_outlined, Icons.settings, 'Réglages'),
          ],
        );
      }),
    );
  }
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
        return const NeoLoading();
      }
      return RefreshIndicator(
        onRefresh: ctrl.refresh,
        color: Neo.blue,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: EdgeInsets.zero,
          children: [
            Obx(() => NeoGreetingHeader(
                  greeting: 'Administration,',
                  name: _str(AuthService.instance.userName.value, 'Admin').split(' ').first,
                  notifications: ctrl.unreadNotifications.value,
                  onBell: () => Get.to(() => const MairieNotificationsScreen()),
                )),
            const SizedBox(height: 8),
            Obx(() => NeoChipRow(
                  chips: AdminDashboardController.periods.entries
                      .map((e) => NeoChip(
                            label: e.value,
                            selected: ctrl.selectedPeriod.value == e.key,
                            onTap: () => ctrl.changePeriod(e.key),
                          ))
                      .toList(),
                )),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Obx(() {
                  final n = ctrl.countByStatus('pending');
                  if (n == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _PendingBanner(count: n, onTap: () => ctrl.changePage(1)),
                  );
                }),
                NeoReveal(
                  child: Obx(() {
                    final total = ctrl.reports.length;
                    return NeoStatsStrip(items: [
                      NeoStat('${ctrl.apiTotalReports ?? total}', 'Signalements'),
                      NeoStat('${ctrl.countByStatus('resolved')}', 'Résolus', Neo.success),
                      NeoStat('${ctrl.apiNewUsers}', 'Nouveaux\nutilisateurs', Neo.info),
                    ]);
                  }),
                ),
                const SizedBox(height: 24),
                const NeoSectionTitle('Utilisateurs', icon: Icons.people_outline),
                const SizedBox(height: 12),
                Obx(() => _UsersRow(overview: ctrl.overview)),
                const SizedBox(height: 24),
                const NeoSectionTitle('Tendance des signalements', icon: Icons.show_chart_rounded),
                const SizedBox(height: 10),
                _ChartPeriodSelector(ctrl: ctrl),
                const SizedBox(height: 12),
                Obx(() => _TrendLineChart(points: ctrl.trendData, period: ctrl.chartPeriod.value)),
                const SizedBox(height: 24),
                const NeoSectionTitle('Répartition par statut', icon: Icons.bar_chart_outlined),
                const SizedBox(height: 12),
                Obx(() => _StatusBreakdownCard(
                  byStatus: ctrl.useApiStats ? ctrl.apiReportsByStatus : null,
                  localCounts: ctrl.statusBreakdown,
                )),
                const SizedBox(height: 24),
                Row(children: [
                  const Expanded(child: NeoSectionTitle('Par catégorie', icon: Icons.pie_chart_outline)),
                  _CategoryFilterChip(ctrl: ctrl),
                ]),
                const SizedBox(height: 12),
                Obx(() {
                  final api = ctrl.apiCategoryBreakdown;
                  final useApi = ctrl.useApiStats && api.isNotEmpty;
                  return _CategoryChart(data: useApi ? api : ctrl.categoryBreakdown);
                }),
                const SizedBox(height: 24),
                const NeoSectionTitle('Sévérité', icon: Icons.warning_amber_outlined),
                const SizedBox(height: 12),
                Obx(() {
                  final local = ctrl.severityBreakdown;
                  final useApi = ctrl.useApiStats;
                  return _SeverityCards(
                    low: (useApi ? ctrl.apiSeverity('low') : null) ?? local['low'] ?? 0,
                    medium: (useApi ? ctrl.apiSeverity('medium') : null) ?? local['medium'] ?? 0,
                    high: (useApi ? ctrl.apiSeverity('high') : null) ?? local['high'] ?? 0,
                  );
                }),
                const SizedBox(height: 24),
                Obx(() {
                  final agents = ctrl.agents;
                  if (agents.isEmpty) return const SizedBox.shrink();
                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const NeoSectionTitle('Top agents', icon: Icons.emoji_events_outlined),
                    const SizedBox(height: 12),
                    _AgentPodium(agents: agents),
                  ]);
                }),
              ]),
            ),
          ],
        ),
      );
    });
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
      if (ctrl.isLoadingReports.value && ctrl.reports.isEmpty) return const NeoLoading();
      return RefreshIndicator(
        onRefresh: ctrl.refresh,
        color: Neo.blue,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: EdgeInsets.zero,
          children: [
            Obx(() => NeoGreetingHeader(
                  greeting: ctrl.mairieZone.value.isNotEmpty ? 'Zone : ${ctrl.mairieZone.value}' : 'Suivi des signalements',
                  name: ctrl.mairieName.value.isNotEmpty ? ctrl.mairieName.value : 'Mairie',
                  notifications: ctrl.unreadNotifications.value,
                  onBell: () => Get.to(() => const MairieNotificationsScreen()),
                )),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Obx(() {
                  final n = ctrl.countByStatus('pending');
                  if (n == 0) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _PendingBanner(count: n, onTap: () => ctrl.changePage(1)),
                  );
                }),
                NeoReveal(
                  child: Obx(() => _MairieStatsGrid(
                        total: ctrl.reports.length,
                        pending: ctrl.countByStatus('pending'),
                        routed: ctrl.countByStatus('routed'),
                        resolved: ctrl.countByStatus('resolved'),
                      )),
                ),
                Obx(() {
                  final t = ctrl.lastUpdatedAt.value;
                  if (t == null) return const SizedBox(height: 16);
                  return Padding(
                    padding: const EdgeInsets.only(left: 2, top: 8, bottom: 14),
                    child: Row(children: [
                      const Icon(Icons.sync_rounded, size: 12, color: Neo.muted),
                      const SizedBox(width: 4),
                      Text('Mis à jour à ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} · auto',
                          style: Neo.t(11, c: Neo.muted)),
                    ]),
                  );
                }),
                Row(children: [
                  Expanded(child: _ChartPeriodSelector(ctrl: ctrl)),
                  const SizedBox(width: 10),
                  _CategoryFilterChip(ctrl: ctrl),
                ]),
                const SizedBox(height: 18),
                const NeoSectionTitle('Tendance', icon: Icons.show_chart_rounded),
                const SizedBox(height: 12),
                Obx(() => _TrendLineChart(points: ctrl.trendData, period: ctrl.chartPeriod.value)),
                const SizedBox(height: 24),
                const NeoSectionTitle('Répartition par statut', icon: Icons.bar_chart_outlined),
                const SizedBox(height: 12),
                Obx(() => _StatusBreakdownCard(byStatus: null, localCounts: ctrl.statusBreakdown)),
                const SizedBox(height: 24),
                const NeoSectionTitle('Par catégorie', icon: Icons.pie_chart_outline_rounded),
                const SizedBox(height: 12),
                Obx(() => _CategoryChart(data: ctrl.categoryBreakdown)),
                const SizedBox(height: 24),
                const NeoSectionTitle('Sévérité', icon: Icons.warning_amber_outlined),
                const SizedBox(height: 12),
                Obx(() {
                  final sv = ctrl.severityBreakdown;
                  return _SeverityCards(low: sv['low'] ?? 0, medium: sv['medium'] ?? 0, high: sv['high'] ?? 0);
                }),
                const SizedBox(height: 24),
                const NeoSectionTitle('Récents', icon: Icons.history_outlined),
                const SizedBox(height: 12),
                Obx(() {
                  final items = ctrl.recentReports;
                  if (items.isEmpty) {
                    return const NeoCard(
                      child: NeoEmpty(
                        icon: Icons.inbox_outlined,
                        title: 'Aucun signalement',
                        message: 'Rien à afficher sur cette période.',
                      ),
                    );
                  }
                  return Column(children: items.map((r) => _ReportMiniCard(report: r)).toList());
                }),
              ]),
            ),
          ],
        ),
      );
    });
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
    if (points.isEmpty) {
      return const NeoCard(
        child: NeoEmpty(icon: Icons.show_chart_rounded, title: 'Pas encore de données', message: 'Le graphique apparaîtra ici.'),
      );
    }

    final maxVal = points.fold<int>(0, (m, p) => p.count > m ? p.count : m);
    final maxY = (maxVal < 4 ? 4 : maxVal + 2).toDouble();
    final total = points.fold<int>(0, (s, p) => s + p.count);
    final n = points.length;
    final showEvery = n <= 7 ? 1 : (n <= 12 ? 2 : (n <= 24 ? 4 : 5));    final interval = (maxY / 4).clamp(1.0, double.infinity).toDouble();
    final spots = List.generate(points.length, (i) => FlSpot(i.toDouble(), points[i].count.toDouble()));

    return NeoCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('$total signalement${total != 1 ? 's' : ''}', style: Neo.t(13, w: FontWeight.w700)),
          const Spacer(),
          NeoPill(label: AdminDashboardController.chartPeriods[period] ?? period, color: Neo.blue),
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
              getDrawingHorizontalLine: (_) => FlLine(color: Neo.line.op(0.7), strokeWidth: 1),
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
                  child: Text('${v.toInt()}', style: Neo.t(10, c: Neo.muted)),
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
                    child: Text(points[i].label, style: Neo.t(10, c: Neo.muted)),
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
                color: Neo.blue,
                barWidth: 3,
                dotData: FlDotData(
                  show: points.length <= 14,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 3.8,
                    color: Neo.blue,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [Neo.blue.op(0.22), Neo.blue.op(0.01)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          )),
        ),
      ]),
    );
  }
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
    Neo.blue,
    Neo.info,
    Neo.warning,
    Neo.danger,
    Neo.purple,
    Neo.blueLight,
    Color(0xFF0EA5E9),
    Color(0xFFF97316),
  ];

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty || widget.data.values.every((v) => v == 0)) {
      return const NeoCard(
        child: NeoEmpty(icon: Icons.pie_chart_outline, title: 'Pas de données', message: 'Aucune catégorie à afficher.'),
      );
    }

    final entries = (widget.data.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(8).toList();
    final total = entries.fold<int>(0, (a, b) => a + b.value);

    return NeoCard(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        SizedBox(
          height: 160,
          child: PieChart(PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 44,
            pieTouchData: PieTouchData(
              touchCallback: (e, resp) {
                setState(() {
                  _touchedIndex = (e is FlTapUpEvent) ? -1 : resp?.touchedSection?.touchedSectionIndex ?? -1;
                });
              },
            ),
            sections: List.generate(entries.length, (i) {
              final e = entries[i];
              final pct = total > 0 ? (e.value / total * 100) : 0.0;
              final touched = i == _touchedIndex;
              return PieChartSectionData(
                value: e.value.toDouble(),
                color: _colors[i % _colors.length],
                title: touched ? '${pct.round()}%\n${e.key}' : '${pct.round()}%',
                radius: touched ? 46 : 34,
                titleStyle: TextStyle(fontSize: touched ? 10 : 9, fontWeight: FontWeight.bold, color: Colors.white),
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
              Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(e.key, overflow: TextOverflow.ellipsis, style: Neo.t(12.5))),
                    Text('${e.value}', style: Neo.t(12, w: FontWeight.w700, c: color)),
                    const SizedBox(width: 6),
                    SizedBox(width: 32, child: Text('${(pct * 100).round()}%', style: Neo.t(10.5, c: Neo.muted))),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      backgroundColor: color.op(0.12),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ]),
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  FILTRES
// ════════════════════════════════════════════════════════════════════════════

class _ChartPeriodSelector extends StatelessWidget {
  final AdminDashboardController ctrl;
  const _ChartPeriodSelector({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final keys = AdminDashboardController.chartPeriods.keys.toList();
    final labels = AdminDashboardController.chartPeriods.values.toList();
    return Obx(() => NeoTabs(
          labels: labels,
          index: keys.indexOf(ctrl.chartPeriod.value).clamp(0, keys.length - 1).toInt(),
          onChanged: (i) => ctrl.setChartPeriod(keys[i]),
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
      return NeoPressable(
        onTap: () {
          Get.bottomSheet(
            Container(
              decoration: BoxDecoration(
                color: Neo.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Neo.shadow.withOpacity(0.5), blurRadius: 24)],
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Filtrer par catégorie', style: Neo.t(17, w: FontWeight.w700)),
                    const SizedBox(height: 14),
                    Obx(() => Wrap(spacing: 10, runSpacing: 10, children: [
                          _catChip('Toutes', '', ctrl),
                          ...cats.map((c) => _catChip(c, c, ctrl)),
                        ])),
                    const SizedBox(height: 16),
                  ]),
                ),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: sel.isEmpty ? Neo.surface : Neo.blue.op(0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: sel.isEmpty ? Colors.white : Neo.blue.op(0.4)),
            boxShadow: Neo.softRelief(),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.filter_list_rounded, size: 16, color: sel.isEmpty ? Neo.muted : Neo.blue),
            const SizedBox(width: 5),
            Text(sel.isEmpty ? 'Catégorie' : sel, style: Neo.t(11.5, w: FontWeight.w600, c: sel.isEmpty ? Neo.muted : Neo.blue)),
          ]),
        ),
      );
    });
  }

  static Widget _catChip(String label, String value, AdminDashboardController ctrl) => NeoChip(
        label: label,
        selected: ctrl.selectedCategory.value == value,
        onTap: () {
          ctrl.setSelectedCategory(value);
          Get.back();
        },
      );
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
  _RFilter('pending', 'En attente', Neo.warning),
  _RFilter('routed', 'Routés', Neo.info),
  _RFilter('in_progress', 'En cours', Neo.purple),
  _RFilter('resolved', 'Résolus', Neo.success),
  _RFilter('all', 'Tous', Neo.blue),
];

class _AdminRoutingPage extends StatelessWidget {
  const _AdminRoutingPage();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AdminDashboardController>();
    return Column(children: [
      NeoTitleBar(
        title: 'Gestion des signalements',
        subtitle: 'Routez chaque alerte vers la bonne autorité',
        actions: [NeoIconButton(icon: Icons.refresh_rounded, onTap: ctrl.loadReports)],
      ),
      const SizedBox(height: 8),
      _FilterBar(filters: _routingFilters, ctrl: ctrl),
      Expanded(
        child: Obx(() {
          if (ctrl.isLoadingReports.value) return const NeoLoading();
          final list = ctrl.filteredReports;
          if (list.isEmpty) return _EmptyRoutingState(filter: ctrl.routingFilter.value);
          final auths = ctrl.authorities.toList();
          final loadingAuth = ctrl.isLoadingAuth.value;
          return RefreshIndicator(
            onRefresh: ctrl.loadReports,
            color: Neo.blue,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: list.length,
              itemBuilder: (_, i) => _RoutingCard(report: list[i], ctrl: ctrl, authorities: auths, isLoadingAuth: loadingAuth),
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
      NeoTitleBar(
        title: 'Suivi des signalements',
        subtitle: 'Toutes les alertes de votre zone',
        actions: [NeoIconButton(icon: Icons.refresh_rounded, onTap: ctrl.loadReports)],
      ),
      const SizedBox(height: 8),
      _FilterBar(filters: _routingFilters, ctrl: ctrl),
      Expanded(
        child: Obx(() {
          if (ctrl.isLoadingReports.value) return const NeoLoading();
          final list = ctrl.filteredReports;
          if (list.isEmpty) return _EmptyRoutingState(filter: ctrl.routingFilter.value);
          return RefreshIndicator(
            onRefresh: ctrl.loadReports,
            color: Neo.blue,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
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
      color: Neo.blue,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverToBoxAdapter(
            child: NeoTitleBar(
              title: "L'impact, en images",
              subtitle: 'Les signalements résolus',
              actions: [NeoIconButton(icon: Icons.refresh_rounded, onTap: ctrl.loadReports)],
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Obx(() => NeoStatsStrip(items: [
                    NeoStat('${ctrl.totalResolved}', 'Résolus', Neo.success),
                    NeoStat('${ctrl.resolvedThisWeek}', 'Cette semaine', Neo.blue),
                  ])),
            ),
          ),
          Obx(() {
            if (ctrl.isLoadingReports.value && ctrl.reports.isEmpty) {
              return const SliverFillRemaining(hasScrollBody: false, child: Padding(padding: EdgeInsets.only(top: 60), child: NeoLoading()));
            }
            final grouped = ctrl.groupedNews;
            if (grouped.isEmpty) {
              return const SliverToBoxAdapter(
                child: NeoEmpty(
                  icon: Icons.photo_library_outlined,
                  title: 'Pas encore de succès',
                  message: "Dès qu'un signalement sera résolu, il apparaîtra ici.",
                ),
              );
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  for (final zone in zones) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10, top: 6),
                      child: Row(children: [
                        Icon(Icons.location_city_rounded,
                            size: 16, color: (myRegion.isNotEmpty && zone.contains(myRegion)) ? Neo.blue : Neo.muted),
                        const SizedBox(width: 6),
                        Text(zone, style: Neo.t(15, w: FontWeight.w700)),
                      ]),
                    ),
                    for (final e in grouped[zone]!.entries) _NewsAuthorityBlock(authority: e.key, items: e.value),
                    const SizedBox(height: 8),
                  ],
                ]),
              ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.account_balance_outlined, size: 12, color: Neo.muted),
          const SizedBox(width: 5),
          Text(authority, style: Neo.t(11, w: FontWeight.w700, c: Neo.muted)),
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
    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: photo.isNotEmpty
          ? Image.network(photo, width: 54, height: 54, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(width: 54, height: 54, color: Neo.inset))
          : Container(width: 54, height: 54, color: Neo.inset, child: const Icon(Icons.image_outlined, color: Neo.muted, size: 20)),
    );
    return NeoListCard(
      icon: Icons.image_outlined,
      leading: thumb,
      title: item.title,
      subtitle: '${item.communeName} · ${item.category}',
      pill: const NeoPill(label: 'Résolu', color: Neo.success),
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
      const NeoTitleBar(title: 'Performance agents', subtitle: 'Classement par taux de résolution'),
      const SizedBox(height: 10),
      Expanded(
        child: Obx(() {
          final agents = ctrl.agents;
          if (ctrl.isLoading && agents.isEmpty) return const NeoLoading();
          if (agents.isEmpty) {
            return const NeoEmpty(icon: Icons.support_agent, title: 'Aucun agent', message: 'Aucun agent enregistré pour le moment.');
          }
          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
            itemCount: agents.length,
            itemBuilder: (_, i) => NeoReveal(delayMs: (i % 8) * 40, child: _AgentCard(agent: agents[i], rank: i + 1)),
          );
        }),
      ),
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
    return NeoGroup(
      children: top.asMap().entries.map((e) {
        final i = e.key;
        final a = e.value;
        final rc = a.resolutionRate >= 80 ? Neo.success : a.resolutionRate >= 50 ? Neo.warning : Neo.danger;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: i == 0 ? Neo.warning.op(0.15) : Neo.inset,
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(i < 3 ? medals[i] : '${i + 1}', style: TextStyle(fontSize: i < 3 ? 16 : 12))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(a.name, style: Neo.t(13.5, w: FontWeight.w600)),
                Text('${a.totalAssigned} ass. · ${a.totalResolved} rés.', style: Neo.t(11, c: Neo.muted)),
              ]),
            ),
            NeoPill(label: '${a.resolutionRate.round()}%', color: rc),
          ]),
        );
      }).toList(),
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
    final rc = rate >= 80 ? Neo.success : rate >= 50 ? Neo.warning : Neo.danger;
    const medals = ['🥇', '🥈', '🥉'];

    return NeoCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderColor: rank == 1 ? Neo.warning.op(0.6) : null,
      child: Column(children: [
        Row(children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: rank <= 3 ? Neo.warning.op(0.12) : Neo.inset, shape: BoxShape.circle),
            child: Center(child: Text(rank <= 3 ? medals[rank - 1] : '$rank', style: TextStyle(fontSize: rank <= 3 ? 21 : 15, fontWeight: FontWeight.bold))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(agent.name, style: Neo.t(14, w: FontWeight.w600)),
              Text('${agent.totalAssigned} assigné · ${agent.totalResolved} résolu', style: Neo.t(11, c: Neo.muted)),
            ]),
          ),
          Text('${rate.round()}%', style: Neo.t(18, w: FontWeight.w700, c: rc)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: (rate / 100).clamp(0.0, 1.0).toDouble(),
            minHeight: 7,
            backgroundColor: rc.op(0.12),
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
      const NeoTitleBar(title: 'Utilisateurs', subtitle: 'Citoyens, agents et administrateurs'),
      Expanded(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          child: Obx(() {
            final ov = ctrl.overview;
            return Column(children: [
              _UsersRow(overview: ov),
              const SizedBox(height: 20),
              if (ov != null && ov.totalUsers > 0) _UserDonut(overview: ov),
            ]);
          }),
        ),
      ),
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
      _Seg('Citoyens', overview.totalCitizens, Neo.blue),
      _Seg('Agents', overview.totalAgents, Neo.info),
      _Seg('Admins', total - overview.totalCitizens - overview.totalAgents, Neo.purple),
    ];
    return NeoCard(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Répartition', style: Neo.t(14, w: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          height: 140,
          child: PieChart(PieChartData(
            sectionsSpace: 3,
            centerSpaceRadius: 38,
            sections: items
                .where((s) => s.count > 0)
                .map((s) => PieChartSectionData(
                      value: s.count.toDouble(),
                      color: s.color,
                      title: '${(s.count / total * 100).round()}%',
                      radius: 30,
                      titleStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ))
                .toList(),
          )),
        ),
        const SizedBox(height: 12),
        ...items.map((s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(s.label, style: Neo.t(12.5))),
                Text('${s.count}', style: Neo.t(12, w: FontWeight.w700, c: s.color)),
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
//  PARAMÈTRES / PROFIL
// ════════════════════════════════════════════════════════════════════════════

class _AdminSettingsPage extends StatelessWidget {
  const _AdminSettingsPage();

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final ctrl = Get.find<AdminDashboardController>();

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 28),
      children: [
        NeoReveal(
          child: Obx(() {
            final mairie = ctrl.isMairie.value;
            final roleLabel = mairie ? 'Mairie' : 'Administrateur système';
            final displayName = mairie
                ? _str(ctrl.mairieName.value, _str(auth.userName.value, 'Mairie'))
                : _str(auth.userName.value, 'Administrateur');
            return Column(children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Neo.surface,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: Neo.relief(),
                ),
                child: Icon(mairie ? Icons.account_balance : Icons.admin_panel_settings, size: 48, color: Neo.blue),
              ),
              const SizedBox(height: 14),
              Text(displayName, textAlign: TextAlign.center, style: Neo.t(21, w: FontWeight.w700)),
              const SizedBox(height: 8),
              NeoPill(label: roleLabel, color: Neo.blue),
            ]);
          }),
        ),
        const SizedBox(height: 24),
        NeoReveal(
          delayMs: 80,
          child: NeoGroup(title: 'MON COMPTE', children: [
            NeoRow(icon: Icons.email_outlined, label: 'Email', value: _str(auth.userEmail.value)),
            NeoRow(
              icon: Icons.shield_outlined,
              label: 'Rôle',
              value: ctrl.isMairie.value ? 'Mairie' : 'Administrateur système',
            ),
          ]),
        ),
        const SizedBox(height: 16),
        NeoReveal(
          delayMs: 120,
          child: NeoGroup(title: 'SÉCURITÉ', children: [
            NeoRow(icon: Icons.lock_outline_rounded, label: 'Changer le mot de passe', onTap: () {}),
            NeoRow(
              icon: Icons.notifications_none_rounded,
              label: 'Notifications',
              onTap: () => Get.to(() => const MairieNotificationsScreen()),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        NeoLogoutButton(onTap: () async {
          final ok = await neoConfirm(context,
              title: 'Déconnexion', message: 'Voulez-vous vraiment vous déconnecter ?', confirm: 'Déconnecter');
          if (ok) {
            await AuthService.instance.logout();
            Get.offAllNamed(Routes.SPLASH);
          }
        }),
      ],
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
      backgroundColor: Neo.bg,
      body: NeoBackdrop(
        child: Column(children: [
          NeoTitleBar(
            title: 'Notifications',
            subtitle: 'Vos dernières alertes',
            leading: NeoIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: () => Get.back()),
            actions: [NeoIconButton(icon: Icons.done_all_rounded, onTap: ctrl.markAllAsRead)],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              if (ctrl.isLoading.value) return const NeoLoading();
              if (ctrl.items.isEmpty) {
                return const NeoEmpty(
                  icon: Icons.notifications_none_rounded,
                  title: 'Aucune notification',
                  message: 'Vous serez prévenu ici dès qu\'il y a du nouveau.',
                );
              }
              return RefreshIndicator(
                onRefresh: ctrl.load,
                color: Neo.blue,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  itemCount: ctrl.items.length,
                  itemBuilder: (_, i) {
                    final n = ctrl.items[i];
                    final isRead = n['read_at'] != null;
                    final title = _str(n['title'], 'Notification');
                    final body = _str(n['body'] ?? n['message']);
                    final id = _asInt(n['id']);
                    return NeoListCard(
                      icon: isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                      color: isRead ? Neo.muted : Neo.blue,
                      title: title,
                      subtitle: body.isEmpty ? null : body,
                      onTap: id == null ? null : () => ctrl.markAsRead(id),
                      pill: isRead ? null : const NeoPill(label: 'Nouveau', color: Neo.blue),
                    );
                  },
                ),
              );
            }),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  WIDGETS PARTAGÉS
// ════════════════════════════════════════════════════════════════════════════

class _MairieStatsGrid extends StatelessWidget {
  final int total, pending, routed, resolved;
  const _MairieStatsGrid({required this.total, required this.pending, required this.routed, required this.resolved});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(child: NeoStatTile(label: 'Total reçus', value: '$total', icon: Icons.assignment_outlined, color: Neo.blue)),
        const SizedBox(width: 12),
        Expanded(child: NeoStatTile(label: 'En attente', value: '$pending', icon: Icons.pending_outlined, color: Neo.warning)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: NeoStatTile(label: 'Routés', value: '$routed', icon: Icons.route_outlined, color: Neo.info)),
        const SizedBox(width: 12),
        Expanded(child: NeoStatTile(label: 'Résolus', value: '$resolved', icon: Icons.check_circle_outline, color: Neo.success)),
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
      Expanded(child: NeoStatTile(label: 'Total', value: '${o?.totalUsers ?? 0}', icon: Icons.people_outline, color: Neo.ink)),
      const SizedBox(width: 10),
      Expanded(child: NeoStatTile(label: 'Citoyens', value: '${o?.totalCitizens ?? 0}', icon: Icons.person_outline, color: Neo.blue)),
      const SizedBox(width: 10),
      Expanded(child: NeoStatTile(label: 'Agents', value: '${o?.totalAgents ?? 0}', icon: Icons.support_agent_outlined, color: Neo.info)),
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
    final total = _asInt(byStatus?.total) ?? (pending + routed + inProgress + resolved);
    final safeTotal = total == 0 ? 1 : total;

    final items = [
      _StatusSegment('En attente', pending, Neo.warning),
      _StatusSegment('Routés', routed, Neo.info),
      _StatusSegment('En cours', inProgress, Neo.purple),
      _StatusSegment('Résolus', resolved, Neo.success),
    ];

    return NeoCard(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Répartition', style: Neo.t(14, w: FontWeight.w600)),
          NeoPill(label: '$total total', color: Neo.blue),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 10,
            child: Row(
              children: items
                  .map((item) => Expanded(
                        flex: item.count > 0 ? item.count : 1,
                        child: Container(color: item.count > 0 ? item.color : Neo.line),
                      ))
                  .toList(),
            ),
          ),
        ),
        const SizedBox(height: 14),
        ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                Container(width: 9, height: 9, decoration: BoxDecoration(color: item.color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(child: Text(item.label, style: Neo.t(12.5))),
                Text('${item.count}', style: Neo.t(12, w: FontWeight.w700, c: item.color)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text('${((item.count / safeTotal) * 100).round()}%', textAlign: TextAlign.right, style: Neo.t(10.5, c: Neo.muted)),
                ),
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
      Expanded(child: _SevCard('Faible', low, Neo.success, Icons.arrow_downward)),
      const SizedBox(width: 10),
      Expanded(child: _SevCard('Moyen', medium, Neo.warning, Icons.remove)),
      const SizedBox(width: 10),
      Expanded(child: _SevCard('Élevé', high, Neo.danger, Icons.priority_high)),
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
    return NeoCard(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      child: Column(children: [
        NeoIconBadge(icon: icon, color: color, size: 36),
        const SizedBox(height: 8),
        Text('$count', style: Neo.t(20, w: FontWeight.w700, c: color)),
        Text(label, style: Neo.t(11, c: Neo.muted)),
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
      return NeoChipRow(
        chips: filters.map((f) {
          final count = f.key == 'all' ? totalCount : ctrl.countByStatus(f.key);
          return NeoChip(
            label: f.label,
            color: f.color,
            count: count,
            selected: active == f.key,
            onTap: () => ctrl.routingFilter.value = f.key,
          );
        }).toList(),
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
    return NeoCard(
      onTap: onTap,
      borderColor: Neo.warning.op(0.5),
      child: Row(children: [
        const NeoIconBadge(icon: Icons.pending_actions, color: Neo.warning, size: 46),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('$count signalement${count > 1 ? 's' : ''} en attente', style: Neo.t(14, w: FontWeight.w600)),
            Text('Toucher pour router', style: Neo.t(11, c: Neo.muted)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Neo.warning),
      ]),
    );
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

    return NeoListCard(
      icon: Icons.report_gmailerrorred_rounded,
      color: AdminDashboardController.severityColor(severity),
      title: title,
      subtitle: commune.isEmpty ? null : commune,
      meta: date.isEmpty ? null : date,
      pill: NeoPill(
        label: AdminDashboardController.statusLabel(status),
        color: AdminDashboardController.statusColor(status),
      ),
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
  const _RoutingCard({required this.report, required this.ctrl, required this.authorities, required this.isLoadingAuth});

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
    final catName = _reportCategory(report, 'Inconnue');
    return NeoCard(
      margin: const EdgeInsets.only(bottom: 14),
      borderColor: isPending ? Neo.warning.op(0.5) : null,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          NeoIconBadge(icon: Icons.report_gmailerrorred_rounded, color: sevClr, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Neo.t(14, w: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(commune.isNotEmpty ? '$commune · $reference' : reference,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: Neo.t(11, c: Neo.muted)),
              Text('$catName · ${AdminDashboardController.severityLabel(severity)}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: Neo.t(10.5, w: FontWeight.w600, c: sevClr)),
            ]),
          ),
          const SizedBox(width: 8),
          NeoPill(label: AdminDashboardController.statusLabel(status), color: statusClr),
        ]),
        if (isPending) ...[
          const SizedBox(height: 12),
          Divider(height: 1, color: Neo.line.op(0.8)),
          const SizedBox(height: 12),
          Row(children: [
            const Icon(Icons.route, size: 15, color: Neo.warning),
            const SizedBox(width: 6),
            Text('Choisir une autorité', style: Neo.t(12.5, w: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          if (isLoadingAuth)
            const SizedBox(height: 32, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Neo.blue))))
          else if (authorities.isEmpty)
            Text('Aucune autorité chargée', style: Neo.t(11, c: Neo.muted))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: authorities.map((auth) {
                final isRec = auth['recommended'] == true;
                return NeoPressable(
                  onTap: () => _confirmRoute(report, auth, ctrl),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(
                      color: Neo.blue.op(isRec ? 0.10 : 0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Neo.blue.op(isRec ? 0.5 : 0.22), width: isRec ? 1.5 : 1),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.account_balance, size: 13, color: Neo.blue),
                      const SizedBox(width: 5),
                      Text(_str(auth['name']), style: Neo.t(11.5, w: FontWeight.w600, c: Neo.blue)),
                      if (isRec) ...[
                        const SizedBox(width: 5),
                        const Icon(Icons.check_circle, size: 13, color: Neo.success),
                      ],
                    ]),
                  ),
                );
              }).toList(),
            ),
        ] else ...[
          const SizedBox(height: 10),
          Row(children: [
            Icon(status == 'resolved' ? Icons.check_circle : Icons.schedule, size: 14, color: statusClr),
            const SizedBox(width: 5),
            Text(AdminDashboardController.statusLabel(status), style: Neo.t(11.5, w: FontWeight.w600, c: statusClr)),
            const Spacer(),
            Text(_fmtDate(report['created_at']), style: Neo.t(11, c: Neo.muted)),
          ]),
        ],
      ]),
    );
  }

  void _confirmRoute(Map<String, dynamic> report, Map<String, dynamic> auth, AdminDashboardController ctrl) {
    final authName = _str(auth['name']);
    final reportTitle = _str(report['title'], 'Ce signalement');
    final reportId = _asInt(report['id']);
    final authId = _asInt(auth['id']);

    Get.dialog(Dialog(
      backgroundColor: Neo.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const NeoIconBadge(icon: Icons.route, size: 40),
            const SizedBox(width: 10),
            Expanded(child: Text('Confirmer le routage', style: Neo.t(16, w: FontWeight.w700))),
          ]),
          const SizedBox(height: 14),
          Text(reportTitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: Neo.t(13.5, w: FontWeight.w600)),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Neo.warning.op(0.10), borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  const Icon(Icons.pending_actions, color: Neo.warning, size: 18),
                  const SizedBox(height: 4),
                  Text('En attente', style: Neo.t(10, w: FontWeight.w600, c: Neo.warning)),
                ]),
              ),
            ),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward, color: Neo.blue, size: 22)),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Neo.blue.op(0.10), borderRadius: BorderRadius.circular(14)),
                child: Column(children: [
                  const Icon(Icons.account_balance, color: Neo.blue, size: 18),
                  const SizedBox(height: 4),
                  Text(authName, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: Neo.t(10, w: FontWeight.w600, c: Neo.blue)),
                ]),
              ),
            ),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: NeoButton(label: 'Annuler', outlined: true, onTap: () => Get.back())),
            const SizedBox(width: 10),
            Expanded(
              child: NeoButton(
                label: 'Router',
                onTap: (reportId == null || authId == null)
                    ? null
                    : () {
                        Get.back();
                        ctrl.routeReport(reportId: reportId, authorityId: authId, authorityName: authName);
                      },
              ),
            ),
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

class _EmptyRoutingState extends StatelessWidget {
  final String filter;
  const _EmptyRoutingState({required this.filter});

  @override
  Widget build(BuildContext context) {
    return NeoEmpty(
      icon: Icons.check_circle_outline,
      title: filter == 'pending' ? 'Aucun signalement en attente' : 'Aucun signalement ici',
      message: filter == 'pending'
          ? 'Tous les signalements ont été routés.'
          : "Changez le filtre pour voir d'autres signalements.",
    );
  }
}
