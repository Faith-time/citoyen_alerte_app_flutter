import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/services/auth_service.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/routes/app_pages.dart';

class AuthorityDashboardController extends GetxController {
  final ApiService _api = Get.find<ApiService>();

  final currentIndex = 0.obs;

  // ── Dashboard ─────────────────────────────────────────────────────────────
  final isLoadingDash   = true.obs;
  final dashError       = ''.obs;
  final authorityName   = ''.obs;
  final authorityType   = ''.obs;
  final totalAssigned   = 0.obs;
  final totalPending    = 0.obs;
  final totalInProgress = 0.obs;
  final totalResolved   = 0.obs;
  final resolvedToday   = 0.obs;
  final recentRoutings  = <Map<String, dynamic>>[].obs;

  // ── Signalements ─────────────────────────────────────────────────────────
  final isLoadingRoutings = false.obs;
  final routingFilter     = 'pending'.obs;
  final allRoutings       = <Map<String, dynamic>>[].obs;

  List<Map<String, dynamic>> get filteredRoutings {
    final f = routingFilter.value;
    if (f == 'all') return allRoutings;
    return allRoutings.where((r) => r['status'] == f).toList();
  }

  int countByStatus(String status) =>
      allRoutings.where((r) => r['status'] == status).length;

  // ── Agents ───────────────────────────────────────────────────────────────
  final isLoadingAgents = false.obs;
  final agents          = <Map<String, dynamic>>[].obs;

  List<Map<String, dynamic>> get availableAgents => agents.where((a) {
    final c = a['current_interventions_count'] as int? ?? 0;
    return c == 0;
  }).toList();

  @override
  void onInit() {
    super.onInit();
    fetchDashboard();
    fetchRoutings();
    fetchAgents();
  }

  void changePage(int i) => currentIndex.value = i;

  // ── DASHBOARD ─────────────────────────────────────────────────────────────

  Future<void> fetchDashboard() async {
    isLoadingDash.value = true;
    dashError.value     = '';
    try {
      final resp = await _api.get('/dashboard/authority');
      if (resp.success && resp.data != null) {
        final d = resp.data as Map<String, dynamic>;
        authorityName.value   = d['authority_name']  ?? '';
        authorityType.value   = d['authority_type']  ?? '';
        totalAssigned.value   = d['total_assigned']  ?? 0;
        totalPending.value    = d['pending']          ?? 0;
        totalInProgress.value = d['in_progress']      ?? 0;
        totalResolved.value   = d['resolved']         ?? 0;
        resolvedToday.value   = d['resolved_today']   ?? 0;

        final rr = d['recent_routings'];
        if (rr is List) {
          recentRoutings.value = rr.cast<Map<String, dynamic>>();
        }
      } else {
        dashError.value = resp.message ?? 'Erreur serveur';
      }
    } catch (e) {
      dashError.value = e.toString();
    } finally {
      isLoadingDash.value = false;
    }
  }

  Future<void> refresh() async {
    await Future.wait([fetchDashboard(), fetchRoutings(), fetchAgents()]);
  }

  // ── SIGNALEMENTS ─────────────────────────────────────────────────────────

