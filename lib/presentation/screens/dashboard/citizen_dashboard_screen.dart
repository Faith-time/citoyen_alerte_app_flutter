import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
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
        statusBarIconBrightness: Brightness.light,
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
      backgroundColor: AppTheme.background,
      body: SafeArea(
        top: false,
        bottom: false,
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
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _buildFAB(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildFAB() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [AppTheme.lightGreen, AppTheme.primaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.45),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _openCreateReport,
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.darkBlue.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          color: Colors.transparent,
          elevation: 0,
          child: SizedBox(
            height: 62,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Accueil',
                  isSelected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                _BottomNavItem(
                  icon: Icons.list_alt_outlined,
                  activeIcon: Icons.list_alt_rounded,
                  label: 'Alertes',
                  isSelected: _selectedIndex == 1,
                  onTap: () => setState(() => _selectedIndex = 1),
                ),
                const SizedBox(width: 48),
                _BottomNavItem(
                  icon: Icons.newspaper_outlined,
                  activeIcon: Icons.newspaper_rounded,
                  label: 'Actualités',
                  isSelected: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
                _BottomNavItem(
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profil',
                  isSelected: _selectedIndex == 3,
                  onTap: () => setState(() => _selectedIndex = 3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// LOGO DE L'APP — réutilisé dans tous les headers
// Ajuste `assetPath` si le chemin de ton image diffère dans pubspec.yaml.
// Un fallback (icône bouclier) s'affiche automatiquement si l'asset est
// introuvable, donc ça ne cassera jamais le build.
// ══════════════════════════════════════════════════════════════════════════

class _AppLogo extends StatelessWidget {
  final double size;
  const _AppLogo({this.size = 36});

  static const String assetPath = 'assets/images/logo.png';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(size * 0.32),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        assetPath,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.shield_outlined,
          color: AppTheme.yellow,
          size: size * 0.55,
        ),
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

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: ctrl.loadAll,
      color: AppTheme.primaryGreen,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _CitizenHeader(ctrl: ctrl)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Cartes de stats — sorties du header (comme le dashboard agent)
                // pour ne jamais dépendre d'une hauteur fixe.
                Obx(() => Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        value: '${ctrl.totalReports}',
                        label: 'Signalements',
                        color: AppTheme.primaryGreen,
                        icon: Icons.flag_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        value: '${ctrl.resolvedReports}',
                        label: 'Résolus',
                        color: AppTheme.success,
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        value: '${ctrl.pendingReports}',
                        label: 'En attente',
                        color: AppTheme.warning,
                        icon: Icons.pending_outlined,
                      ),
                    ),
                  ],
                )),
                const SizedBox(height: 20),
                _SignalCTA(onTap: onCreateTap),
                const SizedBox(height: 20),
                _QuickCategories(onTap: onCreateTap),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Mes signalements', style: AppTheme.h3),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          await Get.to(() => const MyReportsScreen());
                          ctrl.loadAll();
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          child: Text(
                            'Voir tout',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Obx(() {
                  if (ctrl.isLoadingReports.value) {
                    return const _LoadingCard();
                  }
                  if (ctrl.myReports.isEmpty) {
                    return _EmptyReports(onCreateTap: onCreateTap);
                  }
                  return Column(
                    children: ctrl.myReports
                        .take(4)
                        .map((r) => _ReportCard(report: r, ctrl: ctrl))
                        .toList(),
                  );
                }),
                const SizedBox(height: 20),
                const _HelpBanner(),
                const SizedBox(height: 90),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// HEADER CITOYEN — compact, taille NATURELLE (jamais de hauteur fixe qui
// entre en conflit avec le contenu -> plus de bandes de débordement).
// Le fond dégradé et le contenu sont dans LE MÊME Container/Column, donc
// le fond s'étire toujours exactement à la taille du contenu.
// ══════════════════════════════════════════════════════════════════════════

class _CitizenHeader extends StatelessWidget {
  final CitizenDashboardController ctrl;
  const _CitizenHeader({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(AppTheme.radiusXl),
        bottomRight: Radius.circular(AppTheme.radiusXl),
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
        child: Stack(
          children: [
            // Décor : positionné en absolu, ne compte jamais dans la taille du Stack
            const Positioned.fill(child: _HeaderPatternDecor()),
            // Contenu réel : détermine la hauteur du header
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const _AppLogo(size: 36),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Alerte Citoyen',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Sénégal',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.72),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Material(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {},
                            child: const Padding(
                              padding: EdgeInsets.all(9),
                              child: Icon(Icons.notifications_outlined,
                                  color: Colors.white, size: 22),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Obx(() => Text(
                      'Bonjour, ${ctrl.userName.split(' ').first} !',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    )),
                    const SizedBox(height: 4),
                    Text(
                      'Ensemble, faisons la différence.',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 12,
                        color: AppTheme.yellow.withOpacity(0.95),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Décor purement visuel (cercles + losanges très légers).
/// Positioned.fill => n'influence jamais la taille du header.
class _HeaderPatternDecor extends StatelessWidget {
  const _HeaderPatternDecor();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: CustomPaint(painter: _HeaderPatternPainter()),
    );
  }
}

class _HeaderPatternPainter extends CustomPainter {
  const _HeaderPatternPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    canvas.drawCircle(
      Offset(w * 0.88, h * 0.15),
      w * 0.28,
      Paint()..color = AppTheme.yellow.withOpacity(0.07),
    );
    canvas.drawCircle(
      Offset(w * 0.85, h * 0.12),
      w * 0.16,
      Paint()..color = Colors.white.withOpacity(0.05),
    );

    final paint = Paint()..color = Colors.white.withOpacity(0.04);
    const double d = 20;
    for (double x = -10; x < w; x += 36) {
      for (double y = 0; y < h; y += 30) {
        final path = Path()
          ..moveTo(x + d / 2, y)
          ..lineTo(x + d, y + d * 0.45)
          ..lineTo(x + d / 2, y + d * 0.9)
          ..lineTo(x, y + d * 0.45)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_HeaderPatternPainter old) => false;
}

// ══════════════════════════════════════════════════════════════════════════
// CTA SIGNALEMENT
// ══════════════════════════════════════════════════════════════════════════

class _SignalCTA extends StatelessWidget {
  final VoidCallback onTap;
  const _SignalCTA({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppTheme.ctaGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: AppTheme.elevatedShadow(AppTheme.primaryGreen),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.yellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.yellow.withOpacity(0.4), width: 1.5),
                ),
                child: const Icon(Icons.send_rounded, color: AppTheme.yellow, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Faire un signalement',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Signalez un problème en quelques étapes',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.yellow,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_forward_ios_rounded,
                    color: AppTheme.darkBlue, size: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// CATÉGORIES RAPIDES
// ══════════════════════════════════════════════════════════════════════════

class _QuickCategories extends StatelessWidget {
  final VoidCallback onTap;
  const _QuickCategories({required this.onTap});

  static final _cats = [
    _CatDef('Propreté', Icons.delete_outline_rounded, AppTheme.primaryGreen),
    _CatDef('Voirie', Icons.traffic_rounded, AppTheme.coral),
    _CatDef('Éclairage', Icons.lightbulb_outline_rounded, AppTheme.yellow),
    _CatDef('Sécurité', Icons.security_outlined, AppTheme.purple),
    _CatDef('Env.', Icons.park_outlined, AppTheme.lightGreen),
    _CatDef('Autre', Icons.more_horiz_rounded, AppTheme.greyMedium),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Catégories', style: AppTheme.h3),
        const SizedBox(height: 10),
        Row(
          children: _cats
              .map((c) => Expanded(child: _CatChip(cat: c, onTap: onTap)))
              .toList(),
        ),
      ],
    );
  }
}

class _CatDef {
  final String label;
  final IconData icon;
  final Color color;
  const _CatDef(this.label, this.icon, this.color);
}

class _CatChip extends StatelessWidget {
  final _CatDef cat;
  final VoidCallback onTap;
  const _CatChip({required this.cat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: cat.color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cat.color.withOpacity(0.25), width: 1),
              ),
              child: Icon(cat.icon, color: cat.color, size: 22),
            ),
            const SizedBox(height: 5),
            Text(
              cat.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: AppTheme.darkBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    return Column(
      children: [
        _SubHeader(
          title: 'Mes signalements',
          trailingWidget: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onCreateTap,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: AppTheme.yellow.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.yellow.withOpacity(0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, color: AppTheme.yellow, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Nouveau',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: AppTheme.yellow,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Container(
          color: AppTheme.darkGreen,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Obx(() => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterPill(
                    label: 'Tous',
                    isSelected: ctrl.selectedFilter.value == 'all',
                    onTap: () => ctrl.applyFilter('all')),
                const SizedBox(width: 8),
                _FilterPill(
                    label: 'En attente',
                    color: AppTheme.warning,
                    isSelected: ctrl.selectedFilter.value == 'pending',
                    onTap: () => ctrl.applyFilter('pending')),
                const SizedBox(width: 8),
                _FilterPill(
                    label: 'Traitement',
                    color: AppTheme.purple,
                    isSelected: ctrl.selectedFilter.value == 'in_progress',
                    onTap: () => ctrl.applyFilter('in_progress')),
                const SizedBox(width: 8),
                _FilterPill(
                    label: 'Résolu',
                    color: AppTheme.success,
                    isSelected: ctrl.selectedFilter.value == 'resolved',
                    onTap: () => ctrl.applyFilter('resolved')),
              ],
            ),
          )),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: ctrl.loadMyReports,
            color: AppTheme.primaryGreen,
            child: Obx(() {
              if (ctrl.isLoadingReports.value) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryGreen),
                );
              }
              if (ctrl.filteredReports.isEmpty) {
                return _EmptyReports(onCreateTap: onCreateTap);
              }
              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                itemCount: ctrl.filteredReports.length,
                itemBuilder: (_, i) => _ReportCard(
                  report: ctrl.filteredReports[i],
                  ctrl: ctrl,
                  showActions: true,
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// ONGLET ACTUALITÉS
// ══════════════════════════════════════════════════════════════════════════

// ══════════════════════════════════════════════════════════════════════════
// ONGLET ACTUALITÉS — "L'impact en images"
// ──────────────────────────────────────────────────────────────────────────
// Remplace entièrement l'ancienne `_NewsTab` (le stub "Bientôt disponible").
// Colle ce bloc à la place de l'ancienne classe `_NewsTab` dans ton fichier,
// et importe ce dont tu as besoin en haut du fichier (voir note d'intégration
// tout en bas de ce fichier).
//
// Principe : on affiche les signalements RÉSOLUS de l'appli, avec leurs
// photos avant/après (glisser pour comparer), regroupés par ZONE
// (commune, région) puis par AUTORITÉ responsable, avec le nom de l'agent
// qui a traité chaque signalement. Aucune donnée fictive : tout vient de
// ton API réelle via un nouvel endpoint (voir note d'intégration backend).
// ══════════════════════════════════════════════════════════════════════════

// ─────────────────────────────────────────────────────────────────────────
// MODÈLE — élément de fil d'actualité (signalement résolu + avant/après)
// ─────────────────────────────────────────────────────────────────────────

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

  /// Parsing tolérant : accepte plusieurs conventions de nommage possibles
  /// côté Laravel (snake_case direct, objets imbriqués agent/authority/zone).
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

// ─────────────────────────────────────────────────────────────────────────
// CONTROLLER
// ─────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────

class _NewsTab extends StatelessWidget {
  const _NewsTab();

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(NewsFeedController(), tag: 'newsFeed');

    return RefreshIndicator(
      onRefresh: ctrl.loadFeed,
      color: AppTheme.primaryGreen,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _NewsHeader(ctrl: ctrl)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: _NewsStatsRow(ctrl: ctrl),
            ),
          ),
          SliverToBoxAdapter(
            child: Obx(() {
              if (ctrl.items.isEmpty) return const SizedBox.shrink();
              return _ZoneFilterBar(ctrl: ctrl);
            }),
          ),
          Obx(() {
            if (ctrl.isLoading.value) {
              return const SliverToBoxAdapter(child: _NewsLoadingSkeleton());
            }
            if (ctrl.hasError.value) {
              return SliverToBoxAdapter(child: _NewsErrorState(onRetry: ctrl.loadFeed));
            }
            if (ctrl.items.isEmpty) {
              return const SliverToBoxAdapter(child: _NewsEmptyState());
            }

            final grouped = ctrl.groupedFeed;
            if (grouped.isEmpty) {
              return const SliverToBoxAdapter(child: _NewsEmptyState());
            }

            final zones = grouped.keys.toList();
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
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

// ─────────────────────────────────────────────────────────────────────────
// HEADER — bannière "L'impact en images"
// ─────────────────────────────────────────────────────────────────────────

class _NewsHeader extends StatelessWidget {
  final NewsFeedController ctrl;
  const _NewsHeader({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(AppTheme.radiusXl),
        bottomRight: Radius.circular(AppTheme.radiusXl),
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    _AppLogo(size: 32),
                    SizedBox(width: 10),
                    Text(
                      'Alerte Citoyen',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  "L'impact, en images",
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Les signalements résolus par nos autorités, avant / après.',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 12,
                    color: AppTheme.yellow.withOpacity(0.95),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// BANDEAU STATS
// ─────────────────────────────────────────────────────────────────────────

class _NewsStatsRow extends StatelessWidget {
  final NewsFeedController ctrl;
  const _NewsStatsRow({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() => Row(
      children: [
        Expanded(
          child: StatTile(
            value: '${ctrl.totalResolved}',
            label: 'Résolus',
            color: AppTheme.success,
            icon: Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            value: '${ctrl.resolvedThisWeek}',
            label: 'Cette semaine',
            color: AppTheme.primaryGreen,
            icon: Icons.trending_up_rounded,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(
            value: '${ctrl.activeZones}',
            label: 'Zones actives',
            color: AppTheme.info,
            icon: Icons.map_outlined,

          ),
        ),
      ],
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────
// FILTRE PAR ZONE — chips horizontales
// ─────────────────────────────────────────────────────────────────────────

class _ZoneFilterBar extends StatelessWidget {
  final NewsFeedController ctrl;
  const _ZoneFilterBar({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: SizedBox(
        height: 34,
        child: Obx(() {
          final zones = ctrl.zoneOptions;
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: zones.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final zone = zones[i];
              final isSelected = ctrl.selectedZone.value == zone;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => ctrl.selectZone(zone),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primaryGreen : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryGreen : AppTheme.greyLight,
                      ),
                      boxShadow: isSelected ? [] : AppTheme.cardShadow(),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 13,
                          color: isSelected ? Colors.white : AppTheme.greyMedium,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          zone,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppTheme.darkBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// SECTION DE ZONE — regroupe les autorités puis les cartes résolues
// ─────────────────────────────────────────────────────────────────────────

class _ZoneSection extends StatelessWidget {
  final String zone;
  final Map<String, List<ResolvedNewsItem>> authorities;
  const _ZoneSection({required this.zone, required this.authorities});

  @override
  Widget build(BuildContext context) {
    final totalInZone = authorities.values.fold<int>(0, (a, b) => a + b.length);

    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_city_rounded, size: 16, color: AppTheme.primaryGreen),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  zone,
                  style: AppTheme.h3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$totalInZone résolu${totalInZone > 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final entry in authorities.entries) _AuthorityGroup(authority: entry.key, items: entry.value),
        ],
      ),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 2, bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.account_balance_outlined, size: 13, color: AppTheme.greyMedium),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    authority,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.greyMedium,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final item in items) _NewsFeedCard(item: item),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// CARTE PRINCIPALE — avant/après glissant + crédit agent
// ─────────────────────────────────────────────────────────────────────────

class _NewsFeedCard extends StatelessWidget {
  final ResolvedNewsItem item;
  const _NewsFeedCard({required this.item});

  String _timeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) return '${(diff.inDays / 30).floor()} mois';
    if (diff.inDays > 0) return 'Il y a ${diff.inDays}j';
    if (diff.inHours > 0) return 'Il y a ${diff.inHours}h';
    if (diff.inMinutes > 0) return 'Il y a ${diff.inMinutes}min';
    return "À l'instant";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow(),
        border: Border.all(color: AppTheme.greyLight.withOpacity(0.7)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: item.hasBeforePhoto
                ? _BeforeAfterSlider(
              beforeUrl: item.beforePhotoUrl,
              afterUrl: item.afterPhotoUrl,
            )
                : _SinglePhoto(url: item.afterPhotoUrl),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.darkBlue,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StatusPill(label: 'Résolu', color: AppTheme.success),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.lightGreen.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        item.category,
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.schedule_rounded, size: 11, color: AppTheme.greyMedium),
                    const SizedBox(width: 3),
                    Text(_timeAgo(item.resolvedAt), style: AppTheme.caption),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(color: AppTheme.greyLight.withOpacity(0.8), height: 1),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _AgentAvatar(name: item.agentName, avatarUrl: item.agentAvatarUrl),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.agentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkBlue,
                            ),
                          ),
                          Text(
                            'Agent · ${item.authorityName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.caption,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.verified, size: 16, color: AppTheme.success),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryGreen.withOpacity(0.12),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
      ),
      clipBehavior: Clip.antiAlias,
      child: (avatarUrl != null && avatarUrl!.isNotEmpty)
          ? Image.network(
        avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Center(
          child: Text(
            initial,
            style: const TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              color: AppTheme.primaryGreen,
            ),
          ),
        ),
      )
          : Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryGreen,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// SLIDER AVANT / APRÈS — glisser pour comparer
// ─────────────────────────────────────────────────────────────────────────

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
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: AppTheme.greyLight),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: _PhotoTag(label: 'RÉSOLU', color: AppTheme.success),
        ),
      ],
    );
  }
}

class _BeforeAfterSliderState extends State<_BeforeAfterSlider> {
  double _position = 0.5; // 0 = tout "avant", 1 = tout "après"

  void _updatePosition(double dx, double width) {
    setState(() {
      _position = (dx / width).clamp(0.0, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.globalPosition);
            _updatePosition(local.dx, width);
          },
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox;
            final local = box.globalToLocal(details.globalPosition);
            _updatePosition(local.dx, width);
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Photo "après" en fond
              Image.network(
                widget.afterUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: AppTheme.greyLight),
              ),
              // Photo "avant" révélée jusqu'à la position du curseur
              ClipRect(
                clipper: _SliderClipper(_position),
                child: Image.network(
                  widget.beforeUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: AppTheme.greyLight),
                ),
              ),
              // Étiquettes AVANT / APRÈS
              Positioned(
                top: 10,
                left: 10,
                child: _PhotoTag(label: 'AVANT', color: AppTheme.coral),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: _PhotoTag(label: 'APRÈS', color: AppTheme.success),
              ),
              // Poignée de glissement
              Positioned(
                left: (_position * width) - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: Colors.white.withOpacity(0.9)),
              ),
              Positioned(
                left: (_position * width) - 16,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 6),
                      ],
                    ),
                    child: const Icon(Icons.drag_handle_rounded, size: 18, color: AppTheme.darkBlue),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// ÉTATS : chargement / erreur / vide
// ─────────────────────────────────────────────────────────────────────────

class _NewsLoadingSkeleton extends StatelessWidget {
  const _NewsLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        children: List.generate(3, (i) => const _SkeletonCard()),
      ),
    );
  }
}

class _SkeletonCard extends StatefulWidget {
  const _SkeletonCard();

  @override
  State<_SkeletonCard> createState() => _SkeletonCardState();
}

class _SkeletonCardState extends State<_SkeletonCard> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.4, end: 0.9).animate(_controller),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        height: 230,
        decoration: BoxDecoration(
          color: AppTheme.greyLight.withOpacity(0.6),
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
      ),
    );
  }
}

class _NewsErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _NewsErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.cloud_off_rounded, size: 36, color: AppTheme.error),
          ),
          const SizedBox(height: 14),
          const Text('Impossible de charger les actualités', style: AppTheme.h3),
          const SizedBox(height: 6),
          const Text(
            'Vérifiez votre connexion et réessayez.',
            textAlign: TextAlign.center,
            style: AppTheme.body,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 180,
            child: PrimaryActionButton(label: 'Réessayer', icon: Icons.refresh_rounded, onTap: onRetry),
          ),
        ],
      ),
    );
  }
}

