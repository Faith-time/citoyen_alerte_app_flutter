import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/services/dashboard_service.dart';
import 'package:citoyen_alerte_app_backup/core/services/auth_service.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/core/theme/neo_kit.dart';
import 'package:citoyen_alerte_app_backup/data/models/dashboard_model.dart';
import 'package:citoyen_alerte_app_backup/data/models/intervention_model.dart';
import 'package:citoyen_alerte_app_backup/core/services/intervention_service.dart';
import 'package:citoyen_alerte_app_backup/routes/app_pages.dart';
import 'package:citoyen_alerte_app_backup/presentation/widgets/resolution_photo_sheet.dart';
import 'package:url_launcher/url_launcher.dart';

// ════════════════════════════════════════════════════════════════════════════
//  CONTROLLER — logique inchangée
// ════════════════════════════════════════════════════════════════════════════

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
      );

  String _statusString(InterventionStatus s) => switch (s) {
    InterventionStatus.pending    => 'pending',
    InterventionStatus.inProgress => 'in_progress',
    InterventionStatus.completed  => 'completed',
    InterventionStatus.cancelled  => 'cancelled',
  };
}

Color _statusColor(InterventionStatus s) => switch (s) {
  InterventionStatus.pending    => Neo.warning,
  InterventionStatus.inProgress => Neo.info,
  InterventionStatus.completed  => Neo.success,
  InterventionStatus.cancelled  => Neo.danger,
};

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
      backgroundColor: Neo.bg,
      body: NeoBackdrop(
        child: Obx(() => IndexedStack(
          index: ctrl.currentIndex.value,
          children: const [_AgentHomePage(), _AgentKanbanPage(), _AgentProfilePage()],
        )),
      ),
      bottomNavigationBar: Obx(() => NeoBottomNav(
        index: ctrl.currentIndex.value,
        onChanged: ctrl.changePage,
        items: const [
          NeoNavItem(Icons.home_outlined, Icons.home_rounded, 'Accueil'),
          NeoNavItem(Icons.view_kanban_outlined, Icons.view_kanban_rounded, 'Interventions'),
          NeoNavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
        ],
      )),
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
      color: Neo.blue,
      child: Obx(() {
        if (ctrl.isLoading && ctrl.data == null) {
          return ListView(children: const [SizedBox(height: 240), NeoLoading()]);
        }
        if (ctrl.error.isNotEmpty && ctrl.data == null) {
          return ListView(children: [const SizedBox(height: 120), NeoError(onRetry: ctrl.refresh)]);
        }
        final authName = ctrl.data?.authorityName ?? '';
        final todo = ctrl.pending.length + ctrl.inProgress.length;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: EdgeInsets.zero,
          children: [
            NeoGreetingHeader(name: ctrl.agentName),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                NeoReveal(
                  child: NeoHero(
                    icon: Icons.build_circle_outlined,
                    title: todo == 0 ? 'Aucune intervention en cours' : '$todo intervention${todo > 1 ? 's' : ''} à traiter',
                    subtitle: authName.isNotEmpty ? authName : 'Dashboard Agent',
                    buttonLabel: 'Voir mes interventions',
                    onTap: () => ctrl.changePage(1),
                  ),
                ),
                const SizedBox(height: 18),
                NeoReveal(
                  delayMs: 60,
                  child: NeoStatsStrip(items: [
                    NeoStat('${ctrl.pending.length}', 'En attente', Neo.warning),
                    NeoStat('${ctrl.inProgress.length}', 'En cours', Neo.info),
                    NeoStat('${ctrl.completed.length}', 'Terminées', Neo.success),
                  ]),
                ),
                const SizedBox(height: 18),
                NeoReveal(delayMs: 100, child: _TodayCard(resolved: ctrl.data?.completedToday ?? 0)),
                const SizedBox(height: 22),
                NeoSectionTitle('Mes interventions', icon: Icons.view_kanban_outlined, action: 'Voir tout', onAction: () => ctrl.changePage(1)),
                const SizedBox(height: 12),
                _KanbanPreview(ctrl: ctrl),
              ]),
            ),
          ],
        );
      }),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final int resolved;
  const _TodayCard({required this.resolved});

  @override
  Widget build(BuildContext context) {
    return NeoCard(
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Aujourd'hui", style: Neo.t(12, c: Neo.muted)),
            const SizedBox(height: 4),
            Text('$resolved résolu${resolved > 1 ? 's' : ''}', style: Neo.t(22, w: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(resolved == 0 ? "Aucune intervention terminée aujourd'hui" : 'Excellent travail !',
                style: Neo.t(12, c: Neo.muted, h: 1.4)),
          ]),
        ),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: Neo.heroGradient,
            boxShadow: [BoxShadow(color: Neo.blue.withOpacity(0.35), blurRadius: 14, offset: const Offset(0, 6))],
          ),
          child: Center(child: Text('$resolved', style: Neo.t(26, w: FontWeight.w700, c: Colors.white))),
        ),
      ]),
    );
  }
}