  Future<void> fetchRoutings() async {
    isLoadingRoutings.value = true;
    try {
      final resp = await _api.get('/authority/routings'); // ✅ endpoint dédié
      if (resp.success && resp.data != null) {
        final raw = resp.data;
        final list = raw is List
            ? raw
            : (raw as Map<String, dynamic>)['data'] ?? [];
        allRoutings.value = (list as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {
    } finally {
      isLoadingRoutings.value = false;
    }
  }
  /// Autorité : changer le statut d'un signalement reçu
  Future<void> updateRoutingStatus(
      int routingId, int reportId, String newStatus) async {
    try {
      final resp = await _api.put(
        '/reports/$reportId/routings/$routingId',
        data: {'status': newStatus},
      );
      if (resp.success) {
        final idx = allRoutings.indexWhere((r) => r['id'] == routingId);
        if (idx != -1) {
          allRoutings[idx] = {...allRoutings[idx], 'status': newStatus};
          allRoutings.refresh();
        }
        await fetchDashboard();
        _snackSuccess('Statut mis à jour',
            'Signalement marqué : ${statusLabel(newStatus)}');
      } else {
        _snackError(resp.message ?? 'Mise à jour échouée');
      }
    } catch (e) {
      _snackError('Erreur : $e');
    }
  }

  // ── ASSIGNATION ──────────────────────────────────────────────────────────

  Future<void> assignToAgent({
    required int reportId,
    required int agentId,
    required String agentName,
  }) async {
    try {
      final resp = await _api.post('/interventions', data: {
        'report_id': reportId,
        'agent_id':  agentId,
        'status':    'pending',
        'notes':     'Assigné par ${authorityName.value}',
      });
      if (resp.success) {
        await fetchAgents();
        _snackSuccess('Assignation effectuée',
            'Signalement assigné à $agentName');
      } else {
        _snackError(resp.message ?? 'Assignation échouée');
      }
    } catch (e) {
      _snackError('Erreur : $e');
    }
  }


  /// Assigne PLUSIEURS agents en une seule fois au même signalement.
  Future<void> assignAgents({
    required int reportId,
    required List<int> agentIds,
    required Map<int, String> agentNames,
  }) async {
    final failed = <String>[];
    for (final agentId in agentIds) {
      try {
        final resp = await _api.post('/interventions', data: {
          'report_id': reportId,
          'agent_id':  agentId,
          'status':    'pending',
          'notes':     'Assigné par ${authorityName.value}',
        });
        if (!resp.success) failed.add(agentNames[agentId] ?? 'Agent #$agentId');
      } catch (_) {
        failed.add(agentNames[agentId] ?? 'Agent #$agentId');
      }
    }
    await fetchAgents();
    if (failed.isEmpty) {
      _snackSuccess(
        'Assignation effectuée',
        '${agentIds.length} agent${agentIds.length > 1 ? "s" : ""} assigné${agentIds.length > 1 ? "s" : ""}',
      );
    } else {
      _snackError('Échec pour : ${failed.join(', ')}');
    }
  }

  // ── AGENTS ───────────────────────────────────────────────────────────────

  Future<void> fetchAgents() async {
    isLoadingAgents.value = true;
    try {
      final resp = await _api.get('/agent-zones');
      if (resp.success && resp.data != null) {
        final raw  = resp.data;
        final list = raw is List
            ? raw
            : (raw as Map<String, dynamic>)['data'] ?? [];
        agents.value = (list as List).cast<Map<String, dynamic>>();
      }
    } catch (_) {
    } finally {
      isLoadingAgents.value = false;
    }
  }

  Future<void> addAgent({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final result = await _api.post('/authority/agents', data: {
      'name':     name,
      'email':    email,
      'phone':    phone.isNotEmpty ? phone : null,
      'password': password,
    });
    if (result.success) {
      await fetchAgents();
      _snackSuccess('Agent créé', '$name a été ajouté avec succès');
    } else {
      throw Exception(result.message ?? "Impossible de créer l'agent");
    }
  }



  Future<void> updateAgent({
    required int userId,
    required String name,
    required String email,
    required String phone,
  }) async {
    final result = await _api.put('/authority/agents/$userId', data: {
      'name':  name,
      'email': email,
      'phone': phone.isNotEmpty ? phone : null,
    });
    if (result.success) {
      await fetchAgents();
      _snackSuccess('Agent modifié', '$name a été mis à jour');
    } else {
      throw Exception(result.message ?? "Impossible de modifier l'agent");
    }
  }

  Future<void> deleteAgent(int userId, String name) async {
    final result = await _api.get('/authority/agents/$userId');
    if (result.success) {
      await fetchAgents();
      _snackSuccess('Agent supprimé', '$name a été retiré');
    } else {
      _snackError(result.message ?? "Impossible de supprimer l'agent");
    }
  }
  // ── HELPERS STATIQUES ────────────────────────────────────────────────────

  static Color statusColor(String s) => switch (s) {
    'pending'     => Colors.orange,
    'routed'      => Colors.blue,
    'in_progress' => const Color(0xFF7B1FA2),
    'resolved'    => Colors.green,
    _             => Colors.grey,
  };

  static String statusLabel(String s) => switch (s) {
    'pending'     => 'En attente',
    'routed'      => 'Routé',
    'in_progress' => 'En cours',
    'resolved'    => 'Résolu',
    _             => s,
  };

  static Color severityColor(String s) => switch (s) {
    'high'   => Colors.red,
    'medium' => Colors.orange,
    'low'    => Colors.green,
    _        => Colors.grey,
  };

  static String severityLabel(String s) => switch (s) {
    'high'   => 'ÉLEVÉ',
    'medium' => 'MOYEN',
    'low'    => 'FAIBLE',
    _        => s.toUpperCase(),
  };

  void _snackSuccess(String title, String msg) => Get.snackbar(
    title, msg,
    backgroundColor: const Color(0xFF1565C0),
    colorText: Colors.white,
    snackPosition: SnackPosition.BOTTOM,
    margin: const EdgeInsets.all(16),
    duration: const Duration(seconds: 3),
  );

  void _snackError(String msg) => Get.snackbar(
    '❌ Erreur', msg,
    backgroundColor: Colors.red[700],
    colorText: Colors.white,
    snackPosition: SnackPosition.BOTTOM,
    margin: const EdgeInsets.all(16),
  );
}

// ════════════════════════════════════════════════════════════════════════════
//  SCREEN PRINCIPAL
// ════════════════════════════════════════════════════════════════════════════

class AuthorityDashboardScreen extends StatelessWidget {
  const AuthorityDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(AuthorityDashboardController());
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: Obx(() => IndexedStack(
        index: ctrl.currentIndex.value,
        children: const [
          _AuthHomePage(),
          _AuthRoutingPage(),
          _AuthAgentsPage(),
          _AuthSettingsPage(),
        ],
      )),
      bottomNavigationBar: Obx(() => _AuthBottomNav(
        currentIndex: ctrl.currentIndex.value,
        onTap: ctrl.changePage,
        pendingCount: ctrl.totalPending.value,
      )),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  BOTTOM NAV
// ════════════════════════════════════════════════════════════════════════════

class _AuthBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int pendingCount;

  const _AuthBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.pendingCount,
  });

  static const _blue = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {

    final items = [
      _NavDef(Icons.dashboard_outlined,  Icons.dashboard,     'Accueil',     0),
      _NavDef(Icons.assignment_outlined, Icons.assignment,    'Signalements', pendingCount),
      _NavDef(Icons.groups_outlined,     Icons.groups,        'Agents',      0),
      _NavDef(Icons.settings_outlined,   Icons.settings,      'Paramètres',  0),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final item   = items[i];
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
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: active
                                ? _blue.withOpacity(0.1)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            active ? item.activeIcon : item.icon,
                            color: active ? _blue : Colors.grey[400],
                            size: 20,
                          ),
                        ),
                        if (item.badge > 0)
                          Positioned(
                            top: -4, right: -4,
                            child: Container(
                              constraints:
                              const BoxConstraints(minWidth: 16),
                              height: 16,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color: Colors.white, width: 1.5),
                              ),
                              child: Center(
                                child: Text('${item.badge}',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                      ]),
                      const SizedBox(height: 2),
                      Text(item.label,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: active
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: active ? _blue : Colors.grey[400],
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

class _SH extends StatelessWidget {
  final String title;
  final IconData icon;
  const _SH({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 16, color: const Color(0xFF1565C0)),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1A1A2E),
        ),
      ),
    ]);
  }
}


class _AuthHomePage extends StatelessWidget {
  const _AuthHomePage();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AuthorityDashboardController>();

