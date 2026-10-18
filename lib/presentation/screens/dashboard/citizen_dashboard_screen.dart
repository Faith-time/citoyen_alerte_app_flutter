import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/core/theme/neo_kit.dart';
import 'package:citoyen_alerte_app_backup/core/services/auth_service.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/data/models/report_model.dart';
import '../../../routes/app_pages.dart';
import '../reports/create_report_screen.dart';
import '../reports/edit_report_screen.dart';
import '../reports/report_detail_screen.dart';
import '../reports/my_reports_screen.dart';

// ══════════════════════════════════════════════════════════════════════════
// CONTROLLER — logique inchangée
// ══════════════════════════════════════════════════════════════════════════

class CitizenDashboardController extends GetxController {
  final ApiService _api = Get.find<ApiService>();
  final AuthService _auth = AuthService.instance;

  final isLoadingDashboard = true.obs;
  final isLoadingReports = true.obs;
  final isDeletingId = Rx<int?>(null);

  final dashboardData = Rx<Map<String, dynamic>?>(null);
  final myReports = <ReportModel>[].obs;
  final filteredReports = <ReportModel>[].obs;
  final selectedFilter = 'all'.obs;

  int get totalReports => myReports.length;
  int get pendingReports => myReports.where((r) => r.status == 'pending').length;
  int get resolvedReports => myReports.where((r) => r.status == 'resolved').length;
  int get inProgressReports => myReports.where((r) => r.status == 'in_progress').length;

  String get userName => _auth.userName.value ?? 'Citoyen';
  String get userEmail => _auth.userEmail.value ?? '';
  String? get userAvatar => _auth.userAvatar.value;

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<void> loadAll() async {
    await Future.wait([loadDashboard(), loadMyReports()]);
  }

  Future<void> loadDashboard() async {
    try {
      isLoadingDashboard.value = true;
      final response = await _api.getCitizenDashboard();
      if (response.success && response.data != null) {
        dashboardData.value = response.data as Map<String, dynamic>;
      }
    } catch (_) {
      // Silent: dashboard stats fall back to local counts from myReports.
    } finally {
      isLoadingDashboard.value = false;
    }
  }

  Future<void> loadMyReports() async {
    try {
      isLoadingReports.value = true;
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
        myReports.assignAll(
            items.map((e) => ReportModel.fromJson(e as Map<String, dynamic>)));
        applyFilter(selectedFilter.value);
      }
    } catch (e) {
      Get.snackbar('Erreur', 'Impossible de charger vos signalements',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.error,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16));
    } finally {
      isLoadingReports.value = false;
    }
  }

  void applyFilter(String filter) {
    selectedFilter.value = filter;
    if (filter == 'all') {
      filteredReports.assignAll(myReports);
    } else {
      filteredReports.assignAll(myReports.where((r) => r.status == filter));
    }
  }

  Future<void> deleteReport(int id) async {
    try {
      isDeletingId.value = id;
      final response = await _api.deleteReport(id);
      if (response.success) {
        myReports.removeWhere((r) => r.id == id);
        applyFilter(selectedFilter.value);
        Get.snackbar('Supprimé ✓', 'Signalement supprimé avec succès',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppTheme.success,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16));
      }
    } catch (_) {
      Get.snackbar('Erreur', 'Impossible de supprimer ce signalement',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.error,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16));
    } finally {
      isDeletingId.value = null;
    }
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {}
    await AuthService.instance.logout();
    Get.offAllNamed(Routes.LOGIN);
  }

  Color getStatusColor(String s) {
    switch (s) {
      case 'pending':
        return AppTheme.warning;
      case 'routed':
        return AppTheme.info;
      case 'in_progress':
        return AppTheme.purple;
      case 'resolved':
        return AppTheme.success;
      default:
        return AppTheme.greyMedium;
    }
  }

  String getStatusLabel(String s) {
    switch (s) {
      case 'pending':
        return 'En attente';
      case 'routed':
        return 'Routé';
      case 'in_progress':
        return 'En cours';
      case 'resolved':
        return 'Résolu';
      default:
        return s;
    }
  }

  IconData getCategoryIcon(String? cat) {
    switch (cat?.toLowerCase()) {
      case 'propreté':
        return Icons.delete_outline_rounded;
      case 'voirie':
        return Icons.traffic_rounded;
      case 'éclairage':
        return Icons.lightbulb_outline_rounded;
      case 'environnement':
        return Icons.park_outlined;
      case 'sécurité':
        return Icons.security_outlined;
      default:
        return Icons.report_problem_outlined;
    }
  }

  Color getSeverityColor(String s) {
    switch (s) {
      case 'high':
        return AppTheme.error;
      case 'medium':
        return AppTheme.warning;
      case 'low':
        return AppTheme.success;
      default:
        return AppTheme.greyMedium;
    }
  }

  String timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} mois';
    if (diff.inDays > 0) return 'Il y a ${diff.inDays}j';
    if (diff.inHours > 0) return 'Il y a ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'Il y a ${diff.inMinutes}min';
    return 'À l\'instant';
  }
}

