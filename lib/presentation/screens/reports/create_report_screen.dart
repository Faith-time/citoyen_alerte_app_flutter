// lib/presentation/screens/reports/create_report_screen.dart
//
// Design Neo. La logique du controller est inchangée, sauf l'ajout de
// `reloadCategories()` (le bouton "Réessayer" appelait onInit(), qui
// relançait aussi la géolocalisation).

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/core/theme/neo_kit.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/data/models/category_model.dart';
import 'package:geocoding/geocoding.dart' as geo;
import 'report_neo_widgets.dart';

const List<String> kSenegalRegions = [
  'Dakar', 'Thiès', 'Diourbel', 'Fatick', 'Kaffrine', 'Kaolack',
  'Kédougou', 'Kolda', 'Louga', 'Matam', 'Saint-Louis', 'Sédhiou',
  'Tambacounda', 'Ziguinchor',
];

class MediaItem {
  final File file;
  final bool isVideo;
  MediaItem({required this.file, required this.isVideo});
}

// ─────────────────────────────────────────────────────────────────────────
// CONTROLLER (logique inchangée)
// ─────────────────────────────────────────────────────────────────────────

class CreateReportController extends GetxController {
  final ApiService  _api    = Get.find<ApiService>();
  final ImagePicker _picker = ImagePicker();

  final currentStep = 0.obs;

  final isLoadingCategories      = true.obs;
  final categories                = <CategoryModel>[].obs;
  final selectedParentCategoryId  = Rx<int?>(null);
  final selectedCategoryId        = Rx<int?>(null);
  final showingSubcategories      = false.obs;

  final selectedSeverity = 'medium'.obs;

  final mediaFiles = <MediaItem>[].obs;
  static const int maxMedia = 3;
  static const int maxVideoSeconds = 30;

  final isLocating      = false.obs;
  final selectedRegion  = Rx<String?>(null);
  final communeCtrl     = TextEditingController();
  final addressCtrl     = TextEditingController(text: 'Position localisée automatiquement');
  final latCtrl         = TextEditingController(text: '14.7167');
  final lngCtrl         = TextEditingController(text: '-17.4677');

  final showAdvancedText = false.obs;
  final titleCtrl        = TextEditingController();
  final descriptionCtrl  = TextEditingController();