    return Obx(() {
      if (ctrl.isLoadingDash.value && ctrl.totalAssigned.value == 0) {
        return const Center(
            child: CircularProgressIndicator(color: Color(0xFF1565C0)));
      }
      if (ctrl.dashError.isNotEmpty && ctrl.totalAssigned.value == 0) {
        return _ErrorState(onRetry: ctrl.refresh);
      }

      return RefreshIndicator(
        onRefresh: ctrl.refresh,
        color: const Color(0xFF1565C0),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 162,
              pinned: true,
              backgroundColor: const Color(0xFF0D47A1),
              flexibleSpace:
              FlexibleSpaceBar(background: _BlueHeader(ctrl: ctrl)),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Alerte en attente
                  Obx(() {
                    final n = ctrl.totalPending.value;
                    if (n == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _PendingBanner(
                          count: n, onTap: () => ctrl.changePage(1)),
                    );
                  }),

                  // Carte chiffres du jour
                  Obx(() => _PeriodCard(
                    totalAssigned: ctrl.totalAssigned.value,
                    resolved:      ctrl.totalResolved.value,
                    resolvedToday: ctrl.resolvedToday.value,
                  )),
                  const SizedBox(height: 20),

                  // Grille stats
                  const _SH(
                      title: 'Vue d\'ensemble',
                      icon: Icons.bar_chart_outlined),
                  const SizedBox(height: 10),
                  Obx(() => _StatsGrid(
                    total:      ctrl.totalAssigned.value,
                    pending:    ctrl.totalPending.value,
                    inProgress: ctrl.totalInProgress.value,
                    resolved:   ctrl.totalResolved.value,
                  )),
                  const SizedBox(height: 20),

                  // Activité récente
                  const _SH(
                      title: 'Activité récente',
                      icon: Icons.history_outlined),
                  const SizedBox(height: 10),
                  Obx(() {
                    final plain = List<Map<String, dynamic>>.from(
                        ctrl.recentRoutings.take(5));
                    if (plain.isEmpty) {
                      return const _EmptyState(
                        icon: Icons.inbox_outlined,
                        message: 'Aucun signalement reçu pour le moment',
                      );
                    }
                    return Column(
                      children: plain
                          .map((r) => _RoutingMiniCard(routing: r))
                          .toList(),
                    );
                  }),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      );
    });
  }
}


class _AuthRoutingPage extends StatelessWidget {
  const _AuthRoutingPage();

  static final List<Map<String, dynamic>> _authorityFilters = [
    {'key': 'routed',      'label': 'En attente',  'color': Colors.blue},
    {'key': 'in_progress', 'label': 'En cours',    'color': Color(0xFF7B1FA2)},
    {'key': 'resolved',    'label': 'Résolus',     'color': Colors.green},
    {'key': 'all',         'label': 'Tous',        'color': Colors.grey},
  ];
  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AuthorityDashboardController>();

    return Column(children: [
      _RoutingHeader(ctrl: ctrl),
      _RoutingFilterBar(filters: _authorityFilters, ctrl: ctrl),
      Expanded(
        child: Obx(() {
          final isLoading = ctrl.isLoadingRoutings.value;
          final filter     = ctrl.routingFilter.value;
          final list       = ctrl.filteredRoutings;
          final available  = ctrl.availableAgents;

          if (isLoading) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFF1565C0)));
          }
          if (list.isEmpty) {
            return _RoutingEmptyState(filter: filter);
          }
          return RefreshIndicator(
            onRefresh: ctrl.fetchRoutings,
            color: const Color(0xFF1565C0),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (_, i) => _RoutingCard(
                routing:   list[i],
                ctrl:      ctrl,
                available: available,
              ),
            ),
          );
        }),
      ),
    ]);
  }
}

// ─── Header ───────────────────────────────────────────────────────────────