// ══════════════════════════════════════════════════════════════════════════
// SCREEN PRINCIPAL
// ══════════════════════════════════════════════════════════════════════════

class CitizenDashboardScreen extends StatefulWidget {
  const CitizenDashboardScreen({super.key});

  @override
  State<CitizenDashboardScreen> createState() => _CitizenDashboardScreenState();
}

class _CitizenDashboardScreenState extends State<CitizenDashboardScreen> {
  late final CitizenDashboardController _ctrl;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(CitizenDashboardController());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ));
    });
  }

  Future<void> _openCreateReport() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CreateReportScreen()),
    );
    if (result == true) _ctrl.loadAll();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Neo.bg,
      body: NeoBackdrop(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _HomeTab(ctrl: _ctrl, onCreateTap: _openCreateReport),
            _MyAlertsTab(ctrl: _ctrl, onCreateTap: _openCreateReport),
            const _NewsTab(),
            _ProfileTab(ctrl: _ctrl),
          ],
        ),
      ),
      bottomNavigationBar: NeoBottomNav(
        index: _selectedIndex,
        onChanged: (i) => setState(() => _selectedIndex = i),
        items: const [
          NeoNavItem(Icons.home_outlined, Icons.home_rounded, 'Accueil'),
          NeoNavItem(Icons.shield_outlined, Icons.shield_rounded, 'Signalements'),
          NeoNavItem(Icons.newspaper_outlined, Icons.newspaper_rounded, 'Actualités'),
          NeoNavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ONGLET ACCUEIL
// ══════════════════════════════════════════════════════════════════════════

class _HomeTab extends StatelessWidget {
  final CitizenDashboardController ctrl;
  final VoidCallback onCreateTap;
  const _HomeTab({required this.ctrl, required this.onCreateTap});

  static const _cats = [
    _Cat('Propreté', Icons.delete_outline_rounded, Neo.blue),
    _Cat('Voirie', Icons.traffic_rounded, Neo.danger),
    _Cat('Éclairage', Icons.lightbulb_outline_rounded, Neo.warning),
    _Cat('Sécurité', Icons.shield_outlined, Neo.purple),
    _Cat('Environnement', Icons.park_outlined, Neo.success),
    _Cat('Autres', Icons.more_horiz_rounded, Neo.muted),
  ];

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: ctrl.loadAll,
      color: Neo.blue,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: EdgeInsets.zero,
        children: [
          Obx(() => NeoGreetingHeader(
                name: ctrl.userName.split(' ').first,
                avatarUrl: ctrl.userAvatar,
              )),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              NeoReveal(
                child: NeoHero(
                  title: 'Un problème à signaler ?',
                  subtitle: 'Votre signalement compte !',
                  buttonLabel: 'Faire un signalement',
                  onTap: onCreateTap,
                ),
              ),
              const SizedBox(height: 18),
              NeoReveal(
                delayMs: 60,
                child: Obx(() => NeoStatsStrip(items: [
                      NeoStat('${ctrl.totalReports}', 'Signalements'),
                      NeoStat('${ctrl.inProgressReports + ctrl.pendingReports}', 'En cours', Neo.warning),
                      NeoStat('${ctrl.resolvedReports}', 'Résolus', Neo.success),
                    ])),
              ),
              const SizedBox(height: 22),
              NeoReveal(delayMs: 100, child: NeoSectionTitle('Catégories', action: 'Tout voir', onAction: onCreateTap)),
              const SizedBox(height: 12),
              NeoReveal(
                delayMs: 140,
                child: GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.05,
                  children: _cats
                      .map((c) => NeoCategoryTile(icon: c.icon, label: c.label, color: c.color, onTap: onCreateTap))
                      .toList(),
                ),
              ),
              const SizedBox(height: 24),
              NeoSectionTitle(
                'Mes signalements',
                action: 'Voir tout',
                onAction: () async {
                  await Get.to(() => const MyReportsScreen());
                  ctrl.loadAll();
                },
              ),
              const SizedBox(height: 12),
              Obx(() {
                if (ctrl.isLoadingReports.value) {
                  return const Padding(padding: EdgeInsets.all(28), child: NeoLoading());
                }
                if (ctrl.myReports.isEmpty) {
                  return _EmptyReports(onCreateTap: onCreateTap);
                }
                return Column(
                  children: ctrl.myReports.take(4).map((r) => _ReportCard(report: r, ctrl: ctrl)).toList(),
                );
              }),
              const SizedBox(height: 8),
              const _HelpBanner(),
              const SizedBox(height: 28),
            ]),
          ),
        ],
      ),
    );
  }
}

