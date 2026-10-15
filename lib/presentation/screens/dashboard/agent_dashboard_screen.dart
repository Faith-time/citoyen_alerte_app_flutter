import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/services/dashboard_service.dart';
import 'package:citoyen_alerte_app_backup/core/services/auth_service.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/data/models/dashboard_model.dart';
import 'package:citoyen_alerte_app_backup/data/models/intervention_model.dart';
import 'package:citoyen_alerte_app_backup/core/services/intervention_service.dart';
import 'package:citoyen_alerte_app_backup/routes/app_pages.dart';
import 'package:citoyen_alerte_app_backup/presentation/widgets/resolution_photo_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

class AgentDashboardController extends GetxController {
  final DashboardService _dashService = Get.find<DashboardService>();
  final ApiService _api = Get.find<ApiService>();

  final currentIndex = 0.obs;

  final pending    = <InterventionModel>[].obs;
  final inProgress = <InterventionModel>[].obs;
  final completed  = <InterventionModel>[].obs;
  final cancelled  = <InterventionModel>[].obs;

  final isLoadingKanban = false.obs;
  final kanbanError     = ''.obs;

  AgentDashboardModel? get data      => _dashService.agentDashboard.value;
  bool                 get isLoading => _dashService.isLoadingAgent.value;
  String               get error     => _dashService.agentError.value;

  String get agentName {
    final n = AuthService.instance.userName.value;
    return (n != null && n.isNotEmpty) ? n : 'Agent';
  }

  @override
  void onInit() {
    super.onInit();
    _dashService.fetchAgentDashboard();
    fetchKanban();
  }

  Future<void> refresh() async =>
      Future.wait([_dashService.fetchAgentDashboard(), fetchKanban()]);

  void changePage(int i) => currentIndex.value = i;

  Future<void> fetchKanban() async {
    isLoadingKanban.value = true;
    kanbanError.value     = '';
    try {
      final list = await InterventionService.instance.getMine();
      _distribute(list);
    } catch (e) {
      kanbanError.value = e.toString();
    } finally {
      isLoadingKanban.value = false;
    }
  }

  void _distribute(List<InterventionModel> list) {
    pending.assignAll(list.where((i) => i.status == InterventionStatus.pending));
    inProgress.assignAll(list.where((i) => i.status == InterventionStatus.inProgress));
    completed.assignAll(list.where((i) => i.status == InterventionStatus.completed));
    cancelled.assignAll(list.where((i) => i.status == InterventionStatus.cancelled));
  }

  Future<void> moveCard(InterventionModel item, InterventionStatus newStatus) async {
    // Si on termine l'intervention, on exige d'abord une photo "après" —
    // c'est elle qui s'affichera côté citoyen dans Actualités.
    if (newStatus == InterventionStatus.completed &&
        item.status != InterventionStatus.completed) {
      final photoConfirmed = await showResolutionPhotoSheet(reportId: item.reportId);
      if (!photoConfirmed) return;
    }

    _removeFromAll(item);
    final updated = _withStatus(item, newStatus);
    _addToColumn(updated);
    try {
      final resp = await _api.put('/interventions/${item.id}/status',
          data: {'status': _statusString(newStatus)});
      if (!resp.success) {
        _removeFromAll(updated);
        _addToColumn(item);
        Get.snackbar('Erreur', resp.message ?? 'Mise à jour échouée',
            backgroundColor: AppTheme.error, colorText: Colors.white,
            snackPosition: SnackPosition.BOTTOM);
      }
    } catch (_) {
      _removeFromAll(updated);
      _addToColumn(item);
    }
  }

  void _removeFromAll(InterventionModel item) {
    for (final col in [pending, inProgress, completed, cancelled]) {
      col.removeWhere((i) => i.id == item.id);
    }
  }