class _KanbanPreview extends StatelessWidget {
  final AgentDashboardController ctrl;
  const _KanbanPreview({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (ctrl.isLoadingKanban.value) {
        return const Padding(padding: EdgeInsets.all(24), child: NeoLoading());
      }
      final all = [...ctrl.pending, ...ctrl.inProgress, ...ctrl.completed, ...ctrl.cancelled].take(3).toList();
      if (all.isEmpty) {
        return const NeoCard(
          child: NeoEmpty(
            icon: Icons.inbox_outlined,
            title: 'Aucune intervention',
            message: 'Les interventions qui vous sont assignées apparaîtront ici.',
          ),
        );
      }
      return Column(children: all.map((i) => _InterventionMiniCard(item: i)).toList());
    });
  }
}

class _InterventionMiniCard extends StatelessWidget {
  final InterventionModel item;
  const _InterventionMiniCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(item.status);
    return NeoListCard(
      icon: Icons.build_outlined,
      color: color,
      title: item.reportTitle ?? 'Intervention #${item.id}',
      subtitle: item.authorityName,
      meta: item.reportReference,
      pill: NeoPill(label: item.status.label, color: color),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
//  PAGE 2 — KANBAN
// ════════════════════════════════════════════════════════════════════════════

class _AgentKanbanPage extends StatelessWidget {
  const _AgentKanbanPage();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AgentDashboardController>();

    return Column(children: [
      NeoTitleBar(
        title: 'Mes interventions',
        subtitle: 'Glissez une carte pour changer son statut',
        actions: [NeoIconButton(icon: Icons.refresh_rounded, onTap: ctrl.fetchKanban)],
      ),
      const SizedBox(height: 10),
      Expanded(
        child: Obx(() {
          if (ctrl.isLoadingKanban.value) return const NeoLoading();
          if (ctrl.kanbanError.isNotEmpty) return NeoError(onRetry: ctrl.fetchKanban);

          return LayoutBuilder(builder: (context, constraints) {
            const double colWidth = 250;
            return RefreshIndicator(
              onRefresh: ctrl.fetchKanban,
              color: Neo.blue,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: SizedBox(
                  height: constraints.maxHeight - 20,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _KanbanColumn(title: 'En attente', icon: Icons.pending_outlined, color: Neo.warning,
                        colWidth: colWidth, items: ctrl.pending, targetStatus: InterventionStatus.pending, ctrl: ctrl),
                    const SizedBox(width: 12),
                    _KanbanColumn(title: 'En cours', icon: Icons.play_circle_outline, color: Neo.info,
                        colWidth: colWidth, items: ctrl.inProgress, targetStatus: InterventionStatus.inProgress, ctrl: ctrl),
                    const SizedBox(width: 12),
                    _KanbanColumn(title: 'Terminé', icon: Icons.check_circle_outline, color: Neo.success,
                        colWidth: colWidth, items: ctrl.completed, targetStatus: InterventionStatus.completed, ctrl: ctrl),
                    const SizedBox(width: 4),
                  ]),
                ),
              ),
            );
          });
        }),
      ),
    ]);
  }
}

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
        final hovered = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: colWidth,
          decoration: BoxDecoration(
            color: hovered ? color.withOpacity(0.10) : Neo.inset.withOpacity(0.7),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: hovered ? color.withOpacity(0.55) : Colors.white.withOpacity(0.7), width: hovered ? 2 : 1),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
              child: Row(children: [
                NeoIconBadge(icon: icon, color: color, size: 32),
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: Neo.t(13.5, w: FontWeight.w700, c: color))),
                Obx(() => Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(10)),
                  child: Text('${items.length}', textAlign: TextAlign.center, style: Neo.t(11.5, w: FontWeight.w700, c: color)),
                )),
              ]),
            ),
            Expanded(
              child: Obx(() => items.isEmpty
                  ? _EmptyColumnHint(color: color, hovered: hovered)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 10),
                      itemCount: items.length,
                      itemBuilder: (_, i) => _DraggableCard(item: items[i], color: color),
                    )),
            ),
          ]),
        );
      },
    );
  }
}