class _Cat {
  final String label;
  final IconData icon;
  final Color color;
  const _Cat(this.label, this.icon, this.color);
}

// ══════════════════════════════════════════════════════════════════════════
// ONGLET MES ALERTES
// ══════════════════════════════════════════════════════════════════════════

class _MyAlertsTab extends StatelessWidget {
  final CitizenDashboardController ctrl;
  final VoidCallback onCreateTap;
  const _MyAlertsTab({required this.ctrl, required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      NeoTitleBar(
        title: 'Mes signalements',
        subtitle: 'Suivez vos alertes en un coup d\'œil',
        actions: [NeoIconButton(icon: Icons.add_rounded, onTap: onCreateTap)],
      ),
      const SizedBox(height: 8),
      Obx(() => NeoChipRow(chips: [
            NeoChip(label: 'Tous', selected: ctrl.selectedFilter.value == 'all', onTap: () => ctrl.applyFilter('all')),
            NeoChip(label: 'En attente', color: Neo.warning, selected: ctrl.selectedFilter.value == 'pending', onTap: () => ctrl.applyFilter('pending')),
            NeoChip(label: 'Traitement', color: Neo.purple, selected: ctrl.selectedFilter.value == 'in_progress', onTap: () => ctrl.applyFilter('in_progress')),
            NeoChip(label: 'Résolu', color: Neo.success, selected: ctrl.selectedFilter.value == 'resolved', onTap: () => ctrl.applyFilter('resolved')),
          ])),
      Expanded(
        child: RefreshIndicator(
          onRefresh: ctrl.loadMyReports,
          color: Neo.blue,
          child: Obx(() {
            if (ctrl.isLoadingReports.value) return const NeoLoading();
            if (ctrl.filteredReports.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 40),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _EmptyReports(onCreateTap: onCreateTap)),
              ]);
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: ctrl.filteredReports.length,
              itemBuilder: (_, i) => NeoReveal(
                delayMs: (i % 8) * 40,
                child: _ReportCard(report: ctrl.filteredReports[i], ctrl: ctrl, showActions: true),
              ),
            );
          }),
        ),
      ),
    ]);
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ONGLET ACTUALITÉS — "L'impact en images"
// ══════════════════════════════════════════════════════════════════════════