  void _addToColumn(InterventionModel item) {
    switch (item.status) {
      case InterventionStatus.pending:    pending.add(item);    break;
      case InterventionStatus.inProgress: inProgress.add(item); break;
      case InterventionStatus.completed:  completed.add(item);  break;
      case InterventionStatus.cancelled:  cancelled.add(item);  break;
    }
  }

  InterventionModel _withStatus(InterventionModel item, InterventionStatus s) =>
      InterventionModel(
        id: item.id, reportId: item.reportId, agentId: item.agentId,
        authorityId: item.authorityId, status: s, notes: item.notes,
        createdAt: item.createdAt, completedAt: item.completedAt,
        reportTitle: item.reportTitle,
        reportReference: item.reportReference,
        authorityName: item.authorityName,
        reportAddress: item.reportAddress,
        reportCommune: item.reportCommune,
        reportRegion: item.reportRegion,
        reportLatitude: item.reportLatitude,
        reportLongitude: item.reportLongitude,
      );  String _statusString(InterventionStatus s) => switch (s) {
    InterventionStatus.pending    => 'pending',
    InterventionStatus.inProgress => 'in_progress',
    InterventionStatus.completed  => 'completed',
    InterventionStatus.cancelled  => 'cancelled',
  };
}

// ════════════════════════════════════════════════════════════════════════════
//  SCREEN PRINCIPAL
// ════════════════════════════════════════════════════════════════════════════

class AgentDashboardScreen extends StatelessWidget {
  const AgentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (!Get.isRegistered<InterventionService>()) Get.put(InterventionService());
    final ctrl = Get.put(AgentDashboardController(), permanent: false);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Obx(() => IndexedStack(
        index: ctrl.currentIndex.value,
        children: const [_AgentHomePage(), _AgentKanbanPage(), _AgentProfilePage()],
      )),
      bottomNavigationBar: Obx(() => _AgentBottomNav(
        currentIndex: ctrl.currentIndex.value,
        onTap: ctrl.changePage,
      )),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  BOTTOM NAV
// ════════════════════════════════════════════════════════════════════════════

class _AgentBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _AgentBottomNav({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const items = [
      _NavItem(icon: Icons.dashboard_outlined,  activeIcon: Icons.dashboard,   label: 'Accueil'),
      _NavItem(icon: Icons.view_kanban_outlined, activeIcon: Icons.view_kanban, label: 'Interventions'),
      _NavItem(icon: Icons.person_outline,       activeIcon: Icons.person,      label: 'Profil'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(
            color: AppTheme.darkBlue.withOpacity(0.08), blurRadius: 20,
            offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(children: items.asMap().entries.map((e) {
            final i = e.key; final item = e.value;
            final isActive = currentIndex == i;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: isActive ? AppTheme.primaryGreen.withOpacity(0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(isActive ? item.activeIcon : item.icon,
                        color: isActive ? AppTheme.primaryGreen : AppTheme.greyMedium, size: 22),
                  ),
                  const SizedBox(height: 2),
                  Text(item.label, style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    color: isActive ? AppTheme.primaryGreen : AppTheme.greyMedium,
                  )),
                ]),
              ),
            );
          }).toList()),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PAGE 1 — ACCUEIL
// ════════════════════════════════════════════════════════════════════════════

class _AgentHomePage extends StatelessWidget {
  const _AgentHomePage();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AgentDashboardController>();