  final isAnonymous = false.obs;
  final isLoading   = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadCategories();
    _autoLocate();
  }

  @override
  void onClose() {
    communeCtrl.dispose();
    addressCtrl.dispose();
    latCtrl.dispose();
    lngCtrl.dispose();
    titleCtrl.dispose();
    descriptionCtrl.dispose();
    super.onClose();
  }

  /// Recharge uniquement les catégories (bouton "Réessayer").
  Future<void> reloadCategories() => _loadCategories();

  Future<void> _loadCategories() async {
    try {
      isLoadingCategories.value = true;
      final response = await _api.getCategories();
      if (response.data != null) {
        final raw = response.data;
        List items = [];
        if (raw is Map) {
          items = (raw['data'] as List?) ?? [];
        } else if (raw is List) {
          items = raw;
        }
        final all = items
            .map((e) => CategoryModel.fromJson(e as Map<String, dynamic>))
            .toList();
        categories.assignAll(_dedupeCategories(all));
      }
    } catch (_) {
      // L'écran affiche déjà un état d'erreur avec bouton "Réessayer".
    } finally {
      isLoadingCategories.value = false;
    }
  }

  /// Protège contre des doublons éventuels côté base de données (ex: un
  /// seeder relancé par erreur, qui recrée les mêmes catégories avec de
  /// nouveaux ids). Sans autorité rattachée, un signalement créé sur un
  /// id "fantôme" ne serait jamais routé — donc on ne garde, pour chaque
  /// nom de catégorie, QUE celle avec le plus petit id (la version
  /// d'origine, celle qui a une vraie correspondance vers une autorité).
  List<CategoryModel> _dedupeCategories(List<CategoryModel> all) {
    final sorted = [...all]..sort((a, b) => a.id.compareTo(b.id));

    final parents = sorted.where((c) => c.parentId == null).toList();
    final Map<String, CategoryModel> keptParentByName = {};
    final Map<int, int> parentIdRedirect = {};

    for (final p in parents) {
      final key = p.name.trim().toLowerCase();
      final kept = keptParentByName[key];
      if (kept == null) {
        keptParentByName[key] = p;
        parentIdRedirect[p.id] = p.id;
      } else {
        parentIdRedirect[p.id] = kept.id;
      }
    }

    final children = sorted.where((c) => c.parentId != null).toList();
    final Map<String, CategoryModel> keptChildByKey = {};

    for (final c in children) {
      final canonicalParentId = parentIdRedirect[c.parentId] ?? c.parentId;
      final key = '$canonicalParentId::${c.name.trim().toLowerCase()}';
      final existing = keptChildByKey[key];
      if (existing == null) {
        keptChildByKey[key] = c.parentId == canonicalParentId
            ? c
            : c.copyWith(parentId: canonicalParentId);
      }
    }

    return [...keptParentByName.values, ...keptChildByKey.values];
  }

  List<CategoryModel> get parentCategories => categories.where((c) => c.parentId == null).toList();
  List<CategoryModel> get subCategories => selectedParentCategoryId.value == null
      ? []
      : categories.where((c) => c.parentId == selectedParentCategoryId.value).toList();

  int? get effectiveCategoryId => selectedCategoryId.value ?? selectedParentCategoryId.value;

  String get categoryLabel {
    final id = effectiveCategoryId;
    if (id == null) return 'Signalement';
    final match = categories.firstWhereOrNull((c) => c.id == id);
    return match?.name ?? 'Signalement';
  }

  void selectParentCategory(int id) {
    selectedParentCategoryId.value = id;
    selectedCategoryId.value = null;
    final hasSubs = categories.any((c) => c.parentId == id);
    if (hasSubs) {
      showingSubcategories.value = true;
    } else {
      _goToStep(1);
    }
  }

  void selectSubcategory(int id) {
    selectedCategoryId.value = id;
    showingSubcategories.value = false;
    _goToStep(1);
  }

  void backFromSubcategories() {
    showingSubcategories.value = false;
    selectedParentCategoryId.value = null;
  }

  void _goToStep(int step) => currentStep.value = step;

  bool goNext() {
    if (currentStep.value == 0) {
      if (effectiveCategoryId == null) {
        _snack('Choisissez un problème', 'Appuyez sur une icône pour continuer', AppTheme.warning);
        return false;
      }
    }
    // Le média (photo/vidéo) est optionnel.
    if (currentStep.value < 2) {
      currentStep.value++;
      return true;
    }
    return true;
  }

  void goPrev() {
    if (currentStep.value > 0) currentStep.value--;
  }

  // ── Géolocalisation ──────────────────────────────────────────────────

  final detectedRegion  = Rx<String?>(null);
  final detectedCommune = Rx<String?>(null);
  final detectedAddress = Rx<String?>(null);
  final isReverseGeocoding = false.obs;
  final geocodeFailed = false.obs;

  static const Map<String, String> _regionAliases = {
    'dakar': 'Dakar',
    'thies': 'Thiès', 'thiès': 'Thiès',
    'diourbel': 'Diourbel',
    'fatick': 'Fatick',
    'kaffrine': 'Kaffrine',
    'kaolack': 'Kaolack',
    'kedougou': 'Kédougou', 'kédougou': 'Kédougou',
    'kolda': 'Kolda',
    'louga': 'Louga',
    'matam': 'Matam',
    'saint-louis': 'Saint-Louis', 'saint louis': 'Saint-Louis',
    'sedhiou': 'Sédhiou', 'sédhiou': 'Sédhiou',
    'tambacounda': 'Tambacounda',
    'ziguinchor': 'Ziguinchor',
  };

  String? _matchRegion(String? raw) {
    if (raw == null) return null;
    final key = raw.trim().toLowerCase();
    if (_regionAliases.containsKey(key)) return _regionAliases[key];
    for (final entry in _regionAliases.entries) {
      if (key.contains(entry.key)) return entry.value;
    }
    return null;
  }

  Future<void> locateMe({bool silent = false}) async {
    try {
      isLocating.value = true;
      geocodeFailed.value = false;

      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!silent) _snack('GPS désactivé', 'Activez la localisation', AppTheme.warning);
        geocodeFailed.value = true;
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        geocodeFailed.value = true;
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
      );
      latCtrl.text = pos.latitude.toStringAsFixed(6);
      lngCtrl.text = pos.longitude.toStringAsFixed(6);

      await _reverseGeocode(pos.latitude, pos.longitude);

      if (!silent) _snack('Position trouvée ✓', '', AppTheme.success);
    } catch (_) {
      if (!silent) _snack('Position introuvable', 'Réessayez près d\'une fenêtre', AppTheme.error);
      geocodeFailed.value = true;
    } finally {
      isLocating.value = false;
    }
  }

  Future<void> _reverseGeocode(double lat, double lng) async {
    try {
      isReverseGeocoding.value = true;
      final placemarks = await geo.placemarkFromCoordinates(lat, lng);
      if (placemarks.isEmpty) {
        geocodeFailed.value = true;
        return;
      }
      final p = placemarks.first;

      final region = _matchRegion(p.administrativeArea) ?? _matchRegion(p.subAdministrativeArea);

      final commune = (p.subLocality?.isNotEmpty ?? false)
          ? p.subLocality
          : (p.locality?.isNotEmpty ?? false) ? p.locality : p.subAdministrativeArea;

      final addressParts = [p.street, p.subLocality, p.locality]
          .where((s) => s != null && s.isNotEmpty)
          .toList();
      final address = addressParts.isNotEmpty ? addressParts.join(', ') : null;

      if (region == null || commune == null || commune.isEmpty) {
        geocodeFailed.value = true;
      } else {
        detectedRegion.value  = region;
        detectedCommune.value = commune;
        detectedAddress.value = address ?? commune;

        selectedRegion.value = region;
        communeCtrl.text     = commune;
        addressCtrl.text     = address ?? commune;
      }
    } catch (_) {
      geocodeFailed.value = true;
    } finally {
      isReverseGeocoding.value = false;
    }
  }

  Future<void> _autoLocate() => locateMe(silent: true);

  // ── Médias (photo + vidéo) ──────────────────────────────────────────

  Future<void> takePhoto() async {
    if (mediaFiles.length >= maxMedia) {
      _snack('Maximum atteint', 'Vous avez déjà $maxMedia médias', AppTheme.warning);
      return;
    }
    try {
      final file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file != null) mediaFiles.add(MediaItem(file: File(file.path), isVideo: false));
    } catch (_) {}
  }

  Future<void> recordVideo() async {
    if (mediaFiles.length >= maxMedia) {
      _snack('Maximum atteint', 'Vous avez déjà $maxMedia médias', AppTheme.warning);
      return;
    }
    try {
      final file = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: maxVideoSeconds),
      );
      if (file != null) mediaFiles.add(MediaItem(file: File(file.path), isVideo: true));
    } catch (_) {}
  }

  Future<void> pickFromGallery({bool video = false}) async {
    if (mediaFiles.length >= maxMedia) return;
    try {
      final file = video
          ? await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: maxVideoSeconds),
      )
          : await _picker.pickImage(
          source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (file != null) mediaFiles.add(MediaItem(file: File(file.path), isVideo: video));
    } catch (_) {}
  }

  void removeMedia(int i) {
    if (i >= 0 && i < mediaFiles.length) mediaFiles.removeAt(i);
  }

  // ── Texte auto-généré ────────────────────────────────────────────────

  String get _autoTitle {
    final zone = communeCtrl.text.trim().isNotEmpty ? communeCtrl.text.trim() : (selectedRegion.value ?? '');
    return zone.isEmpty ? categoryLabel : '$categoryLabel — $zone';
  }

  String get _autoDescription {
    final zone = communeCtrl.text.trim().isNotEmpty ? communeCtrl.text.trim() : 'la zone signalée';
    return 'Signalement envoyé par un citoyen : $categoryLabel à $zone.';
  }

  // ── Soumission ───────────────────────────────────────────────────────

  Future<void> submitReport() async {
    if (selectedRegion.value == null || communeCtrl.text.trim().isEmpty) {
      _snack('Position requise', 'Vérifiez ou corrigez votre position', AppTheme.warning);
      return;
    }

    try {
      isLoading.value = true;

      final title = titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : _autoTitle;
      final description = descriptionCtrl.text.trim().isNotEmpty ? descriptionCtrl.text.trim() : _autoDescription;

      final formData = FormData.fromMap({
        'category_id': effectiveCategoryId.toString(),
        'title': title,
        'description': description,
        'latitude': latCtrl.text.trim(),
        'longitude': lngCtrl.text.trim(),
        'address': addressCtrl.text.trim(),
        'commune_name': communeCtrl.text.trim(),
        'region_name': selectedRegion.value,
        'severity': selectedSeverity.value,
        'is_anonymous': isAnonymous.value ? '1' : '0',
      });

      final response = await _api.createReport(formData);
      final rawData = response.data as Map<String, dynamic>?;
      if (rawData == null) {
        _snack('Erreur', response.message ?? 'Une erreur est survenue', AppTheme.error);
        return;
      }

      final reportId = rawData['id'] as int?;
      if (reportId != null) await _uploadMedia(reportId: reportId);

      Get.back(result: true);
      _snack('Envoyé ✓', 'Merci pour votre signalement', AppTheme.success);
    } catch (_) {
      _snack('Erreur', 'Impossible d\'envoyer le signalement', AppTheme.error);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _uploadMedia({required int reportId}) async {
    for (int i = 0; i < mediaFiles.length; i++) {
      try {
        final m = mediaFiles[i];
        final ext = m.isVideo ? 'mp4' : 'jpg';
        final fd = FormData.fromMap({
          'image': await MultipartFile.fromFile(m.file.path, filename: 'media_${reportId}_$i.$ext'),
          'type': 'initial',
        });
        await _api.uploadReportImage(reportId, fd);
      } catch (_) {}
    }
  }

  void _snack(String title, String msg, Color color) {
    Get.snackbar(title, msg,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: color, colorText: Colors.white,
        margin: const EdgeInsets.all(16), borderRadius: 14,
        duration: const Duration(seconds: 2));
  }
}

// ─────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────

class CreateReportScreen extends StatefulWidget {
  const CreateReportScreen({super.key});

  @override
  State<CreateReportScreen> createState() => _CreateReportScreenState();
}

class _CreateReportScreenState extends State<CreateReportScreen> {
  late final CreateReportController ctrl;

  static const _stepLabels = ['Le problème', 'Photo et gravité', 'Le lieu'];

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(CreateReportController());
  }

  @override
  void dispose() {
    Get.delete<CreateReportController>();
    super.dispose();
  }

  void _onBack() {
    if (ctrl.showingSubcategories.value) {
      ctrl.backFromSubcategories();
    } else if (ctrl.currentStep.value > 0) {
      ctrl.goPrev();
    } else {
      Get.back();
    }
  }

  String _subtitle() {
    if (ctrl.showingSubcategories.value) return 'Précisez le problème';
    final i = ctrl.currentStep.value;
    return 'Étape ${i + 1}/3 · ${_stepLabels[i.clamp(0, 2).toInt()]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Neo.bg,
      body: NeoBackdrop(
        child: Column(children: [
          Obx(() => NeoTitleBar(
            title: 'Faire un signalement',
            subtitle: _subtitle(),
            leading: NeoIconButton(icon: Icons.arrow_back_ios_new_rounded, onTap: _onBack),
          )),
          Obx(() => _StepDots(currentStep: ctrl.currentStep.value)),
          const SizedBox(height: 4),
          Expanded(
            child: Obx(() {
              if (ctrl.showingSubcategories.value) {
                return _StepSubcategory(key: const ValueKey('step-sub'), ctrl: ctrl);
              }
              switch (ctrl.currentStep.value) {
                case 0:
                  return _StepCategory(key: const ValueKey('step-0'), ctrl: ctrl);
                case 1:
                  return _StepPhotoSeverity(key: const ValueKey('step-1'), ctrl: ctrl);
                case 2:
                  return _StepLocation(key: const ValueKey('step-2'), ctrl: ctrl);
                default:
                  return const SizedBox.shrink(key: ValueKey('step-default'));
              }
            }),
          ),
          Obx(() {
            if (ctrl.showingSubcategories.value) return const SizedBox.shrink();
            final isLast = ctrl.currentStep.value == 2;
            final loading = ctrl.isLoading.value;
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: NeoButton(
                    label: loading ? 'Envoi en cours…' : (isLast ? 'Envoyer' : 'Suivant'),
                    onTap: loading
                        ? null
                        : () {
                      if (isLast) {
                        ctrl.submitReport();
                      } else {
                        ctrl.goNext();
                      }
                    },
                  ),
                ),
              ),
            );
          }),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// INDICATEUR D'ÉTAPES — icônes uniquement
// ─────────────────────────────────────────────────────────────────────────

class _StepDots extends StatelessWidget {
  final int currentStep;
  const _StepDots({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const icons = [Icons.category_rounded, Icons.camera_alt_rounded, Icons.place_rounded];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(icons.length * 2 - 1, (i) {
          if (i.isOdd) {
            final done = (i ~/ 2) < currentStep;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 34,
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: done ? Neo.blue : Neo.line,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }
          final idx = i ~/ 2;
          final active = idx <= currentStep;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: active ? Neo.blue : Neo.surface,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: Neo.softRelief(),
            ),
            child: Icon(icons[idx], size: 19, color: active ? Colors.white : Neo.muted),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// ÉTAPE 1 — CATÉGORIE
// ─────────────────────────────────────────────────────────────────────────

IconData categoryIconFor(String? name) {
  final n = (name ?? '').toLowerCase();
  if (n.contains('propret')) return Icons.delete_outline_rounded;
  if (n.contains('voirie') || n.contains('route')) return Icons.traffic_rounded;
  if (n.contains('clairage') || n.contains('lumi')) return Icons.lightbulb_outline_rounded;
  if (n.contains('environ')) return Icons.park_outlined;
  if (n.contains('curit')) return Icons.security_outlined;
  if (n.contains('eau')) return Icons.water_drop_outlined;
  if (n.contains('lectri')) return Icons.electrical_services_outlined;
  if (n.contains('batiment') || n.contains('bâtiment')) return Icons.apartment_outlined;
  if (n.contains('transport') || n.contains('bus')) return Icons.directions_bus_outlined;
  return Icons.report_problem_outlined;
}

class _StepCategory extends StatelessWidget {
  final CreateReportController ctrl;
  const _StepCategory({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLoading = ctrl.isLoadingCategories.value;
      final selectedId = ctrl.selectedParentCategoryId.value;
      final parents = ctrl.categories.where((c) => c.parentId == null).toList();

      return SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quel est le problème ?', style: Neo.t(20, w: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Appuyez sur une image', style: Neo.t(13, c: Neo.muted)),
            const SizedBox(height: 20),
            if (isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator(color: Neo.blue)),
              )
            else if (parents.isEmpty)
              Column(children: [
                const NeoEmpty(
                  icon: Icons.wifi_off_rounded,
                  title: 'Impossible de charger',
                  message: 'Vérifiez votre connexion et réessayez.',
                ),
                const SizedBox(height: 12),
                NeoButton(label: 'Réessayer', onTap: ctrl.reloadCategories),
              ])
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: parents.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (_, i) {
                  final cat = parents[i];
                  return _CategoryTile(
                    label: cat.name,
                    icon: categoryIconFor(cat.name),
                    selected: selectedId == cat.id,
                    onTap: () => ctrl.selectParentCategory(cat.id),
                  );
                },
              ),
          ],
        ),
      );
    });
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryTile({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return NeoPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? Neo.blue : Neo.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: selected ? Neo.blue : Colors.white, width: 2),
          boxShadow: Neo.softRelief(),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? Colors.white.withValues(alpha: 0.2)
                    : Neo.blue.withValues(alpha: 0.10),
              ),
              child: Icon(icon, size: 28, color: selected ? Colors.white : Neo.blue),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Neo.t(13, w: FontWeight.w700, c: selected ? Colors.white : Neo.ink),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepSubcategory extends StatelessWidget {
  final CreateReportController ctrl;
  const _StepSubcategory({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final subs = ctrl.subCategories;
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Précisez', style: Neo.t(20, w: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Quel type de problème exactement ?', style: Neo.t(13, c: Neo.muted)),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: subs.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.05,
                ),
                itemBuilder: (_, i) {
                  final sub = subs[i];
                  return _CategoryTile(
                    label: sub.name,
                    icon: categoryIconFor(sub.name),
                    selected: false,
                    onTap: () => ctrl.selectSubcategory(sub.id),
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────
// ÉTAPE 2 — MÉDIA (facultatif) + GRAVITÉ
// ─────────────────────────────────────────────────────────────────────────

class _StepPhotoSeverity extends StatelessWidget {
  final CreateReportController ctrl;
  const _StepPhotoSeverity({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ajoutez une photo ou une vidéo', style: Neo.t(20, w: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('Facultatif · ça aide les agents à comprendre le problème',
              style: Neo.t(13, c: Neo.muted)),
          const SizedBox(height: 20),

          Obx(() {
            if (ctrl.mediaFiles.isEmpty) {
              return Row(
                key: const ValueKey('media-empty'),
                children: [
                  Expanded(
                    child: _BigMediaButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Photo',
                      onTap: ctrl.takePhoto,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _BigMediaButton(
                      icon: Icons.videocam_rounded,
                      label: 'Vidéo (${CreateReportController.maxVideoSeconds}s max)',
                      onTap: ctrl.recordVideo,
                    ),
                  ),
                ],
              );
            }
            return SizedBox(
              key: const ValueKey('media-list'),
              height: 140,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                children: [
                  ...ctrl.mediaFiles.asMap().entries.map((e) => _MediaThumb(
                    key: ValueKey('media-${e.key}-${e.value.file.path}'),
                    item: e.value,
                    onRemove: () => ctrl.removeMedia(e.key),
                  )),
                  if (ctrl.mediaFiles.length < CreateReportController.maxMedia)
                    GestureDetector(
                      key: const ValueKey('add-media-tile'),
                      onTap: ctrl.takePhoto,
                      onLongPress: ctrl.recordVideo,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: Neo.blue.withValues(alpha: 0.06),
                          border: Border.all(color: Neo.blue.withValues(alpha: 0.35), width: 1.5),
                        ),
                        child: const Icon(Icons.add_a_photo_rounded, color: Neo.blue, size: 34),
                      ),
                    ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => ctrl.pickFromGallery(video: false),
                  icon: const Icon(Icons.photo_library_outlined, size: 16, color: Neo.muted),
                  label: Text('Photo depuis la galerie', style: Neo.t(12, c: Neo.muted)),
                ),
                TextButton.icon(
                  onPressed: () => ctrl.pickFromGallery(video: true),
                  icon: const Icon(Icons.video_library_outlined, size: 16, color: Neo.muted),
                  label: Text('Vidéo depuis la galerie', style: Neo.t(12, c: Neo.muted)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          Text("C'est grave ?", style: Neo.t(20, w: FontWeight.w800)),
          const SizedBox(height: 16),
          Obx(() => Row(
            children: [
              Expanded(
                child: _SeverityTile(
                  emoji: '😌',
                  label: 'Non',
                  color: Neo.success,
                  selected: ctrl.selectedSeverity.value == 'low',
                  onTap: () => ctrl.selectedSeverity.value = 'low',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SeverityTile(
                  emoji: '🙁',
                  label: 'Un peu',
                  color: Neo.warning,
                  selected: ctrl.selectedSeverity.value == 'medium',
                  onTap: () => ctrl.selectedSeverity.value = 'medium',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SeverityTile(
                  emoji: '🚨',
                  label: 'Urgent',
                  color: Neo.danger,
                  selected: ctrl.selectedSeverity.value == 'high',
                  onTap: () => ctrl.selectedSeverity.value = 'high',
                ),
              ),
            ],
          )),
        ],
      ),
    );
  }
}

class _BigMediaButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _BigMediaButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return NeoPressable(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Neo.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: Neo.softRelief(),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Neo.blue.withValues(alpha: 0.10),
              ),
              child: Icon(icon, size: 30, color: Neo.blue),
            ),
            const SizedBox(height: 10),
            Text(label,
                textAlign: TextAlign.center,
                style: Neo.t(13, w: FontWeight.w700, c: Neo.blue)),
          ],
        ),
      ),
    );
  }
}