class ResolvedNewsItem {
  final int id;
  final String title;
  final String? description;
  final String category;
  final String communeName;
  final String regionName;
  final String authorityName;
  final String agentName;
  final String? agentAvatarUrl;
  final String beforePhotoUrl;
  final String afterPhotoUrl;
  final DateTime resolvedAt;

  ResolvedNewsItem({
    required this.id,
    required this.title,
    this.description,
    required this.category,
    required this.communeName,
    required this.regionName,
    required this.authorityName,
    required this.agentName,
    this.agentAvatarUrl,
    required this.beforePhotoUrl,
    required this.afterPhotoUrl,
    required this.resolvedAt,
  });

  String get zoneKey =>
      communeName.isNotEmpty ? '$communeName, $regionName' : regionName;

  factory ResolvedNewsItem.fromJson(Map<String, dynamic> json) {
    String _str(dynamic v, [String fallback = '']) =>
        (v == null) ? fallback : v.toString();

    final agent = json['agent'] as Map<String, dynamic>?;
    final authority = json['authority'] as Map<String, dynamic>?;
    final commune = json['commune'] as Map<String, dynamic>?;
    final region = json['region'] as Map<String, dynamic>?;
    final category = json['category'] as Map<String, dynamic>?;

    DateTime _parseDate(dynamic v) {
      if (v == null) return DateTime.now();
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    return ResolvedNewsItem(
      id: json['id'] is int ? json['id'] as int : int.tryParse('${json['id']}') ?? 0,
      title: _str(json['title'], 'Signalement'),
      description: json['description']?.toString(),
      category: _str(category?['name'] ?? json['category_name'] ?? json['category'], 'Autre'),
      communeName: _str(commune?['name'] ?? json['commune_name'] ?? json['communeName']),
      regionName: _str(region?['name'] ?? json['region_name'] ?? json['regionName']),
      authorityName: _str(
        authority?['name'] ?? json['authority_name'] ?? json['authorityName'],
        'Autorité locale',
      ),
      agentName: _str(
        agent?['name'] ?? json['agent_name'] ?? json['resolved_by_name'] ?? json['agentName'],
        'Agent municipal',
      ),
      agentAvatarUrl: (agent?['avatar'] ?? json['agent_avatar'])?.toString(),
      beforePhotoUrl: _str(
        json['photo_before'] ?? json['before_photo'] ?? json['photoBefore'] ?? json['image_url'],
      ),
      afterPhotoUrl: _str(
        json['photo_after'] ?? json['after_photo'] ?? json['photoAfter'] ?? json['resolution_photo_url'],
      ),
      resolvedAt: _parseDate(json['resolved_at'] ?? json['resolvedAt'] ?? json['updated_at']),
    );
  }

  bool get hasAfterPhoto => afterPhotoUrl.isNotEmpty;
  bool get hasBeforePhoto => beforePhotoUrl.isNotEmpty;
}

class NewsFeedController extends GetxController {
  final ApiService _api = Get.find<ApiService>();

  final isLoading = true.obs;
  final hasError = false.obs;
  final items = <ResolvedNewsItem>[].obs;
  final selectedZone = 'Toutes les zones'.obs;

  @override
  void onInit() {
    super.onInit();
    loadFeed();
  }

  Future<void> loadFeed() async {
    try {
      isLoading.value = true;
      hasError.value = false;
      final response = await _api.getResolvedNewsFeed();
      if (response.success && response.data != null) {
        final raw = response.data;
        List rawList = [];
        if (raw is Map<String, dynamic>) {
          rawList = (raw['data'] as List?) ?? [];
        } else if (raw is List) {
          rawList = raw;
        }
        final parsed = rawList
            .map((e) => ResolvedNewsItem.fromJson(e as Map<String, dynamic>))
            .where((e) => e.hasAfterPhoto)
            .toList()
          ..sort((a, b) => b.resolvedAt.compareTo(a.resolvedAt));
        items.assignAll(parsed);
      } else {
        hasError.value = true;
      }
    } catch (_) {
      hasError.value = true;
    } finally {
      isLoading.value = false;
    }
  }