class _DraggableCard extends StatelessWidget {
  final InterventionModel item;
  final Color color;
  const _DraggableCard({required this.item, required this.color});

  @override
  Widget build(BuildContext context) {
    return Draggable<InterventionModel>(
      data: item,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 226, child: _CardContent(item: item, color: color)),
      ),
      childWhenDragging: Opacity(
        opacity: 0.35,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: _CardContent(item: item, color: color),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: _CardContent(item: item, color: color),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  final InterventionModel item;
  final Color color;
  const _CardContent({required this.item, required this.color});

  Future<void> _openDirections() async {
    if (!item.hasLocation) return;
    final lat = item.reportLatitude;
    final lng = item.reportLongitude;
    final uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return NeoCard(
      radius: 18,
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          NeoIconBadge(icon: Icons.build_outlined, color: color, size: 30),
          const SizedBox(width: 8),
          Expanded(
            child: Text(item.reportTitle ?? 'Intervention #${item.id}',
                maxLines: 2, overflow: TextOverflow.ellipsis, style: Neo.t(12.5, w: FontWeight.w700)),
          ),
        ]),
        if (item.authorityName != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.account_balance_outlined, size: 11, color: Neo.muted),
            const SizedBox(width: 4),
            Expanded(child: Text(item.authorityName!, overflow: TextOverflow.ellipsis, style: Neo.t(10.5, w: FontWeight.w600, c: Neo.muted))),
          ]),
        ],
        if (item.reportReference != null) ...[
          const SizedBox(height: 3),
          Text(item.reportReference!, style: Neo.t(9.5, c: Neo.muted)),
        ],
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.location_on_outlined, size: 12, color: Neo.muted),
          const SizedBox(width: 4),
          Expanded(child: Text(item.locationLabel, maxLines: 2, overflow: TextOverflow.ellipsis, style: Neo.t(10.5, c: Neo.muted, h: 1.3))),
        ]),
        const SizedBox(height: 10),
        if (item.hasLocation)
          NeoPressable(
            onTap: _openDirections,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(color: Neo.info.withOpacity(0.10), borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.directions_rounded, size: 15, color: Neo.info),
                const SizedBox(width: 5),
                Text('Itinéraire', style: Neo.t(11, w: FontWeight.w700, c: Neo.info)),
              ]),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(color: Neo.warning.withOpacity(0.10), borderRadius: BorderRadius.circular(10)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.warning_amber_rounded, size: 12, color: Neo.warning),
              const SizedBox(width: 4),
              Text('Coordonnées manquantes', style: Neo.t(9.5, w: FontWeight.w600, c: Neo.warning)),
            ]),
          ),
        if (item.notes != null && item.notes!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(item.notes!, maxLines: 2, overflow: TextOverflow.ellipsis, style: Neo.t(11, c: Neo.muted)),
        ],
        if (item.createdAt != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.access_time, size: 10, color: Neo.muted),
            const SizedBox(width: 4),
            Text(_fmt(item.createdAt!), style: Neo.t(10, c: Neo.muted)),
          ]),
        ],
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.drag_indicator, size: 14, color: Neo.line.withOpacity(1)),
          const SizedBox(width: 4),
          Text('Glisser pour changer', style: Neo.t(9, c: Neo.muted)),
        ]),
      ]),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