class _RoutingHeader extends StatelessWidget {
  final AuthorityDashboardController ctrl;
  const _RoutingHeader({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D47A1),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(children: [
            const Icon(
              Icons.assignment,
              color: Colors.white70,
              size: 20,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Mes Signalements',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: ctrl.fetchRoutings,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─── Barre de filtres ─────────────────────────────────────────────────────
//
//  Obx dans build() → couvre les builders lazy du ListView.separated.

class _RoutingFilterBar extends StatelessWidget {
  final List<Map<String, dynamic>> filters;
  final AuthorityDashboardController ctrl;
  const _RoutingFilterBar({required this.filters, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final activeFilter = ctrl.routingFilter.value;
      final counts = <String, int>{};
      for (final f in filters) {
        final k = f['key'] as String;
        counts[k] =
        k == 'all' ? ctrl.allRoutings.length : ctrl.countByStatus(k);
      }

      return Container(
        height: 52,
        color: const Color(0xFF0D47A1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: filters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final f     = filters[i];
            final key   = f['key'] as String;
            final label = f['label'] as String;
            final color = (f['color'] as Color?) ?? Colors.grey;            final active = activeFilter == key;
            final count  = counts[key] ?? 0;

            return GestureDetector(
              onTap: () => ctrl.routingFilter.value = key,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: active
                      ? Colors.white
                      : Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: active
                            ? const Color(0xFF1565C0)
                            : Colors.white,
                      )),
                  const SizedBox(width: 5),
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: active
                          ? color.withOpacity(0.15)
                          : Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$count',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: active ? color : Colors.white,
                        )),
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


class _RoutingEmptyState extends StatelessWidget {
  final String filter;
  const _RoutingEmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final isWaiting = filter == 'routed';

    String message;
    String sub;
    if (isWaiting) {
      message = 'Aucun signalement en attente';
      sub = 'Tous vos signalements ont été traités';
    } else {
      message = 'Aucun signalement ici';
      sub = "Changez le filtre pour voir d'autres";
    }

    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.check_circle_outline, size: 72, color: Colors.grey[200]),
        const SizedBox(height: 14),
        Text(message,
            style: TextStyle(
                color: Colors.grey[500], fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(sub,
            style: TextStyle(color: Colors.grey[400], fontSize: 12)),
      ]),
    );
  }
}

// ─── Routing Card ─────────────────────────────────────────────────────────

class _RoutingCard extends StatelessWidget {
  final Map<String, dynamic> routing;
  final AuthorityDashboardController ctrl;
  final List<Map<String, dynamic>> available;

  const _RoutingCard({
    required this.routing,
    required this.ctrl,
    required this.available,
  });

  /// Extrait le nom de catégorie qu'elle soit un String ou un Map {id, name}
  String _categoryName(dynamic raw) {
    if (raw == null) return '';
    if (raw is Map) return raw['name'] as String? ?? '';
    return raw as String? ?? '';
  }
  @override
  Widget build(BuildContext context) {
    final status    = (routing['status'] as String?) ?? 'pending';
    final rep       = routing['report'] as Map?;
    final severity  = rep?['severity']     as String? ?? 'low';
    final title     = rep?['title']        as String? ?? 'Signalement';
    final ref       = rep?['reference']    as String? ?? '';
    final commune   = rep?['commune_name'] as String? ?? '';
    final _cat = rep?['category'];
    final category = _cat is Map ? (_cat['name'] as String? ?? '') : (_cat as String? ?? '');    final reportId  = rep?['id']           as int?    ?? 0;
    final routingId = routing['id']        as int?    ?? 0;
    final routedAt  = routing['routed_at'] as String?;

    final isRouted  = status == 'routed';    // en attente de prise en charge
    final isInProg  = status == 'in_progress';

    final statusClr = AuthorityDashboardController.statusColor(status);
    final sevClr    = AuthorityDashboardController.severityColor(severity);

    Border? cardBorder;
    if (isRouted) {
      cardBorder =
          Border.all(color: Colors.blue.withOpacity(0.4), width: 1.5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: cardBorder,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Infos principales ─────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 4,
              height: 65,
              decoration: BoxDecoration(
                  color: sevClr, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(title,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: Color(0xFF1A1A2E)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                          label: AuthorityDashboardController
                              .statusLabel(status),
                          color: statusClr),
                    ]),
                    const SizedBox(height: 5),
                    Row(children: [
                      Icon(Icons.location_on_outlined,
                          size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          commune.isNotEmpty ? '$commune · $ref' : ref,
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[500]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Row(children: [
                      Icon(Icons.label_outline,
                          size: 12, color: Colors.grey[500]),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(category,
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                            overflow: TextOverflow.ellipsis),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: sevClr.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          AuthorityDashboardController.severityLabel(severity),
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: sevClr),
                        ),
                      ),
                    ]),
                    if (routedAt != null) ...[
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.access_time,
                            size: 11, color: Colors.grey[400]),
                        const SizedBox(width: 3),
                        Text('Reçu le ${_formatDate(routedAt)}',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[400])),
                      ]),
                    ],
                  ]),
            ),
          ]),
        ),

        // ══════════════════════════════════════════════════════════
        //  SECTION AUTORITÉ : statut + assignation agent
        // ══════════════════════════════════════════════════════════
        if (isRouted || isInProg) ...[
          Container(
              height: 1,
              color: Colors.grey.withOpacity(0.08),
              margin: const EdgeInsets.symmetric(horizontal: 14)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Bouton changement de statut
                  if (isRouted)
                    _ActionButton(
                      label: 'Prendre en charge',
                      icon: Icons.play_arrow_outlined,
                      color: const Color(0xFF7B1FA2),
                      onTap: () => ctrl.updateRoutingStatus(
                          routingId, reportId, 'in_progress'),
                    ),
                  if (isInProg)
                    _ActionButton(
                      label: 'Marquer résolu',
                      icon: Icons.check_circle_outline,
                      color: Colors.green,
                      onTap: () => ctrl.updateRoutingStatus(
                          routingId, reportId, 'resolved'),
                    ),
                  const SizedBox(height: 10),

                  // Bloc assignation agent
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                          color: const Color(0xFF1565C0).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.person_add_outlined,
                          size: 14, color: Color(0xFF1565C0)),
                    ),
                    const SizedBox(width: 7),
                    const Text('Assigner à un agent',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E))),
                  ]),
                  const SizedBox(height: 8),
                  if (available.isEmpty)
                    _NoAgentBanner(onAddAgent: () => ctrl.changePage(2))
                  else
                    _AgentMultiSelectChips(
                      available: available,
                      reportId: reportId,
                      ctrl: ctrl,
                    ),
                ]),
          ),
        ],

        // ── Résolu ────────────────────────────────────────────────
        if (status == 'resolved') ...[
          Container(
              height: 1,
              color: Colors.grey.withOpacity(0.08),
              margin: const EdgeInsets.symmetric(horizontal: 14)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
            child: Row(children: [
              const Icon(Icons.check_circle,
                  color: Colors.green, size: 13),
              const SizedBox(width: 5),
              Text(
                'Résolu le ${_formatDate(routing['resolved_at'])}',
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.green,
                    fontWeight: FontWeight.w600),
              ),
            ]),
          ),
        ],

      ]),
    );
  }

  String _formatDate(dynamic d) {
    if (d == null) return '';
    try {
      final dt = DateTime.parse(d as String).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return '';
    }
  }
}

class _AgentMultiSelectChips extends StatefulWidget {
  final List<Map<String, dynamic>> available;
  final int reportId;
  final AuthorityDashboardController ctrl;
  const _AgentMultiSelectChips({
    required this.available,
    required this.reportId,
    required this.ctrl,
  });

  @override
  State<_AgentMultiSelectChips> createState() => _AgentMultiSelectChipsState();
}