  List<String> get zoneOptions {
    final zones = items.map((e) => e.zoneKey).where((z) => z.isNotEmpty).toSet().toList()..sort();
    return ['Toutes les zones', ...zones];
  }

  List<ResolvedNewsItem> get _filtered {
    if (selectedZone.value == 'Toutes les zones') return items;
    return items.where((i) => i.zoneKey == selectedZone.value).toList();
  }

  /// zone -> autorité -> liste de signalements résolus
  Map<String, Map<String, List<ResolvedNewsItem>>> get groupedFeed {
    final map = <String, Map<String, List<ResolvedNewsItem>>>{};
    for (final item in _filtered) {
      final zone = item.zoneKey.isEmpty ? 'Zone non précisée' : item.zoneKey;
      map.putIfAbsent(zone, () => {});
      final authority = item.authorityName.isEmpty ? 'Autorité locale' : item.authorityName;
      map[zone]!.putIfAbsent(authority, () => []);
      map[zone]![authority]!.add(item);
    }
    return map;
  }

  int get totalResolved => items.length;

  int get resolvedThisWeek =>
      items.where((i) => DateTime.now().difference(i.resolvedAt).inDays <= 7).length;

  int get activeZones => items.map((e) => e.zoneKey).toSet().length;

  void selectZone(String zone) => selectedZone.value = zone;
}

class _NewsTab extends StatelessWidget {
  const _NewsTab();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(NewsFeedController(), tag: 'newsFeed');

    return RefreshIndicator(
      onRefresh: ctrl.loadFeed,
      color: Neo.blue,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          const SliverToBoxAdapter(
            child: NeoTitleBar(
              title: "L'impact, en images",
              subtitle: 'Les signalements résolus, avant / après',
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Obx(() => NeoStatsStrip(items: [
                    NeoStat('${ctrl.totalResolved}', 'Résolus', Neo.success),
                    NeoStat('${ctrl.resolvedThisWeek}', 'Cette semaine', Neo.blue),
                    NeoStat('${ctrl.activeZones}', 'Zones actives', Neo.info),
                  ])),
            ),
          ),
          SliverToBoxAdapter(
            child: Obx(() {
              if (ctrl.items.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 14),
                child: NeoChipRow(
                  chips: ctrl.zoneOptions
                      .map((z) => NeoChip(label: z, selected: ctrl.selectedZone.value == z, onTap: () => ctrl.selectZone(z)))
                      .toList(),
                ),
              );
            }),
          ),
          Obx(() {
            if (ctrl.isLoading.value) {
              return const SliverFillRemaining(hasScrollBody: false, child: Padding(padding: EdgeInsets.only(top: 60), child: NeoLoading()));
            }
            if (ctrl.hasError.value) {
              return SliverToBoxAdapter(child: NeoError(onRetry: ctrl.loadFeed, message: 'Impossible de charger les actualités'));
            }
            final grouped = ctrl.groupedFeed;
            if (ctrl.items.isEmpty || grouped.isEmpty) {
              return const SliverToBoxAdapter(
                child: NeoEmpty(
                  icon: Icons.photo_library_outlined,
                  title: 'Pas encore de succès à afficher',
                  message: "Dès qu'un signalement sera résolu avec des photos avant/après, il apparaîtra ici.",
                ),
              );
            }
            final zones = grouped.keys.toList();
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  for (final zone in zones) _ZoneSection(zone: zone, authorities: grouped[zone]!),
                ]),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ZoneSection extends StatelessWidget {
  final String zone;
  final Map<String, List<ResolvedNewsItem>> authorities;
  const _ZoneSection({required this.zone, required this.authorities});

  @override
  Widget build(BuildContext context) {
    final total = authorities.values.fold<int>(0, (a, b) => a + b.length);
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const NeoIconBadge(icon: Icons.location_city_rounded, size: 36),
          const SizedBox(width: 10),
          Expanded(child: Text(zone, maxLines: 1, overflow: TextOverflow.ellipsis, style: Neo.t(15, w: FontWeight.w700))),
          NeoPill(label: '$total résolu${total > 1 ? 's' : ''}', color: Neo.blue),
        ]),
        const SizedBox(height: 14),
        for (final e in authorities.entries) _AuthorityGroup(authority: e.key, items: e.value),
      ]),
    );
  }
}