class _NewsEmptyState extends StatelessWidget {
  const _NewsEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 0),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.yellow.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.photo_library_outlined, size: 44, color: AppTheme.yellow),
          ),
          const SizedBox(height: 16),
          const Text('Pas encore de succès à afficher', style: AppTheme.h3),
          const SizedBox(height: 6),
          const Text(
            'Dès qu\'un signalement sera résolu avec des\nphotos avant/après, il apparaîtra ici.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: AppTheme.greyMedium,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// NOTE D'INTÉGRATION (à lire avant de coller ce fichier)
// ══════════════════════════════════════════════════════════════════════════
//
// 1) FLUTTER — ApiService
//    Ajoute cette méthode à ta classe `ApiService` (même style que
//    `getCitizenDashboard()` / `getUserReports()`) :
//
//      Future<ApiResponse> getResolvedNewsFeed() {
//        return get('/reports/resolved-feed');
//      }
//
//    (adapte le nom exact de ta méthode `get` / du wrapper HTTP à ce que
//    fait déjà ton `ApiService` pour les autres endpoints).
//
// 2) LARAVEL — endpoint attendu : GET /api/reports/resolved-feed
//    Retourne les signalements avec statut "resolved" qui ont une photo
//    avant ET une photo après, avec les relations chargées :
//
//      Report::with(['category', 'commune', 'region', 'authority',
//                     'resolvedByAgent'])
//        ->where('status', 'resolved')
//        ->whereNotNull('photo_before')
//        ->whereNotNull('photo_after')
//        ->orderByDesc('resolved_at')
//        ->get();
//
//    Champs minimum par élément du JSON (le parsing ci-dessus accepte
//    aussi des variantes snake_case ou des objets imbriqués) :
//      id, title, category (ou category_name), commune_name, region_name,
//      authority_name, agent_name, agent_avatar (optionnel),
//      photo_before, photo_after, resolved_at
//
//    Si tes signalements n'ont pas encore de colonnes `photo_before` /
//    `photo_after` / `resolved_at` / `resolved_by_agent_id`, il faudra les
//    ajouter (migration) et les faire remplir par l'agent au moment de
//    marquer un signalement comme résolu.
//
// 3) Où coller ce code dans ton fichier existant :
//    - Supprime l'ancienne classe `_NewsTab` (le stub "Bientôt disponible").
//    - Colle tout ce fichier à la place (les classes `ResolvedNewsItem`,
//      `NewsFeedController`, `_NewsTab` et tous les widgets qui suivent).
//    - Rien d'autre à changer dans `CitizenDashboardScreen` : il appelle
//      déjà `const _NewsTab()` dans son `IndexedStack`.
// ══════════════════════════════════════════════════════════════════════════
// ══════════════════════════════════════════════════════════════════════════
// ONGLET PROFIL
// ══════════════════════════════════════════════════════════════════════════

class _ProfileTab extends StatelessWidget {
  final CitizenDashboardController ctrl;
  const _ProfileTab({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header profil : fond + contenu dans le MÊME Container -> taille
          // toujours cohérente, jamais de débordement.
          ClipRRect(
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(AppTheme.radiusXl),
              bottomRight: Radius.circular(AppTheme.radiusXl),
            ),
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
              child: Stack(
                children: [
                  const Positioned.fill(child: _HeaderPatternDecor()),
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Row(
                              children: [
                                const _AppLogo(size: 32),
                                const SizedBox(width: 8),
                                const Text(
                                  'Alerte Citoyen',
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Obx(() => Column(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  Container(
                                    width: 78,
                                    height: 78,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.15),
                                      border: Border.all(
                                          color: AppTheme.yellow.withOpacity(0.6),
                                          width: 2.5),
                                    ),
                                    child: ctrl.userAvatar != null
                                        ? ClipOval(
                                      child: Image.network(ctrl.userAvatar!,
                                          fit: BoxFit.cover),
                                    )
                                        : const Icon(Icons.person_rounded,
                                        size: 38, color: Colors.white),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppTheme.yellow,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.verified,
                                        color: AppTheme.darkBlue, size: 11),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                ctrl.userName,
                                style: const TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(ctrl.userEmail,
                                  style: TextStyle(
                                    fontFamily: AppTheme.fontFamily,
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.75),
                                  )),
                              const SizedBox(height: 10),
                              Container(
                                padding:
                                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.yellow.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border:
                                  Border.all(color: AppTheme.yellow.withOpacity(0.4)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.location_on_outlined,
                                        size: 12, color: AppTheme.yellow),
                                    SizedBox(width: 5),
                                    Text('Citoyen Sénégalais',
                                        style: TextStyle(
                                          color: AppTheme.yellow,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11,
                                        )),
                                  ],
                                ),
                              ),
                            ],
                          )),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Obx(() => Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        value: '${ctrl.totalReports}',
                        label: 'Total',
                        color: AppTheme.primaryGreen,
                        icon: Icons.flag_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        value: '${ctrl.resolvedReports}',
                        label: 'Résolus',
                        color: AppTheme.success,
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatTile(
                        value: '${ctrl.pendingReports}',
                        label: 'En attente',
                        color: AppTheme.warning,
                        icon: Icons.pending_outlined,
                      ),
                    ),
                  ],
                )),
                const SizedBox(height: 20),
                _ProfileSection(
                  title: 'MON COMPTE',
                  children: [
                    _ProfileOption(
                        icon: Icons.person_outline_rounded,
                        label: 'Informations personnelles',
                        onTap: () {}),
                    _ProfileOption(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        onTap: () {}),
                    _ProfileOption(
                        icon: Icons.security_outlined,
                        label: 'Sécurité & Confidentialité',
                        onTap: () {}),
                  ],
                ),
                const SizedBox(height: 12),
                _ProfileSection(
                  title: 'AIDE',
                  children: [
                    _ProfileOption(
                        icon: Icons.help_outline_rounded, label: 'Centre d\'aide', onTap: () {}),
                    _ProfileOption(
                        icon: Icons.info_outline_rounded,
                        label: 'À propos',
                        trailing: const Text('v1.0.0',
                            style: TextStyle(fontSize: 12, color: AppTheme.greyMedium)),
                        onTap: () {}),
                  ],
                ),
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Get.defaultDialog(
                        title: 'Déconnexion',
                        middleText: 'Êtes-vous sûr de vouloir vous déconnecter ?',
                        textCancel: 'Annuler',
                        textConfirm: 'Déconnexion',
                        confirmTextColor: Colors.white,
                        buttonColor: AppTheme.coral,
                        onConfirm: () {
                          Get.back();
                          ctrl.logout();
                        },
                      );
                    },
                    child: Container(
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
                          Text(
                            'Se déconnecter',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.coral,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 90),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// WIDGETS RÉUTILISABLES
// ══════════════════════════════════════════════════════════════════════════

/// En-tête compact pour les onglets secondaires (Alertes / Actualités).
/// Taille naturelle (pas de hauteur fixe) + logo de l'app à gauche.
class _SubHeader extends StatelessWidget {
  final String title;
  final Widget? trailingWidget;

  const _SubHeader({required this.title, this.trailingWidget});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppTheme.ctaGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              const _AppLogo(size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (trailingWidget != null) trailingWidget!,
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportModel report;
  final CitizenDashboardController ctrl;
  final bool showActions;

  const _ReportCard({
    required this.report,
    required this.ctrl,
    this.showActions = false,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = ctrl.getStatusColor(report.status);
    final statusLabel = ctrl.getStatusLabel(report.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.cardShadow(),
        border: Border.all(color: AppTheme.greyLight.withOpacity(0.8)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: () async {
            final result = await Get.to(() => ReportDetailScreen(reportId: report.id));
            if (result == 'deleted') ctrl.loadMyReports();
          },
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 52,
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        ctrl.getCategoryIcon(report.category?.name),
                        color: AppTheme.primaryGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.title,
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.darkBlue,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 11, color: AppTheme.greyMedium),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  '${report.communeName}, ${report.regionName}',
                                  style: AppTheme.caption,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    StatusPill(label: statusLabel, color: statusColor),
                  ],
                ),
                if (showActions) ...[
                  const SizedBox(height: 10),
                  Divider(color: AppTheme.greyLight, height: 1),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _ActionBtn(
                        icon: Icons.visibility_outlined,
                        label: 'Détails',
                        color: AppTheme.info,
                        onTap: () async {
                          final result =
                          await Get.to(() => ReportDetailScreen(reportId: report.id));
                          if (result == 'deleted') ctrl.loadMyReports();
                        },
                      ),
                      if (report.status == 'pending') ...[
                        const SizedBox(width: 10),
                        _ActionBtn(
                          icon: Icons.edit_outlined,
                          label: 'Modifier',
                          color: AppTheme.primaryGreen,
                          onTap: () async {
                            final result =
                            await Get.to(() => EditReportScreen(report: report));
                            if (result == true) ctrl.loadMyReports();
                          },
                        ),
                        const SizedBox(width: 10),
                        Obx(() => _ActionBtn(
                          icon: ctrl.isDeletingId.value == report.id
                              ? Icons.hourglass_empty
                              : Icons.delete_outline,
                          label: 'Supprimer',
                          color: AppTheme.coral,
                          onTap: ctrl.isDeletingId.value == report.id
                              ? null
                              : () => _confirmDelete(context),
                        )),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    Get.defaultDialog(
      title: 'Supprimer',
      middleText: 'Voulez-vous supprimer "${report.title}" ?',
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

class _HelpBanner extends StatelessWidget {
  const _HelpBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.yellow.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.yellow.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppTheme.yellow.withOpacity(0.15),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(Icons.headset_mic_outlined, color: AppTheme.yellow, size: 22),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Besoin d\'aide ?', style: AppTheme.h3),
                SizedBox(height: 2),
                Text(
                  'Consultez nos conseils pour un signalement efficace',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: AppTheme.greyMedium,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppTheme.greyMedium),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? c : Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? c : Colors.white.withOpacity(0.3)),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isSelected ? AppTheme.darkBlue : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 3),
              Text(label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _ProfileSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          child: Column(
            children: children.asMap().entries.map((e) {
              final isLast = e.key == children.length - 1;
              return Column(
                children: [
                  e.value,
                  if (!isLast)
                    Divider(height: 1, color: AppTheme.greyLight.withOpacity(0.7), indent: 52),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ProfileOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final Widget? trailing;

  const _ProfileOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primaryGreen;
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: c.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: c, size: 18),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: color ?? AppTheme.darkBlue,
        ),
      ),
      trailing:
      trailing ?? const Icon(Icons.arrow_forward_ios_rounded, size: 13, color: AppTheme.greyMedium),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  final IconData icon, activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primaryGreen.withOpacity(0.1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isSelected ? activeIcon : icon,
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.greyMedium,
                  size: 22,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 9,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? AppTheme.primaryGreen : AppTheme.greyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: CircularProgressIndicator(color: AppTheme.primaryGreen),
      ),
    );
  }
}

class _EmptyReports extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyReports({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.cardShadow(),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.report_problem_outlined, size: 40, color: AppTheme.primaryGreen),
          ),
          const SizedBox(height: 14),
          const Text('Aucun signalement', style: AppTheme.h3),
          const SizedBox(height: 6),
          const Text(
            'Appuyez sur + pour créer\nvotre premier signalement',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: AppTheme.greyMedium,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 220,
            child: PrimaryActionButton(
                label: 'Faire un signalement', icon: Icons.send_rounded, onTap: onCreateTap),
          ),
        ],
      ),
    );
  }
}