class _AgentMultiSelectChipsState extends State<_AgentMultiSelectChips> {
  final Set<int> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: widget.available.map((a) {
            final ad = a['agent'] as Map? ?? a;
            final aId = ad['id'] as int? ?? a['agent_id'] as int? ?? 0;
            final aName = ad['name'] as String? ?? 'Agent';
            final isSelected = _selected.contains(aId);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selected.remove(aId);
                  } else {
                    _selected.add(aId);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF1565C0)
                      : const Color(0xFF1565C0).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF1565C0).withOpacity(isSelected ? 1 : 0.25),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? Icons.check_circle : Icons.person_outline,
                      size: 14,
                      color: isSelected ? Colors.white : const Color(0xFF1565C0),
                    ),
                    const SizedBox(width: 5),
                    Text(aName,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : const Color(0xFF1565C0))),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (_selected.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _confirmMulti(context),
              icon: const Icon(Icons.person_add, size: 16, color: Colors.white),
              label: Text('Assigner (${_selected.length})',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _confirmMulti(BuildContext ctx) {
    final names = <int, String>{};
    final selectedNames = <String>[];
    for (final a in widget.available) {
      final ad = a['agent'] as Map? ?? a;
      final aId = ad['id'] as int? ?? a['agent_id'] as int? ?? 0;
      if (_selected.contains(aId)) {
        final n = ad['name'] as String? ?? 'Agent';
        names[aId] = n;
        selectedNames.add(n);
      }
    }

    Get.dialog(Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.groups, color: Color(0xFF1565C0), size: 20),
              ),
              const SizedBox(width: 10),
              Text('Assigner ${_selected.length} agent${_selected.length > 1 ? "s" : ""}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 16),
            ...selectedNames.map((n) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                const Icon(Icons.person, size: 14, color: Color(0xFF1565C0)),
                const SizedBox(width: 6),
                Text(n, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            )),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Get.back(),
                  style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Get.back();
                    widget.ctrl.assignAgents(
                      reportId: widget.reportId,
                      agentIds: names.keys.toList(),
                      agentNames: names,
                    );
                    setState(() => _selected.clear());
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('Confirmer'),
                ),
              ),
            ]),
          ],
        ),
      ),
    ));
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PAGE 3 — AGENTS
// ════════════════════════════════════════════════════════════════════════════

class _AuthAgentsPage extends StatelessWidget {
  const _AuthAgentsPage();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AuthorityDashboardController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: const Color(0xFF0D47A1),
          title: const Text('Mes Agents',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_add, color: Colors.white),
              onPressed: () => _showAddAgentDialog(context, ctrl),
              tooltip: 'Ajouter un agent',
            ),
          ],
        ),

        // Bandeau stats agents
        SliverToBoxAdapter(
          child: Obx(() {
            final total     = ctrl.agents.length;
            final available = ctrl.availableAgents.length;
            final busy      = total - available;
            return Container(
              color: const Color(0xFF0D47A1),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(children: [
                _AgentStatBadge('Total',       '$total',     Colors.white),
                const SizedBox(width: 8),
                _AgentStatBadge('Disponibles', '$available', Colors.greenAccent),
                const SizedBox(width: 8),
                _AgentStatBadge('Occupés',     '$busy',      Colors.orangeAccent),
              ]),
            );
          }),
        ),

        Obx(() {
          if (ctrl.isLoadingAgents.value) {
            return const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF1565C0))),
            );
          }
          final list = ctrl.agents;
          if (list.isEmpty) {
            return SliverFillRemaining(
              child: _EmptyAgentsPage(
                  onAdd: () => _showAddAgentDialog(context, ctrl)),
            );
          }
          return SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                    (_, i) => _AgentCard(agent: list[i], rank: i + 1),
                childCount: list.length,
              ),
            ),
          );
        }),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAgentDialog(context, ctrl),
        backgroundColor: const Color(0xFF1565C0),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Ajouter un agent',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _showAddAgentDialog(
      BuildContext context, AuthorityDashboardController ctrl) {
    final nameCtrl     = TextEditingController();
    final emailCtrl    = TextEditingController();
    final phoneCtrl    = TextEditingController();
    final passwordCtrl = TextEditingController();
    final formKey      = GlobalKey<FormState>();
    final isLoading    = false.obs;
    final errorMsg     = ''.obs;

    Get.dialog(Dialog(
      shape:
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: Obx(() => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1565C0).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.person_add,
                        color: Color(0xFF1565C0), size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Nouvel agent',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                const SizedBox(height: 4),
                Text('Crée un compte avec le rôle Agent',
                    style:
                    TextStyle(fontSize: 11, color: Colors.grey[500])),
                const SizedBox(height: 18),

                if (errorMsg.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.red.withOpacity(0.3))),
                    child: Row(children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 14),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(errorMsg.value,
                            style: const TextStyle(
                                fontSize: 11, color: Colors.red)),
                      ),
                    ]),
                  ),

                _FormField(
                    controller: nameCtrl,
                    label: 'Nom complet *',
                    icon: Icons.person_outline,
                    validator: (v) =>
                    v!.trim().isEmpty ? 'Obligatoire' : null),
                const SizedBox(height: 12),
                _FormField(
                    controller: emailCtrl,
                    label: 'Email *',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) =>
                    v!.trim().isEmpty ? 'Obligatoire' : null),
                const SizedBox(height: 12),
                _FormField(
                    controller: phoneCtrl,
                    label: 'Téléphone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 12),
                _FormField(
                    controller: passwordCtrl,
                    label: 'Mot de passe *',
                    icon: Icons.lock_outline,
                    obscureText: true,
                    validator: (v) => (v?.length ?? 0) < 8
                        ? 'Min. 8 caractères'
                        : null),
                const SizedBox(height: 20),

                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                      isLoading.value ? null : () => Get.back(),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading.value
                          ? null
                          : () async {
                        if (!formKey.currentState!.validate()) return;
                        isLoading.value = true;
                        errorMsg.value  = '';
                        try {
                          await ctrl.addAgent(
                            name:     nameCtrl.text.trim(),
                            email:    emailCtrl.text.trim(),
                            phone:    phoneCtrl.text.trim(),
                            password: passwordCtrl.text,
                          );
                          Get.back();
                        } catch (e) {
                          errorMsg.value = e
                              .toString()
                              .replaceAll('Exception: ', '');
                        } finally {
                          isLoading.value = false;
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: isLoading.value
                          ? const SizedBox(
                          width: 16, height: 16,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                          : const Text('Créer l\'agent'),
                    ),
                  ),
                ]),
              ],
            )),
          ),
        ),
      ),
    ));
  }
}