class _AuthorityGroup extends StatelessWidget {
  final String authority;
  final List<ResolvedNewsItem> items;
  const _AuthorityGroup({required this.authority, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 8),
          child: Row(children: [
            const Icon(Icons.account_balance_outlined, size: 13, color: Neo.muted),
            const SizedBox(width: 5),
            Flexible(child: Text(authority, maxLines: 1, overflow: TextOverflow.ellipsis, style: Neo.t(11.5, w: FontWeight.w700, c: Neo.muted))),
          ]),
        ),
        for (final item in items) _NewsFeedCard(item: item),
      ]),
    );
  }
}

class _NewsFeedCard extends StatelessWidget {
  final ResolvedNewsItem item;
  const _NewsFeedCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Neo.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.9)),
        boxShadow: Neo.relief(),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: item.hasBeforePhoto
              ? _BeforeAfterSlider(beforeUrl: item.beforePhotoUrl, afterUrl: item.afterPhotoUrl)
              : _SinglePhoto(url: item.afterPhotoUrl),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Neo.t(14, w: FontWeight.w700))),
              const SizedBox(width: 8),
              const NeoPill(label: 'Résolu', color: Neo.success),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Text(item.category, style: Neo.t(11, w: FontWeight.w600, c: Neo.blue)),
              const SizedBox(width: 8),
              const Icon(Icons.schedule_rounded, size: 11, color: Neo.muted),
              const SizedBox(width: 3),
              Text(Neo.ago(item.resolvedAt), style: Neo.t(11, c: Neo.muted)),
            ]),
            const SizedBox(height: 12),
            Divider(color: Neo.line.withOpacity(0.8), height: 1),
            const SizedBox(height: 10),
            Row(children: [
              _AgentAvatar(name: item.agentName, avatarUrl: item.agentAvatarUrl),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.agentName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Neo.t(12.5, w: FontWeight.w700)),
                  Text('Agent · ${item.authorityName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: Neo.t(11, c: Neo.muted)),
                ]),
              ),
              const Icon(Icons.verified, size: 17, color: Neo.success),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _AgentAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  const _AgentAvatar({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    final fallback = Center(child: Text(initial, style: Neo.t(14, w: FontWeight.w700, c: Neo.blue)));
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Neo.blue.withOpacity(0.10),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: Neo.softRelief(),
      ),
      clipBehavior: Clip.antiAlias,
      child: (avatarUrl != null && avatarUrl!.isNotEmpty)
          ? Image.network(avatarUrl!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback)
          : fallback,
    );
  }
}

class _BeforeAfterSlider extends StatefulWidget {
  final String beforeUrl;
  final String afterUrl;
  const _BeforeAfterSlider({required this.beforeUrl, required this.afterUrl});

  @override
  State<_BeforeAfterSlider> createState() => _BeforeAfterSliderState();
}

class _SinglePhoto extends StatelessWidget {
  final String url;
  const _SinglePhoto({required this.url});

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Neo.inset)),
      const Positioned(top: 10, right: 10, child: _PhotoTag(label: 'RÉSOLU', color: Neo.success)),
    ]);
  }
}

