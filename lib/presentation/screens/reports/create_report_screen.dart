import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/data/models/category_model.dart';
import 'package:geocoding/geocoding.dart' as geo;

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

    // 1) Catégories parentes : on garde la plus ancienne par nom, et on
    //    construit une table de correspondance ANCIEN id parent -> id
    //    parent conservé, pour pouvoir rattacher correctement les
    //    sous-catégories ensuite.
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

    // 2) Sous-catégories : on les rattache d'abord au parent conservé
    //    (au cas où elles pointaient vers un parent en doublon), puis on
    //    déduplique par (parent conservé, nom).
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
      // Si un doublon a un id plus petit, "sorted" garantit qu'on a déjà
      // traité le plus petit id en premier, donc rien à faire de plus.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: Container(
          decoration: const BoxDecoration(
            color: AppTheme.primaryGreen,
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                        onPressed: () {
                          if (ctrl.showingSubcategories.value) {
                            ctrl.backFromSubcategories();
                          } else if (ctrl.currentStep.value > 0) {
                            ctrl.goPrev();
                          } else {
                            Get.back();
                          }
                        },
                      ),
                      const Expanded(
                        child: Text('Faire un signalement',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Obx(() => _BigStepDots(currentStep: ctrl.currentStep.value)),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
      body: Obx(() {
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
      bottomNavigationBar: Obx(() {
        if (ctrl.showingSubcategories.value) return const SizedBox.shrink();
        final isLast = ctrl.currentStep.value == 2;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Color(0x10000000), blurRadius: 12, offset: Offset(0, -4))],
          ),
          child: SizedBox(
            height: 58,
            child: ElevatedButton(
              onPressed: ctrl.isLoading.value
                  ? null
                  : () {
                if (isLast) {
                  ctrl.submitReport();
                } else {
                  ctrl.goNext();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                disabledBackgroundColor: AppTheme.greyLight,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: ctrl.isLoading.value
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(isLast ? 'Envoyer' : 'Suivant',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(width: 8),
                  Icon(isLast ? Icons.send_rounded : Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// INDICATEUR D'ÉTAPES — icônes uniquement, pas de texte
// ─────────────────────────────────────────────────────────────────────────

class _BigStepDots extends StatelessWidget {
  final int currentStep;
  const _BigStepDots({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    const icons = [Icons.category_rounded, Icons.camera_alt_rounded, Icons.place_rounded];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(icons.length * 2 - 1, (i) {
        if (i.isOdd) {
          final done = (i ~/ 2) < currentStep;
          return Container(width: 30, height: 2, color: done ? Colors.white : Colors.white.withOpacity(0.3));
        }
        final idx = i ~/ 2;
        final done = idx <= currentStep;
        final current = idx == currentStep;
        return Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            color: done ? Colors.white : Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
            border: current ? Border.all(color: Colors.white, width: 2.5) : null,
          ),
          child: Icon(icons[idx], size: 18, color: done ? AppTheme.primaryGreen : Colors.white.withOpacity(0.7)),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// ÉTAPE 1 — CATÉGORIE (icônes géantes)
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

class _StepCategory extends StatefulWidget {
  final CreateReportController ctrl;
  const _StepCategory({super.key, required this.ctrl});

  @override
  State<_StepCategory> createState() => _StepCategoryState();
}

class _StepCategoryState extends State<_StepCategory> {
  @override
  void initState() {
    super.initState();
    widget.ctrl.isLoadingCategories.listen((_) { if (mounted) setState(() {}); });
    widget.ctrl.categories.listen((_)         { if (mounted) setState(() {}); });
    widget.ctrl.selectedParentCategoryId.listen((_) { if (mounted) setState(() {}); });
  }

  @override
  Widget build(BuildContext context) {
    final isLoading  = widget.ctrl.isLoadingCategories.value;
    final allCats    = widget.ctrl.categories.toList();
    final selectedId = widget.ctrl.selectedParentCategoryId.value;
    final parents    = allCats.where((c) => c.parentId == null).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quel est le problème ?',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 19,
                  fontWeight: FontWeight.w800, color: AppTheme.darkBlue)),
          const SizedBox(height: 4),
          const Text('Appuyez sur une image',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13,
                  color: AppTheme.greyMedium)),
          const SizedBox(height: 20),

          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(60),
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              ),
            )
          else if (parents.isEmpty)
            _BigErrorCard(onRetry: widget.ctrl.onInit)
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
                return _BigCategoryTile(
                  label: cat.name,
                  icon: categoryIconFor(cat.name),
                  selected: selectedId == cat.id,
                  onTap: () => widget.ctrl.selectParentCategory(cat.id),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _BigCategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _BigCategoryTile({super.key, required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryGreen : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? AppTheme.primaryGreen : AppTheme.greyLight, width: selected ? 2 : 1),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 3))],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: selected ? Colors.white : AppTheme.primaryGreen),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(label,
                    textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppTheme.darkBlue)),
              ),
            ],
          ),
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Précisez',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 19, fontWeight: FontWeight.w800, color: AppTheme.darkBlue)),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              itemCount: ctrl.subCategories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, crossAxisSpacing: 14, mainAxisSpacing: 14, childAspectRatio: 1.05,
              ),
              itemBuilder: (_, i) {
                final sub = ctrl.subCategories[i];
                return _BigCategoryTile(
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
  }
}

// ─────────────────────────────────────────────────────────────────────────
// ÉTAPE 2 — MÉDIA (photo ou vidéo, facultatif) + GRAVITÉ
// ─────────────────────────────────────────────────────────────────────────

class _StepPhotoSeverity extends StatelessWidget {
  final CreateReportController ctrl;
  const _StepPhotoSeverity({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Ajoutez une photo ou une vidéo (facultatif)',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 19, fontWeight: FontWeight.w800, color: AppTheme.darkBlue)),
          const SizedBox(height: 4),
          const Text('Ça aide les agents à mieux comprendre le problème',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppTheme.greyMedium)),
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
            return Column(
              key: const ValueKey('media-list'),
              children: [
                SizedBox(
                  height: 140,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ...ctrl.mediaFiles.asMap().entries.map((e) => Container(
                        key: ValueKey('media-${e.key}-${e.value.file.path}'),
                        width: 140,
                        height: 140,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.greyLight)),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: e.value.isVideo
                                  ? Container(
                                width: 140,
                                height: 140,
                                color: AppTheme.darkBlue,
                                child: const Icon(Icons.play_circle_fill_rounded,
                                    color: Colors.white, size: 40),
                              )
                                  : Image.file(e.value.file, width: 140, height: 140, fit: BoxFit.cover),
                            ),
                            if (e.value.isVideo)
                              const Positioned(
                                bottom: 6,
                                left: 6,
                                child: _MediaTag(label: 'VIDÉO'),
                              ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: () => ctrl.removeMedia(e.key),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(color: AppTheme.error, shape: BoxShape.circle),
                                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                      if (ctrl.mediaFiles.length < CreateReportController.maxMedia)
                        Container(
                          key: const ValueKey('add-media-tile'),
                          width: 140,
                          height: 140,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.4)),
                            color: AppTheme.primaryGreen.withOpacity(0.05),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: ctrl.takePhoto,
                              onLongPress: ctrl.recordVideo,
                              child: const Icon(Icons.add_a_photo_rounded, color: AppTheme.primaryGreen, size: 34),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }),

          const SizedBox(height: 8),
          Center(
            child: Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => ctrl.pickFromGallery(video: false),
                  icon: const Icon(Icons.photo_library_outlined, size: 16, color: AppTheme.greyMedium),
                  label: const Text('Photo depuis la galerie',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.greyMedium)),
                ),
                TextButton.icon(
                  onPressed: () => ctrl.pickFromGallery(video: true),
                  icon: const Icon(Icons.video_library_outlined, size: 16, color: AppTheme.greyMedium),
                  label: const Text('Vidéo depuis la galerie',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.greyMedium)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          const Text('C\'est grave ?',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 19, fontWeight: FontWeight.w800, color: AppTheme.darkBlue)),
          const SizedBox(height: 16),
          Obx(() => Row(
            children: [
              Expanded(
                  child: _EmojiSeverityBtn(
                      emoji: '😌',
                      label: 'Non',
                      color: AppTheme.success,
                      selected: ctrl.selectedSeverity.value == 'low',
                      onTap: () => ctrl.selectedSeverity.value = 'low')),
              const SizedBox(width: 10),
              Expanded(
                  child: _EmojiSeverityBtn(
                      emoji: '🙁',
                      label: 'Un peu',
                      color: AppTheme.warning,
                      selected: ctrl.selectedSeverity.value == 'medium',
                      onTap: () => ctrl.selectedSeverity.value = 'medium')),
              const SizedBox(width: 10),
              Expanded(
                  child: _EmojiSeverityBtn(
                      emoji: '🚨',
                      label: 'Urgent',
                      color: AppTheme.error,
                      selected: ctrl.selectedSeverity.value == 'high',
                      onTap: () => ctrl.selectedSeverity.value = 'high')),
            ],
          )),
          const SizedBox(height: 90),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 140,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppTheme.primaryGreen.withOpacity(0.08),
            border: Border.all(color: AppTheme.primaryGreen, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: AppTheme.primaryGreen),
              const SizedBox(height: 8),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryGreen)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaTag extends StatelessWidget {
  final String label;
  const _MediaTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.darkBlue,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)],
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _EmojiSeverityBtn extends StatelessWidget {
  final String emoji;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _EmojiSeverityBtn({required this.emoji, required this.label, required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected ? color : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? color : AppTheme.greyLight, width: selected ? 2 : 1),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 34)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : color)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// ÉTAPE 3 — LIEU (détection auto + repli manuel) + envoi
// ─────────────────────────────────────────────────────────────────────────

class _StepLocation extends StatelessWidget {
  final CreateReportController ctrl;
  const _StepLocation({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Où est le problème ?',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 19, fontWeight: FontWeight.w800, color: AppTheme.darkBlue)),
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(14)),
            child: Obx(() => Row(
              children: [
                const Icon(Icons.privacy_tip_outlined, color: AppTheme.primaryGreen, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Rester anonyme',
                      style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.darkBlue)),
                ),
                Switch(
                  value: ctrl.isAnonymous.value,
                  activeColor: AppTheme.primaryGreen,
                  onChanged: (v) => ctrl.isAnonymous.value = v,
                ),
              ],
            )),
          ),

          const SizedBox(height: 16),
          Obx(() => TextButton(
            onPressed: () => ctrl.showAdvancedText.value = !ctrl.showAdvancedText.value,
            child: Text(
              ctrl.showAdvancedText.value
                  ? 'Masquer le texte du signalement'
                  : 'Écrire un texte personnalisé (optionnel)',
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.greyMedium),
            ),
          )),
          Obx(() {
            if (!ctrl.showAdvancedText.value) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                _SimpleField(
                  controller: ctrl.titleCtrl,
                  hint: ctrl.categoryLabel,
                  icon: Icons.title_rounded,
                ),
                const SizedBox(height: 10),
                _SimpleField(
                  controller: ctrl.descriptionCtrl,
                  hint: 'Décrivez le problème...',
                  icon: Icons.description_outlined,
                  maxLines: 3,
                ),
              ],
            );
          }),

          const SizedBox(height: 90),
        ],
      ),
    );
  }
}