    return RefreshIndicator(
      onRefresh: ctrl.refresh,
      color: AppTheme.primaryGreen,
      child: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: _AgentHeader(ctrl: ctrl)),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
          sliver: Obx(() {
            if (ctrl.isLoading && ctrl.data == null) {
              return const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
              );
            }
            if (ctrl.error.isNotEmpty && ctrl.data == null) {
              return SliverFillRemaining(child: _ErrorState(onRetry: ctrl.refresh));
            }
            return SliverList(
              delegate: SliverChildListDelegate([
                _StatsGrid(ctrl: ctrl),
                const SizedBox(height: 20),
                _TodayCard(ctrl: ctrl),
                const SizedBox(height: 20),
                _KanbanPreview(ctrl: ctrl),
                const SizedBox(height: 40),
              ]),
            );
          }),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  HEADER — identité Sénégal (motif + bandeau drapeau)
// ════════════════════════════════════════════════════════════════════════════

class _AgentHeader extends StatelessWidget {
  final AgentDashboardController ctrl;
  const _AgentHeader({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(AppTheme.radiusXl),
            bottomRight: Radius.circular(AppTheme.radiusXl),
          ),
          child: Container(
            height: 170,   // au lieu de constraints: const BoxConstraints(minHeight: 170),
            decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
            child: const SenegalPatternBackground(),
          ),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(AppTheme.radiusXl),
              bottomRight: Radius.circular(AppTheme.radiusXl),
            ),
            child: const FlagStripe(),
          ),
        ),
        SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.25))),
                child: const Icon(Icons.shield_outlined, color: AppTheme.yellow, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Dashboard Agent',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: Colors.white, fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Obx(() => Text('Bonjour, ${ctrl.agentName} !',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: Colors.white.withOpacity(0.85), fontSize: 13))),
                  const SizedBox(height: 6),
                  Obx(() {
                    final authName = ctrl.data?.authorityName;
                    if (authName == null || authName.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.yellow.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppTheme.yellow.withOpacity(0.4)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.account_balance_outlined,
                            size: 11, color: AppTheme.yellow),
                        const SizedBox(width: 5),
                        Text(authName,
                            style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: AppTheme.yellow,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ]),
                    );
                  }),
                ],
              )),
              Obx(() => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(16)),
                child: Column(children: [
                  const Icon(Icons.build_circle_outlined, color: Colors.white, size: 16),
                  const SizedBox(height: 2),
                  Text('${ctrl.data?.totalInterventions ?? 0}',
                      style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: Colors.white,
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text('total', style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      color: Colors.white.withOpacity(0.7), fontSize: 9)),
                ]),
              )),
            ]),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  STATS GRID
// ════════════════════════════════════════════════════════════════════════════

class _StatsGrid extends StatelessWidget {
  final AgentDashboardController ctrl;
  const _StatsGrid({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(children: [
        Expanded(child: Obx(() => StatTile(
            label: 'En attente', value: '${ctrl.pending.length}',
            icon: Icons.pending_outlined, color: AppTheme.warning))),
        const SizedBox(width: 12),
        Expanded(child: Obx(() => StatTile(
            label: 'En cours', value: '${ctrl.inProgress.length}',
            icon: Icons.play_circle_outline, color: AppTheme.info))),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Obx(() => StatTile(
            label: 'Terminées', value: '${ctrl.completed.length}',
            icon: Icons.check_circle_outline, color: AppTheme.success))),
      ]),
    ]);
  }
}


class _TodayCard extends StatelessWidget {
  final AgentDashboardController ctrl;
  const _TodayCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final c = ctrl.data?.completedToday ?? 0;
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppTheme.ctaGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.elevatedShadow(AppTheme.primaryGreen),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("Aujourd'hui",
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: Colors.white70, fontSize: 13,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text('$c résolu${c > 1 ? 's' : ''}',
                style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: Colors.white, fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(c == 0 ? "Aucune intervention terminée aujourd'hui" : 'Excellent travail !',
                style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: Colors.white70, fontSize: 12, height: 1.4)),
          ])),
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
                color: AppTheme.yellow.withOpacity(0.22), shape: BoxShape.circle,
                border: Border.all(color: AppTheme.yellow.withOpacity(0.4), width: 1.5)),
            child: Center(child: Text('$c',
                style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    color: AppTheme.yellow, fontSize: 28,
                    fontWeight: FontWeight.bold))),
          ),
        ]),
      );
    });
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  KANBAN PREVIEW (home)
// ════════════════════════════════════════════════════════════════════════════