class _BeforeAfterSliderState extends State<_BeforeAfterSlider> {
  double _position = 0.5;

  void _update(double dx, double width) =>
      setState(() => _position = (dx / width).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth;
      return GestureDetector(
        onHorizontalDragUpdate: (d) {
          final box = context.findRenderObject() as RenderBox;
          _update(box.globalToLocal(d.globalPosition).dx, width);
        },
        onTapDown: (d) {
          final box = context.findRenderObject() as RenderBox;
          _update(box.globalToLocal(d.globalPosition).dx, width);
        },
        child: Stack(fit: StackFit.expand, children: [
          Image.network(widget.afterUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Neo.inset)),
          ClipRect(
            clipper: _SliderClipper(_position),
            child: Image.network(widget.beforeUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Neo.inset)),
          ),
          const Positioned(top: 10, left: 10, child: _PhotoTag(label: 'AVANT', color: Neo.danger)),
          const Positioned(top: 10, right: 10, child: _PhotoTag(label: 'APRÈS', color: Neo.success)),
          Positioned(left: (_position * width) - 1, top: 0, bottom: 0, child: Container(width: 2, color: Colors.white.withOpacity(0.9))),
          Positioned(
            left: (_position * width) - 17,
            top: 0,
            bottom: 0,
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 8)],
                ),
                child: const Icon(Icons.swap_horiz_rounded, size: 19, color: Neo.blue),
              ),
            ),
          ),
        ]),
      );
    });
  }
}

class _SliderClipper extends CustomClipper<Rect> {
  final double position;
  const _SliderClipper(this.position);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width * position, size.height);

  @override
  bool shouldReclip(covariant _SliderClipper oldClipper) => oldClipper.position != position;
}

class _PhotoTag extends StatelessWidget {
  final String label;
  final Color color;
  const _PhotoTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)],
      ),
      child: Text(label, style: Neo.t(9.5, w: FontWeight.w800, c: Colors.white).copyWith(letterSpacing: 0.5)),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ONGLET PROFIL
// ══════════════════════════════════════════════════════════════════════════