class _AgentCard extends StatelessWidget {
  final Map<String, dynamic> agent;
  final int rank;
  const _AgentCard({required this.agent, required this.rank});

  @override
  Widget build(BuildContext context) {
    final ctrl  = Get.find<AuthorityDashboardController>();
    final ad    = agent['agent'] as Map? ?? agent;
    final userId = ad['id'] as int? ?? 0;
    final name  = ad['name']  as String? ?? 'Agent';
    final email = ad['email'] as String? ?? '';
    final phone = ad['phone'] as String? ?? '';
    final count = agent['current_interventions_count'] as int? ?? 0;
    final isAvail = count == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: isAvail
                ? Colors.green.withOpacity(0.3)
                : Colors.orange.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        // ── Infos agent ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Stack(children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: const Color(0xFF1565C0).withOpacity(0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'A',
                  style: const TextStyle(
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.bold,
                      fontSize: 18),
                ),
              ),
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: isAvail ? Colors.green : Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Color(0xFF1A1A2E))),
                    const SizedBox(height: 2),
                    Text(email,
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        overflow: TextOverflow.ellipsis),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 1),
                      Text(phone,
                          style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isAvail
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isAvail
                            ? 'Disponible'
                            : '$count intervention${count > 1 ? 's' : ''} en cours',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isAvail ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('Agent',
                  style: TextStyle(
                      fontSize: 10,
                      color: Color(0xFF1565C0),
                      fontWeight: FontWeight.w700)),
            ),
          ]),
        ),

        // ── Actions ──────────────────────────────────────────────
        Container(
          height: 1,
          color: Colors.grey.withOpacity(0.08),
          margin: const EdgeInsets.symmetric(horizontal: 16),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(children: [
            // Voir détails
            _AgentAction(
              icon: Icons.visibility_outlined,
              label: 'Détails',
              color: const Color(0xFF1565C0),
              onTap: () => _showDetailDialog(context, ad, count),
            ),
            const SizedBox(width: 8),
            // Modifier
            _AgentAction(
              icon: Icons.edit_outlined,
              label: 'Modifier',
              color: Colors.orange,
              onTap: () => _showEditDialog(context, ctrl, userId, name, email, phone),
            ),
            const SizedBox(width: 8),
            // Supprimer
            _AgentAction(
              icon: Icons.delete_outline,
              label: 'Supprimer',
              color: Colors.red,
              onTap: () => _confirmDelete(context, ctrl, userId, name),
            ),
          ]),
        ),
      ]),
    );
  }

  void _showDetailDialog(BuildContext ctx, Map ad, int count) {
    final name  = ad['name']  as String? ?? '';
    final email = ad['email'] as String? ?? '';
    final phone = ad['phone'] as String? ?? '';
    final isAvail = count == 0;

    Get.dialog(Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: const Color(0xFF1565C0).withOpacity(0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'A',
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0)),
            ),
          ),
          const SizedBox(height: 12),
          Text(name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isAvail ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              isAvail ? 'Disponible' : '$count intervention(s) en cours',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: isAvail ? Colors.green : Colors.orange),
            ),
          ),
          const SizedBox(height: 20),
          _DetailRow(icon: Icons.email_outlined,  label: 'Email',     value: email),
          const SizedBox(height: 10),
          _DetailRow(icon: Icons.phone_outlined,  label: 'Téléphone', value: phone.isNotEmpty ? phone : 'Non renseigné'),
          const SizedBox(height: 10),
          _DetailRow(icon: Icons.work_outline,    label: 'Rôle',      value: 'Agent'),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              child: const Text('Fermer'),
            ),
          ),
        ]),
      ),
    ));
  }

  void _showEditDialog(BuildContext ctx, AuthorityDashboardController ctrl,
      int userId, String name, String email, String phone) {
    final nameCtrl  = TextEditingController(text: name);
    final emailCtrl = TextEditingController(text: email);
    final phoneCtrl = TextEditingController(text: phone);
    final formKey   = GlobalKey<FormState>();
    final isLoading = false.obs;
    final errorMsg  = ''.obs;

    Get.dialog(Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: formKey,
            child: Obx(() => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.edit, color: Colors.orange, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text('Modifier l\'agent',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
                const SizedBox(height: 18),
                if (errorMsg.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3))),
                    child: Text(errorMsg.value,
                        style: const TextStyle(fontSize: 11, color: Colors.red)),
                  ),
                _FormField(
                    controller: nameCtrl,
                    label: 'Nom complet *',
                    icon: Icons.person_outline,
                    validator: (v) => v!.trim().isEmpty ? 'Obligatoire' : null),
                const SizedBox(height: 12),
                _FormField(
                    controller: emailCtrl,
                    label: 'Email *',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) => v!.trim().isEmpty ? 'Obligatoire' : null),
                const SizedBox(height: 12),
                _FormField(
                    controller: phoneCtrl,
                    label: 'Téléphone',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isLoading.value ? null : () => Get.back(),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading.value ? null : () async {
                        if (!formKey.currentState!.validate()) return;
                        isLoading.value = true;
                        errorMsg.value  = '';
                        try {
                          await ctrl.updateAgent(
                            userId: userId,
                            name:   nameCtrl.text.trim(),
                            email:  emailCtrl.text.trim(),
                            phone:  phoneCtrl.text.trim(),
                          );
                          Get.back();
                        } catch (e) {
                          errorMsg.value = e.toString().replaceAll('Exception: ', '');
                        } finally {
                          isLoading.value = false;
                        }
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10))),
                      child: isLoading.value
                          ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Enregistrer'),
                    ),
                  ),
                ]),
              ],
            )),
          ),
        ),
      ),
    ));
  }

  void _confirmDelete(BuildContext ctx, AuthorityDashboardController ctrl,
      int userId, String name) {
    Get.dialog(AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.delete, color: Colors.red, size: 20),
        ),
        const SizedBox(width: 10),
        const Text('Supprimer l\'agent',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
      content: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A2E)),
          children: [
            const TextSpan(text: 'Voulez-vous vraiment supprimer '),
            TextSpan(text: name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const TextSpan(text: ' ? Cette action est irréversible.'),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Get.back(),
            child: const Text('Annuler')),
        ElevatedButton(
          onPressed: () {
            Get.back();
            ctrl.deleteAgent(userId, name);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          child: const Text('Supprimer'),
        ),
      ],
    ));
  }
}