class _LocatingCard extends StatelessWidget {
  const _LocatingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppTheme.background, borderRadius: BorderRadius.circular(16)),
      child: const Row(
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: AppTheme.primaryGreen)),
          SizedBox(width: 14),
          Expanded(
            child: Text('Localisation en cours...',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppTheme.greyMedium)),
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.location_on_rounded, color: AppTheme.primaryGreen, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Obx(() => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ctrl.detectedCommune.value ?? '',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.darkBlue)),
                    const SizedBox(height: 2),
                    Text(ctrl.detectedRegion.value ?? '',
                        style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppTheme.greyMedium)),
                  ],
                )),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => ctrl.locateMe(),
              icon: const Icon(Icons.refresh_rounded, size: 16, color: AppTheme.primaryGreen),
              label: const Text('Actualiser',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.primaryGreen)),
            ),
            TextButton.icon(
              onPressed: () => ctrl.geocodeFailed.value = true,
              icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.greyMedium),
              label: const Text('Ce n\'est pas ça',
                  style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.greyMedium)),
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
            icon: const Icon(Icons.my_location_rounded, size: 16, color: AppTheme.primaryGreen),
            label: const Text('Réessayer la détection automatique',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.primaryGreen)),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
          ),
        ),
        const SizedBox(height: 16),

        const Text('Choisissez votre région',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkBlue)),
        const SizedBox(height: 10),
        Obx(() => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kSenegalRegions.map((r) {
            final selected = ctrl.selectedRegion.value == r;
            return GestureDetector(
              onTap: () => ctrl.selectedRegion.value = r,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.primaryGreen : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: selected ? AppTheme.primaryGreen : AppTheme.greyLight),
                ),
                child: Text(r,
                    style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppTheme.darkBlue)),
              ),
            );
          }).toList(),
        )),

        const SizedBox(height: 20),
        const Text('Quartier ou commune',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkBlue)),
        const SizedBox(height: 10),
        _SimpleField(
          controller: ctrl.communeCtrl,
          hint: 'Ex: Parcelles Assainies',
          icon: Icons.location_city_outlined,
        ),

        const SizedBox(height: 20),
        const Text('Repère (optionnel)',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.darkBlue)),
        const SizedBox(height: 10),
        _SimpleField(
          controller: ctrl.addressCtrl,
          hint: 'Ex: près du marché',
          icon: Icons.signpost_outlined,
        ),
      ],
    );
  }
}

class _SimpleField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final int maxLines;
  const _SimpleField({required this.controller, required this.hint, required this.icon, this.maxLines = 1});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontFamily: 'Poppins', fontSize: 15, color: AppTheme.darkBlue),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppTheme.greyMedium),
        prefixIcon: Icon(icon, size: 20, color: AppTheme.primaryGreen),
        filled: true, fillColor: AppTheme.background,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.greyLight)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.greyLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 1.5)),
      ),
    );
  }
}

class _BigErrorCard extends StatelessWidget {
  final VoidCallback onRetry;
  const _BigErrorCard({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 56, color: AppTheme.greyMedium),
          const SizedBox(height: 12),
          const Text('Impossible de charger', style: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppTheme.greyMedium)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}