class _MediaThumb extends StatelessWidget {
  final MediaItem item;
  final VoidCallback onRemove;
  const _MediaThumb({super.key, required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      height: 140,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: Neo.softRelief(),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: item.isVideo
                ? Container(
              width: 134,
              height: 134,
              color: Neo.ink,
              child: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 40),
            )
                : Image.file(item.file, width: 134, height: 134, fit: BoxFit.cover),
          ),
          if (item.isVideo)
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Neo.ink,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('VIDÉO', style: Neo.t(9.5, w: FontWeight.w800, c: Colors.white)),
              ),
            ),
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(color: Neo.danger, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityTile extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _SeverityTile({
    required this.emoji,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return NeoPressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color : Neo.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? color : Colors.white, width: 2),
          boxShadow: Neo.softRelief(),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 34)),
            const SizedBox(height: 4),
            Text(label, style: Neo.t(12, w: FontWeight.w700, c: selected ? Colors.white : color)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// ÉTAPE 3 — LIEU (détection auto + repli manuel)
// ─────────────────────────────────────────────────────────────────────────

class _StepLocation extends StatelessWidget {
  final CreateReportController ctrl;
  const _StepLocation({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Où est le problème ?', style: Neo.t(20, w: FontWeight.w800)),
          const SizedBox(height: 16),

          Obx(() {
            if (ctrl.isLocating.value || ctrl.isReverseGeocoding.value) {
              return const _LocatingCard();
            }
            if (ctrl.geocodeFailed.value) {
              return _ManualLocationFallback(ctrl: ctrl);
            }
            return _DetectedLocationCard(ctrl: ctrl);
          }),

          const SizedBox(height: 20),
          NeoCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Obx(() => Row(
              children: [
                const Icon(Icons.privacy_tip_outlined, color: Neo.blue, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Rester anonyme', style: Neo.t(13, w: FontWeight.w600)),
                ),
                Switch(
                  value: ctrl.isAnonymous.value,
                  activeTrackColor: Neo.blue,
                  inactiveTrackColor: Neo.inset,
                  thumbColor: WidgetStateProperty.all(Colors.white),
                  trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                  onChanged: (v) => ctrl.isAnonymous.value = v,
                ),
              ],
            )),
          ),

          const SizedBox(height: 12),
          Obx(() => TextButton(
            onPressed: () => ctrl.showAdvancedText.value = !ctrl.showAdvancedText.value,
            child: Text(
              ctrl.showAdvancedText.value
                  ? 'Masquer le texte du signalement'
                  : 'Écrire un texte personnalisé (optionnel)',
              style: Neo.t(12, c: Neo.muted),
            ),
          )),
          Obx(() {
            if (!ctrl.showAdvancedText.value) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                ReportNeoField(
                  controller: ctrl.titleCtrl,
                  hint: ctrl.categoryLabel,
                  icon: Icons.title_rounded,
                ),
                const SizedBox(height: 10),
                ReportNeoField(
                  controller: ctrl.descriptionCtrl,
                  hint: 'Décrivez le problème...',
                  icon: Icons.description_outlined,
                  maxLines: 3,
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _LocatingCard extends StatelessWidget {
  const _LocatingCard();

  @override
  Widget build(BuildContext context) {
    return NeoCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: Neo.blue),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text('Localisation en cours...', style: Neo.t(14, c: Neo.muted)),
          ),
        ],
      ),
    );
  }
}

class _DetectedLocationCard extends StatelessWidget {
  final CreateReportController ctrl;
  const _DetectedLocationCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NeoCard(
          padding: const EdgeInsets.all(16),
          borderColor: Neo.blue.withValues(alpha: 0.35),
          child: Row(
            children: [
              const NeoIconBadge(icon: Icons.location_on_rounded, color: Neo.blue, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ctrl.detectedCommune.value ?? '',
                        style: Neo.t(15, w: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(ctrl.detectedRegion.value ?? '',
                        style: Neo.t(13, c: Neo.muted)),
                  ],
                )),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          children: [
            TextButton.icon(
              onPressed: () => ctrl.locateMe(),
              icon: const Icon(Icons.refresh_rounded, size: 16, color: Neo.blue),
              label: Text('Actualiser', style: Neo.t(12, c: Neo.blue)),
            ),
            TextButton.icon(
              onPressed: () => ctrl.geocodeFailed.value = true,
              icon: const Icon(Icons.edit_outlined, size: 16, color: Neo.muted),
              label: Text("Ce n'est pas ça", style: Neo.t(12, c: Neo.muted)),
            ),
          ],
        ),
      ],
    );
  }
}