// Widget action bouton dans la card
class _AgentAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AgentAction({
    required this.icon, required this.label,
    required this.color, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.07),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 9, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

// Widget ligne de détail
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 14, color: const Color(0xFF1565C0)),
      ),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey[500])),
        Text(value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A2E))),
      ]),
    ]);
  }
}
// ════════════════════════════════════════════════════════════════════════════
//  PAGE 4 — PARAMÈTRES
// ════════════════════════════════════════════════════════════════════════════

class _AuthSettingsPage extends StatelessWidget {
  const _AuthSettingsPage();

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final ctrl = Get.find<AuthorityDashboardController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: const Color(0xFF0D47A1),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0A2D6E), Color(0xFF1565C0)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SafeArea(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 2),
                        ),
                        child: const Icon(
                          Icons.account_balance,
                          color: Colors.white,
                          size: 38,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Obx(() => Text(
                        ctrl.authorityName.value.isNotEmpty
                            ? ctrl.authorityName.value
                            : (auth.userName.value ?? 'Autorité'),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      )),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12)),
                        child: Obx(() => Text(
                          ctrl.authorityType.value.isNotEmpty
                              ? ctrl.authorityType.value
                              : 'Autorité compétente',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500),
                        )),
                      ),
                    ]),
              ),
            ),
          ),
        ),

        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Obx(() => Row(children: [
                Expanded(
                    child: _MiniStat('Total',
                        '${ctrl.totalAssigned.value}', Colors.blue)),
                const SizedBox(width: 10),
                Expanded(
                    child: _MiniStat('En cours',
                        '${ctrl.totalInProgress.value}', Colors.purple)),
                const SizedBox(width: 10),
                Expanded(
                    child: _MiniStat('Résolus',
                        '${ctrl.totalResolved.value}', Colors.green)),
              ])),
              const SizedBox(height: 20),

              _SettingsSection(title: 'Mon compte', items: [
                _SettingsItem(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  trailing: Obx(() => Text(auth.userEmail.value ?? '',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.grey))),
                ),
                _SettingsItem(
                  icon: Icons.phone_outlined,
                  label: 'Téléphone',
                  trailing: Obx(() => Text(
                      (auth.userPhone.value?.isNotEmpty ?? false)
                          ? auth.userPhone.value!
                          : 'Non renseigné',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.grey))),
                ),
                _SettingsItem(
                  icon: Icons.shield_outlined,
                  label: 'Rôle',
                  trailing: const Text('Autorité',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.grey)),
                ),
                _SettingsItem(
                  icon: Icons.business_outlined,
                  label: 'Entité',
                  trailing: Obx(() => Text(
                      ctrl.authorityName.value.isNotEmpty
                          ? ctrl.authorityName.value
                          : 'Non défini',
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.grey))),
                ),
              ]),
              const SizedBox(height: 16),

              _SettingsSection(title: 'Sécurité', items: [
                _SettingsItem(
                    icon: Icons.lock_outline,
                    label: 'Changer le mot de passe',
                    isAction: true,
                    onTap: () {}),
                _SettingsItem(
                    icon: Icons.notifications_outlined,
                    label: 'Notifications',
                    isAction: true,
                    onTap: () {}),
              ]),
              const SizedBox(height: 16),

              const _SettingsSection(title: 'Application', items: [
                _SettingsItem(
                  icon: Icons.info_outline,
                  label: 'Version',
                  trailing: Text('1.0.0',
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.grey)),
                ),
              ]),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await Get.dialog<bool>(AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: const Text('Déconnexion',
                          style:
                          TextStyle(fontWeight: FontWeight.bold)),
                      content: const Text(
                          'Voulez-vous vraiment vous déconnecter ?'),
                      actions: [
                        TextButton(
                            onPressed: () => Get.back(result: false),
                            child: const Text('Annuler')),
                        ElevatedButton(
                          onPressed: () => Get.back(result: true),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white),
                          child: const Text('Déconnecter'),
                        ),
                      ],
                    ));
                    if (confirm == true) {
                      await AuthService.instance.logout();
                      Get.offAllNamed(Routes.SPLASH);
                    }
                  },
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Se déconnecter',
                      style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding:
                    const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  WIDGETS RÉUTILISABLES
// ════════════════════════════════════════════════════════════════════════════

class _BlueHeader extends StatelessWidget {
  final AuthorityDashboardController ctrl;
  const _BlueHeader({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0A2D6E), Color(0xFF0D47A1), Color(0xFF1565C0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12)),
                    child: const Icon(
                      Icons.account_balance_outlined,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Obx(() => Text(
                            ctrl.authorityName.value.isNotEmpty
                                ? ctrl.authorityName.value
                                : 'Autorité',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.bold),
                          )),
                          Obx(() => Text(
                            ctrl.authorityType.value.isNotEmpty
                                ? ctrl.authorityType.value
                                : 'Tableau de bord',
                            style: TextStyle(
                                color: Colors.white.withOpacity(0.7),
                                fontSize: 11),
                          )),
                        ]),
                  ),
                  Obx(() => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(children: [
                      const Icon(
                        Icons.assignment,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text('${ctrl.totalAssigned.value}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    ]),
                  )),
                ]),
              ]),
        ),
      ),
    );
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
          gradient: const LinearGradient(
              colors: [Colors.orange, Color(0xFFFF8C00)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.orange.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle),
            child: const Icon(Icons.pending_actions,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count signalement${count > 1 ? 's' : ''} en attente',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  const Text('Toucher pour les traiter',
                      style: TextStyle(
                          color: Colors.white70, fontSize: 11)),
                ]),
          ),
          const Icon(Icons.arrow_forward_ios,
              color: Colors.white70, size: 14),
        ]),
      ),
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final int totalAssigned, resolved, resolvedToday;
  const _PeriodCard({
    required this.totalAssigned,
    required this.resolved,
    required this.resolvedToday,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF0A2D6E), Color(0xFF1565C0)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF1565C0).withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 6))
        ],
      ),
      child: Row(children: [
        _PStat('Reçus', '$totalAssigned', Icons.assignment_outlined),
        Container(width: 1, height: 50,
            color: Colors.white.withOpacity(0.25),
            margin: const EdgeInsets.symmetric(horizontal: 8)),
        _PStat('Résolus', '$resolved', Icons.check_circle_outline),
        Container(width: 1, height: 50,
            color: Colors.white.withOpacity(0.25),
            margin: const EdgeInsets.symmetric(horizontal: 8)),
        _PStat("Aujourd'hui", '$resolvedToday', Icons.today_outlined),
      ]),
    );
  }
}