class _KanbanPreview extends StatelessWidget {
  final AgentDashboardController ctrl;
  const _KanbanPreview({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.view_kanban_outlined, size: 18, color: AppTheme.primaryGreen),
        const SizedBox(width: 8),
        const Expanded(child: Text('Mes Interventions', style: AppTheme.h3)),
        TextButton(
          onPressed: () => ctrl.changePage(1),
          child: const Text('Voir tout',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: AppTheme.primaryGreen, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ]),
      const SizedBox(height: 10),
      Obx(() {
        if (ctrl.isLoadingKanban.value) {
          return const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen));
        }
        final all = [
          ...ctrl.pending, ...ctrl.inProgress,
          ...ctrl.completed, ...ctrl.cancelled,
        ].take(3).toList();
        if (all.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                boxShadow: AppTheme.cardShadow()),
            child: const Center(child: Text('Aucune intervention assignée',
                style: AppTheme.body)),
          );
        }
        return Column(
            children: all.map((i) => _InterventionMiniCard(item: i)).toList());
      }),
    ]);
  }
}

// ── Mini-card aperçu ──────────────────────────────────────────────────────

class _InterventionMiniCard extends StatelessWidget {
  final InterventionModel item;
  const _InterventionMiniCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(item.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.cardShadow(),
        border: Border.all(color: AppTheme.greyLight.withOpacity(0.7)),
      ),
      child: Row(children: [
        Container(width: 4, height: 52,
            decoration: BoxDecoration(color: color,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.reportTitle ?? 'Intervention #${item.id}',
              style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 13, color: AppTheme.darkBlue),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            if (item.authorityName != null) ...[
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.account_balance_outlined,
                    size: 11, color: AppTheme.greyMedium),
                const SizedBox(width: 4),
                Expanded(child: Text(item.authorityName!,
                    style: AppTheme.caption,
                    overflow: TextOverflow.ellipsis)),
              ]),
            ],
          ],
        )),
        const SizedBox(width: 8),
        StatusPill(label: item.status.label, color: color),
      ]),
    );
  }

  Color _statusColor(InterventionStatus s) => switch (s) {
    InterventionStatus.pending    => AppTheme.warning,
    InterventionStatus.inProgress => AppTheme.info,
    InterventionStatus.completed  => AppTheme.success,
    InterventionStatus.cancelled  => AppTheme.error,
  };
}

// ════════════════════════════════════════════════════════════════════════════
//  PAGE 2 — KANBAN
// ════════════════════════════════════════════════════════════════════════════

class _AgentKanbanPage extends StatelessWidget {
  const _AgentKanbanPage();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AgentDashboardController>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(children: [
        SectionHeader(
          title: 'Mes Interventions',
          height: 78,
          leading: const Icon(Icons.view_kanban, color: Colors.white, size: 22),
          trailing: IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: ctrl.fetchKanban,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ),
        Expanded(
          child: Obx(() {
            if (ctrl.isLoadingKanban.value) {
              return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryGreen));
            }
            if (ctrl.kanbanError.isNotEmpty) {
              return _ErrorState(onRetry: ctrl.fetchKanban);
            }

            return LayoutBuilder(builder: (context, constraints) {
              const double colWidth = 240;
              return RefreshIndicator(
                onRefresh: ctrl.fetchKanban,
                color: AppTheme.primaryGreen,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    height: constraints.maxHeight - 24,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _KanbanColumn(title: 'En attente',
                            icon: Icons.pending_outlined, color: AppTheme.warning,
                            colWidth: colWidth, items: ctrl.pending,
                            targetStatus: InterventionStatus.pending, ctrl: ctrl),
                        const SizedBox(width: 10),
                        _KanbanColumn(title: 'En cours',
                            icon: Icons.play_circle_outline, color: AppTheme.info,
                            colWidth: colWidth, items: ctrl.inProgress,
                            targetStatus: InterventionStatus.inProgress, ctrl: ctrl),
                        const SizedBox(width: 10),
                        _KanbanColumn(title: 'Terminé',
                            icon: Icons.check_circle_outline, color: AppTheme.success,
                            colWidth: colWidth, items: ctrl.completed,
                            targetStatus: InterventionStatus.completed, ctrl: ctrl),
                        const SizedBox(width: 10),
                      ],
                    ),
                  ),
                ),
              );
            });
          }),
        ),
      ]),
    );
  }
}