class _ManualLocationFallback extends StatelessWidget {
  final CreateReportController ctrl;
  const _ManualLocationFallback({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => ctrl.locateMe(),
            icon: const Icon(Icons.my_location_rounded, size: 16, color: Neo.blue),
            label: Text('Réessayer la détection automatique', style: Neo.t(12, c: Neo.blue)),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
          ),
        ),
        const SizedBox(height: 16),

        Text('Choisissez votre région', style: Neo.t(14, w: FontWeight.w700)),
        const SizedBox(height: 10),
        Obx(() => Wrap(
          spacing: 10,
          runSpacing: 10,
          children: kSenegalRegions
              .map((r) => NeoChip(
            label: r,
            selected: ctrl.selectedRegion.value == r,
            onTap: () => ctrl.selectedRegion.value = r,
          ))
              .toList(),
        )),

        const SizedBox(height: 20),
        Text('Quartier ou commune', style: Neo.t(14, w: FontWeight.w700)),
        const SizedBox(height: 10),
        ReportNeoField(
          controller: ctrl.communeCtrl,
          hint: 'Ex: Parcelles Assainies',
          icon: Icons.location_city_outlined,
        ),

        const SizedBox(height: 20),
        Text('Repère (optionnel)', style: Neo.t(14, w: FontWeight.w700)),
        const SizedBox(height: 10),
        ReportNeoField(
          controller: ctrl.addressCtrl,
          hint: 'Ex: près du marché',
          icon: Icons.signpost_outlined,
        ),
      ],
    );
  }
}