class _PStat extends StatelessWidget {
  final String label, value;
  final IconData icon;
  const _PStat(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: Colors.white70, fontSize: 9, height: 1.3)),
      ]),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int total, pending, inProgress, resolved;
  const _StatsGrid({
    required this.total,
    required this.pending,
    required this.inProgress,
    required this.resolved,
  });

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(
            child: _StatCard('Total reçus', '$total',
                Icons.assignment_outlined, const Color(0xFF1565C0))),
        const SizedBox(width: 12),
        Expanded(
            child: _StatCard('En attente', '$pending',
                Icons.pending_outlined, Colors.orange)),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
            child: _StatCard('En cours', '$inProgress',
                Icons.hourglass_bottom_outlined, Colors.purple)),
        const SizedBox(width: 12),
        Expanded(
            child: _StatCard('Résolus', '$resolved',
                Icons.check_circle_outline, Colors.green)),
      ]),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _StatCard(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 3))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: AppTheme.grey,
                fontWeight: FontWeight.w500)),
      ]),
    );
  }
}

class _RoutingMiniCard extends StatelessWidget {
  final Map<String, dynamic> routing;
  const _RoutingMiniCard({required this.routing});

  @override
  Widget build(BuildContext context) {
    final status   = (routing['status'] as String?) ?? 'pending';
    final rep      = routing['report'] as Map?;
    final title    = rep?['title']        as String? ?? 'Signalement';
    final severity = rep?['severity']     as String? ?? 'low';
    final commune  = rep?['commune_name'] as String? ?? '';
    final _cat = rep?['category'];
    final category = _cat is Map ? (_cat['name'] as String? ?? '') : (_cat as String? ?? '');    final statusClr = AuthorityDashboardController.statusColor(status);
    final sevClr    = AuthorityDashboardController.severityColor(severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 4, height: 48,
          decoration: BoxDecoration(
              color: sevClr, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(
                    '$commune${category.isNotEmpty ? ' · $category' : ''}',
                    style:
                    TextStyle(fontSize: 11, color: Colors.grey[500]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]),
        ),
        _Chip(
            label: AuthorityDashboardController.statusLabel(status),
            color: statusClr),
      ]),
    );
  }
}

class _NoAgentBanner extends StatelessWidget {
  final VoidCallback onAddAgent;
  const _NoAgentBanner({required this.onAddAgent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_outlined,
            color: Colors.orange, size: 16),
        const SizedBox(width: 8),
        const Expanded(
          child: Text('Aucun agent disponible',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.orange,
                  fontWeight: FontWeight.w600)),
        ),
        GestureDetector(
          onTap: onAddAgent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(6)),
            child: const Text('+ Agent',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ),
        ),
      ]),
    );
  }
}

class _EmptyAgentsPage extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyAgentsPage({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.groups_outlined, size: 80, color: Colors.grey[200]),
            const SizedBox(height: 16),
            Text('Aucun agent assigné',
                style: TextStyle(
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
            const SizedBox(height: 8),
            Text('Ajoutez des agents pour gérer vos signalements',
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.person_add),
              label: const Text('Ajouter un agent'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ]),
    );
  }
}

class _AgentStatBadge extends StatelessWidget {
  final String label, value;
  final Color color;
  const _AgentStatBadge(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10)),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color)),
          Text(label,
              style: const TextStyle(
                  fontSize: 9, color: Colors.white70)),
        ]),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final String? Function(String?)? validator;
  const _FormField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFF1565C0)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
          const BorderSide(color: Color(0xFF1565C0), width: 2),
        ),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        labelStyle: TextStyle(fontSize: 13, color: Colors.grey[600]),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;
  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey[500],
                letterSpacing: 0.5)),
      ),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          children: items.asMap().entries.map((e) {
            final isLast = e.key == items.length - 1;
            return Column(children: [
              e.value,
              if (!isLast)
                Divider(
                    height: 1,
                    color: Colors.grey.withOpacity(0.08),
                    indent: 52),
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
  const _SettingsItem({
    required this.icon,
    required this.label,
    this.trailing,
    this.isAction = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: const Color(0xFF1565C0).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: const Color(0xFF1565C0), size: 18),
      ),
      title: Text(label,
          style:
          const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
      trailing: trailing ??
          (isAction
              ? const Icon(Icons.chevron_right,
              color: AppTheme.grey, size: 18)
              : null),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppTheme.grey)),
      ]),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6)),
      child: Text(label,
          style: TextStyle(
              fontSize: 9,
              color: color,
              fontWeight: FontWeight.bold)),
    );
  }
}

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
          Icon(icon, size: 72, color: Colors.grey[200]),
          const SizedBox(height: 14),
          Text(message,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey[400], fontSize: 14, height: 1.5)),
        ]),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.cloud_off_outlined, size: 72, color: Colors.grey[200]),
          const SizedBox(height: 16),
          const Text('Impossible de charger le dashboard',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Vérifiez votre connexion et réessayez.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
        ]),
      ),
    );
  }
}