// ── Colonne kanban ────────────────────────────────────────────────────────

class _KanbanColumn extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final RxList<InterventionModel> items;
  final InterventionStatus targetStatus;
  final AgentDashboardController ctrl;
  final double colWidth;

  const _KanbanColumn({
    required this.title, required this.icon, required this.color,
    required this.items, required this.targetStatus,
    required this.ctrl, required this.colWidth,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<InterventionModel>(
      onWillAcceptWithDetails: (d) => d.data.status != targetStatus,
      onAcceptWithDetails: (d) => ctrl.moveCard(d.data, targetStatus),
      builder: (context, candidateData, _) {
        final isHovered = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: colWidth,
          decoration: BoxDecoration(
            color: isHovered ? color.withOpacity(0.06) : AppTheme.greyLight.withOpacity(0.5),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
                color: isHovered ? color.withOpacity(0.5) : Colors.transparent,
                width: 2),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8)),
                  child: Icon(icon, color: color, size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w700, fontSize: 13, color: color))),
                Obx(() => Container(
                  constraints: const BoxConstraints(minWidth: 22),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('${items.length}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.bold, color: color)),
                )),
              ]),
            ),
            Expanded(
              child: Obx(() => items.isEmpty
                  ? _EmptyColumnHint(color: color, isHovered: isHovered)
                  : ListView.builder(
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: items.length,
                itemBuilder: (_, i) =>
                    _DraggableCard(item: items[i], color: color),
              )),
            ),
          ]),
        );
      },
    );
  }
}

// ── Carte draggable ───────────────────────────────────────────────────────

class _DraggableCard extends StatelessWidget {
  final InterventionModel item;
  final Color color;
  const _DraggableCard({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    return Draggable<InterventionModel>(
      data: item,
      feedback: Material(
        elevation: 8, borderRadius: BorderRadius.circular(14),
        child: SizedBox(width: 200,
            child: _CardContent(item: item, color: color, isDragging: true)),
      ),
      childWhenDragging: Opacity(opacity: 0.35,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: _CardContent(item: item, color: color),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: _CardContent(item: item, color: color),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  final InterventionModel item;
  final Color color;
  final bool isDragging;
  const _CardContent({required this.item, required this.color,
    this.isDragging = false});

  Future<void> _openDirections() async {
    if (!item.hasLocation) return;
    final lat = item.reportLatitude;
    final lng = item.reportLongitude;
    final uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDragging ? color.withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: AppTheme.cardShadow(opacity: isDragging ? 0.15 : 0.05),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(5),

            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6)),
            child: Icon(Icons.build_outlined, size: 12, color: color),
          ),
          const SizedBox(width: 7),
          Expanded(child: Text(
            item.reportTitle ?? 'Intervention #${item.id}',
            style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w700, fontSize: 12,
                color: AppTheme.darkBlue),
            overflow: TextOverflow.ellipsis, maxLines: 2,
          )),
        ]),
        if (item.authorityName != null) ...[
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: color.withOpacity(0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.account_balance_outlined,
                  size: 10, color: color.withOpacity(0.7)),
              const SizedBox(width: 4),
              Flexible(child: Text(item.authorityName!,
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10,

                      color: color.withOpacity(0.85),
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis)),
            ]),
          ),
        ],
        if (item.reportReference != null) ...[
          const SizedBox(height: 4),
          Text(item.reportReference!,
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 9, color: AppTheme.greyMedium.withOpacity(0.7),
                  fontStyle: FontStyle.italic)),
        ],

        // ── Localisation ────────────────────────────────────────────
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.location_on_outlined, size: 12, color: AppTheme.greyMedium.withOpacity(0.8)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(item.locationLabel,
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10.5,
                    color: AppTheme.greyMedium.withOpacity(0.9),
                    height: 1.3),
                maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ]),
        if (item.hasLocation) ...[
          const SizedBox(height: 8),

          Material(
            color: AppTheme.info.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _openDirections,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.directions_rounded, size: 14, color: AppTheme.info),
                  const SizedBox(width: 5),
                  Text('Itinéraire',
                      style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.info)),
                ]),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.warning.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.warning_amber_rounded, size: 11, color: AppTheme.warning),
              const SizedBox(width: 4),

              Text('Coordonnées manquantes',
                  style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 9.5,
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ],

        if (item.notes != null && item.notes!.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(item.notes!,
              style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 11, color: AppTheme.greyMedium),
              maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
        if (item.createdAt != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.access_time, size: 10, color: AppTheme.greyMedium.withOpacity(0.7)),
            const SizedBox(width: 4),
            Text(_fmt(item.createdAt!),
                style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10, color: AppTheme.greyMedium.withOpacity(0.7))),
          ]),
        ],
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.drag_indicator, size: 14, color: AppTheme.greyLight),

          const SizedBox(width: 4),
          Text('Glisser pour changer',
              style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 9, color: AppTheme.greyMedium.withOpacity(0.7))),
        ]),
      ]),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
          '${d.month.toString().padLeft(2, '0')}/${d.year}';
}
// ── Colonne vide ──────────────────────────────────────────────────────────