class _EmptyColumnHint extends StatelessWidget {
  final Color color;
  final bool hovered;
  const _EmptyColumnHint({required this.color, required this.hovered});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      padding: const EdgeInsets.symmetric(vertical: 26),
      decoration: BoxDecoration(
        color: hovered ? color.withOpacity(0.08) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hovered ? color.withOpacity(0.45) : Neo.line),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.inbox_outlined, size: 28, color: hovered ? color.withOpacity(0.6) : Neo.line),
        const SizedBox(height: 6),
        Text(hovered ? 'Déposer ici' : 'Vide',
            style: Neo.t(11, w: hovered ? FontWeight.w600 : FontWeight.w400, c: hovered ? color : Neo.muted)),
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

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 28),
      children: [
        NeoReveal(
          child: Column(children: [
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Neo.surface,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: Neo.relief(),
              ),
              child: const Icon(Icons.person_rounded, size: 50, color: Neo.blue),
            ),
            const SizedBox(height: 14),
            Obx(() => Text(auth.userName.value ?? 'Agent', style: Neo.t(21, w: FontWeight.w700))),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
              const NeoPill(label: 'Agent', color: Neo.blue),
              Obx(() {
                final n = ctrl.data?.authorityName;
                if (n == null || n.isEmpty) return const SizedBox.shrink();
                return NeoPill(label: n, color: Neo.info);
              }),
            ]),
          ]),
        ),
        const SizedBox(height: 22),
        NeoReveal(
          delayMs: 60,
          child: Obx(() => NeoStatsStrip(items: [
                NeoStat('${ctrl.pending.length + ctrl.inProgress.length + ctrl.completed.length}', 'Total'),
                NeoStat('${ctrl.inProgress.length}', 'En cours', Neo.info),
                NeoStat('${ctrl.completed.length}', 'Terminées', Neo.success),
              ])),
        ),
        const SizedBox(height: 20),
        NeoReveal(
          delayMs: 100,
          child: NeoGroup(title: 'INFORMATIONS', children: [
            NeoRow(icon: Icons.email_outlined, label: 'Email', value: auth.userEmail.value ?? ''),
            NeoRow(
              icon: Icons.phone_outlined,
              label: 'Téléphone',
              value: (auth.userPhone.value?.isNotEmpty ?? false) ? auth.userPhone.value! : 'Non renseigné',
            ),
          ]),
        ),
        const SizedBox(height: 16),
        NeoReveal(
          delayMs: 140,
          child: NeoGroup(title: 'COMPTE', children: [
            NeoRow(icon: Icons.lock_outline_rounded, label: 'Changer le mot de passe', onTap: () {}),
          ]),
        ),
        const SizedBox(height: 24),
        NeoLogoutButton(onTap: () async {
          final ok = await neoConfirm(context,
              title: 'Déconnexion', message: 'Voulez-vous vraiment vous déconnecter ?', confirm: 'Déconnecter');
          if (!ok) return;
          await Future.delayed(const Duration(milliseconds: 250));
          await AuthService.instance.logout();
          Get.offAllNamed(Routes.SPLASH);
        }),
      ],
    );
  }
}