class _ProfileTab extends StatelessWidget {
  final CitizenDashboardController ctrl;
  const _ProfileTab({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 28),
      children: [
        NeoReveal(
          child: Obx(() => Column(children: [
                Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Neo.surface,
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: Neo.relief(),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ctrl.userAvatar != null && ctrl.userAvatar!.isNotEmpty
                      ? Image.network(ctrl.userAvatar!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, size: 50, color: Neo.blue))
                      : const Icon(Icons.person_rounded, size: 50, color: Neo.blue),
                ),
                const SizedBox(height: 14),
                Text(ctrl.userName, style: Neo.t(21, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(ctrl.userEmail, style: Neo.t(12.5, c: Neo.muted)),
              ])),
        ),
        const SizedBox(height: 22),
        NeoReveal(
          delayMs: 60,
          child: Obx(() => NeoStatsStrip(items: [
                NeoStat('${ctrl.totalReports}', 'Signalements'),
                NeoStat('${ctrl.pendingReports + ctrl.inProgressReports}', 'En cours', Neo.warning),
                NeoStat('${ctrl.resolvedReports}', 'Clôturés', Neo.success),
              ])),
        ),
        const SizedBox(height: 20),
        NeoReveal(
          delayMs: 100,
          child: NeoGroup(title: 'MON COMPTE', children: [
            NeoRow(icon: Icons.person_outline_rounded, label: 'Mes informations', onTap: () {}),
            NeoRow(icon: Icons.notifications_none_rounded, label: 'Notifications', onTap: () {}),
            NeoRow(icon: Icons.lock_outline_rounded, label: 'Sécurité & confidentialité', onTap: () {}),
          ]),
        ),
        const SizedBox(height: 16),
        NeoReveal(
          delayMs: 140,
          child: NeoGroup(title: 'AIDE', children: [
            NeoRow(icon: Icons.help_outline_rounded, label: "Centre d'aide", onTap: () {}),
            NeoRow(
              icon: Icons.info_outline_rounded,
              label: 'À propos',
              trailing: Text('v1.0.0', style: Neo.t(12, c: Neo.muted)),
              onTap: () {},
            ),
          ]),
        ),
        const SizedBox(height: 24),
        NeoLogoutButton(onTap: () async {
          final ok = await neoConfirm(context,
              title: 'Déconnexion', message: 'Êtes-vous sûr de vouloir vous déconnecter ?', confirm: 'Déconnexion');
          if (ok) ctrl.logout();
        }),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// WIDGETS RÉUTILISABLES
// ══════════════════════════════════════════════════════════════════════════

class _ReportCard extends StatelessWidget {
  final ReportModel report;
  final CitizenDashboardController ctrl;
  final bool showActions;

  const _ReportCard({required this.report, required this.ctrl, this.showActions = false});

  @override
  Widget build(BuildContext context) {
    final statusColor = ctrl.getStatusColor(report.status);

    Future<void> openDetail() async {
      final result = await Get.to(() => ReportDetailScreen(reportId: report.id));
      if (result == 'deleted') ctrl.loadMyReports();
    }

    return NeoListCard(
      icon: ctrl.getCategoryIcon(report.category?.name),
      color: Neo.blue,
      title: report.title,
      subtitle: '${report.communeName}, ${report.regionName}',
      meta: ctrl.timeAgo(report.createdAt),
      pill: NeoPill(label: ctrl.getStatusLabel(report.status), color: statusColor),
      onTap: openDetail,
      bottom: showActions
          ? Column(children: [
              Divider(color: Neo.line.withOpacity(0.8), height: 1),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                _ActionBtn(icon: Icons.visibility_outlined, label: 'Détails', color: Neo.info, onTap: openDetail),
                if (report.status == 'pending') ...[
                  const SizedBox(width: 6),
                  _ActionBtn(
                    icon: Icons.edit_outlined,
                    label: 'Modifier',
                    color: Neo.blue,
                    onTap: () async {
                      final result = await Get.to(() => EditReportScreen(report: report));
                      if (result == true) ctrl.loadMyReports();
                    },
                  ),
                  const SizedBox(width: 6),
                  Obx(() => _ActionBtn(
                        icon: ctrl.isDeletingId.value == report.id ? Icons.hourglass_empty : Icons.delete_outline,
                        label: 'Supprimer',
                        color: Neo.danger,
                        onTap: ctrl.isDeletingId.value == report.id ? null : () => _confirmDelete(context),
                      )),
                ],
              ]),
            ])
          : null,
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await neoConfirm(context,
        title: 'Supprimer', message: 'Voulez-vous supprimer "${report.title}" ?', confirm: 'Supprimer');
    if (ok) ctrl.deleteReport(report.id);
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _ActionBtn({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: Neo.t(11, w: FontWeight.w700, c: color)),
        ]),
      ),
    );
  }
}

class _HelpBanner extends StatelessWidget {
  const _HelpBanner();

  @override
  Widget build(BuildContext context) {
    return NeoCard(
      child: Row(children: [
        const NeoIconBadge(icon: Icons.headset_mic_outlined, color: Neo.warning, size: 46),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("Besoin d'aide ?", style: Neo.t(14, w: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('Consultez nos conseils pour un signalement efficace', style: Neo.t(11, c: Neo.muted, h: 1.4)),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: Neo.muted),
      ]),
    );
  }
}

class _EmptyReports extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyReports({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return NeoCard(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
      child: NeoEmpty(
        icon: Icons.report_problem_outlined,
        title: 'Aucun signalement',
        message: 'Appuyez sur le bouton pour créer\nvotre premier signalement',
        action: SizedBox(width: 230, child: NeoButton(label: 'Faire un signalement', icon: Icons.send_rounded, onTap: onCreateTap)),
      ),
    );
  }
}