class _EmptyColumnHint extends StatelessWidget {
  final Color color;
  final bool isHovered;
  const _EmptyColumnHint({required this.color, required this.isHovered});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: isHovered ? color.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isHovered ? color.withOpacity(0.4) : AppTheme.greyLight,
        ),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_outlined, size: 28,
            color: isHovered ? color.withOpacity(0.5) : AppTheme.greyLight),
        const SizedBox(height: 6),
        Text(isHovered ? 'Déposer ici' : 'Vide',
            style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 11,
                color: isHovered ? color : AppTheme.greyMedium.withOpacity(0.7),
                fontWeight: isHovered ? FontWeight.w600 : FontWeight.w400)),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PAGE 3 — PROFIL
// ════════════════════════════════════════════════════════════════════════════

class _AgentProfilePage extends StatelessWidget {
  const _AgentProfilePage();

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final ctrl = Get.find<AgentDashboardController>();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SingleChildScrollView(
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(AppTheme.radiusXl),
                    bottomRight: Radius.circular(AppTheme.radiusXl),
                  ),
                  child: Container(
                    height: 230,
                    decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
                    child: const SenegalPatternBackground(),
                  ),
                ),
                const Positioned(bottom: 0, left: 0, right: 0, child: FlagStripe()),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: Column(
                      children: [
                        Stack(alignment: Alignment.bottomRight, children: [
                          Container(
                            width: 80, height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.15),
                              border: Border.all(color: AppTheme.yellow.withOpacity(0.6), width: 2.5),
                            ),
                            child: const Icon(Icons.person_rounded, size: 38, color: Colors.white),
                          ),
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                                color: AppTheme.yellow,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2)),
                            child: const Icon(Icons.shield, color: AppTheme.darkBlue, size: 12),
                          ),
                        ]),
                        const SizedBox(height: 12),
                        Obx(() => Text(auth.userName.value ?? 'Agent',
                            style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: Colors.white, fontSize: 20,
                                fontWeight: FontWeight.bold))),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                              color: AppTheme.yellow.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.yellow.withOpacity(0.4))),
                          child: const Text('Agent',
                              style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  color: AppTheme.yellow, fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(height: 6),
                        Obx(() {
                          final authName = ctrl.data?.authorityName;
                          if (authName == null || authName.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white.withOpacity(0.4)),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.account_balance_outlined,
                                  size: 13, color: Colors.white),
                              const SizedBox(width: 6),
                              Text(authName,
                                  style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      color: Colors.white, fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ]),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Obx(() => Row(children: [
                    Expanded(child: StatTile(label: 'Total',
                        value: '${ctrl.pending.length + ctrl.inProgress.length + ctrl.completed.length}',
                        color: AppTheme.primaryGreen, icon: Icons.flag_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: StatTile(label: 'En cours',
                        value: '${ctrl.inProgress.length}', color: AppTheme.info,
                        icon: Icons.hourglass_bottom_outlined)),
                    const SizedBox(width: 10),
                    Expanded(child: StatTile(label: 'Terminées',
                        value: '${ctrl.completed.length}', color: AppTheme.success,
                        icon: Icons.check_circle_outline)),
                  ])),
                  const SizedBox(height: 20),
                  _ProfileSection(title: 'INFORMATIONS', items: [
                    _ProfileItem(icon: Icons.email_outlined, label: 'Email',
                        value: auth.userEmail.value ?? ''),
                    _ProfileItem(icon: Icons.phone_outlined, label: 'Téléphone',
                        value: (auth.userPhone.value?.isNotEmpty ?? false)
                            ? auth.userPhone.value! : 'Non renseigné'),
                  ]),
                  const SizedBox(height: 12),
                  _ProfileSection(title: 'COMPTE', items: [
                    _ProfileItem(icon: Icons.lock_outline, label: 'Changer le mot de passe',
                        value: '', isAction: true, onTap: () {}),
                  ]),

                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: () async {
                      final confirm = await Get.dialog<bool>(AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
                        title: const Text('Déconnexion', style: AppTheme.h3),
                        content: const Text('Voulez-vous vraiment vous déconnecter ?', style: AppTheme.body),
                        actions: [
                          TextButton(onPressed: () => Get.back(result: false), child: const Text('Annuler')),
                          ElevatedButton(
                            onPressed: () => Get.back(result: true),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.coral, foregroundColor: Colors.white),
                            child: const Text('Déconnecter'),
                          ),
                        ],
                      ));

                      if (confirm != true) return;

                      await Future.delayed(const Duration(milliseconds: 250)); // laisse l'animation de fermeture se terminer

                      await AuthService.instance.logout();
                      Get.offAllNamed(Routes.SPLASH);
                    },                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.coral.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.coral.withOpacity(0.4), width: 1.5),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded, color: AppTheme.coral, size: 20),
                          SizedBox(width: 8),
                          Text('Se déconnecter',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.coral,
                              )),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<_ProfileItem> items;
  const _ProfileSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title, style: AppTheme.label),
      ),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.cardShadow(),
        ),
        child: Column(children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          return Column(children: [
            e.value,
            if (!isLast) Divider(height: 1,
                color: AppTheme.greyLight.withOpacity(0.7), indent: 52),
          ]);
        }).toList()),
      ),
    ]);
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final bool isAction;
  final VoidCallback? onTap;
  const _ProfileItem({required this.icon, required this.label,
    required this.value, this.isAction = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.circle, color: Colors.transparent, size: 0),
      ),
      title: Text(label,
          style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkBlue)),
      subtitle: value.isNotEmpty
          ? Text(value, style: AppTheme.caption)
          : null,
      trailing: isAction
          ? const Icon(Icons.chevron_right, color: AppTheme.greyMedium, size: 18)
          : null,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Icon(Icons.cloud_off_outlined, size: 64, color: AppTheme.greyMedium),
        const SizedBox(height: 16),
        const Text('Erreur de chargement', textAlign: TextAlign.center, style: AppTheme.h3),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: const Text('Réessayer'),
          style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryGreen,
              foregroundColor: Colors.white),
        ),
      ]),
    ));
  }
}

class _NavItem {
  final IconData icon, activeIcon;
  final String label;
  const _NavItem({required this.icon, required this.activeIcon,
    required this.label});
}