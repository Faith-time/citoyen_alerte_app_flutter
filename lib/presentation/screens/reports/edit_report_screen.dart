// lib/presentation/screens/reports/edit_report_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/data/models/report_model.dart';
import 'package:citoyen_alerte_app_backup/data/models/category_model.dart';

// ─── CONTROLLER ──────────────────────────────────────────────────────────────

class EditReportController extends GetxController {
  final ApiService _api = Get.find<ApiService>();
  final ImagePicker _picker = ImagePicker();
  final ReportModel report;

  EditReportController({required this.report});

  // Catégories
  final isLoadingCategories = true.obs;
  final categories = <CategoryModel>[].obs;
  final selectedParentCategoryId = Rx<int?>(null);
  final selectedCategoryId = Rx<int?>(null);

  // Formulaire
  final selectedSeverity = 'medium'.obs;
  final isAnonymous = false.obs;
  final isLoading = false.obs;
  final isLocating = false.obs;

  // Images (max 3) — nouvelles images à uploader
  final images = <File>[].obs;
  static const int maxImages = 3;

  late final TextEditingController titleCtrl;
  late final TextEditingController descriptionCtrl;
  late final TextEditingController addressCtrl;
  late final TextEditingController communeCtrl;
  late final TextEditingController regionCtrl;
  late final TextEditingController latCtrl;
  late final TextEditingController lngCtrl;
  final formKey = GlobalKey<FormState>();

  @override
  void onInit() {
    super.onInit();
    // Pré-remplir avec les données existantes
    titleCtrl       = TextEditingController(text: report.title);
    descriptionCtrl = TextEditingController(text: report.description);
    addressCtrl     = TextEditingController(text: report.address);
    communeCtrl     = TextEditingController(text: report.communeName);
    regionCtrl      = TextEditingController(text: report.regionName);
    latCtrl         = TextEditingController(text: report.latitude.toString());
    lngCtrl         = TextEditingController(text: report.longitude.toString());
    selectedSeverity.value = report.severity;
    isAnonymous.value      = report.isAnonymous;

    _loadCategories();
  }

  @override
  void onClose() {
    titleCtrl.dispose();
    descriptionCtrl.dispose();
    addressCtrl.dispose();
    communeCtrl.dispose();
    regionCtrl.dispose();
    latCtrl.dispose();
    lngCtrl.dispose();
    super.onClose();
  }

  // ── Catégories ─────────────────────────────────────────────────────────

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

        if (items.isNotEmpty) {
          categories.assignAll(
            items.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)),
          );
          _restoreSelection();
        }
      }
    } catch (e) {
      debugPrint('❌ Catégories: $e');
    } finally {
      isLoadingCategories.value = false;
    }
  }

  void _restoreSelection() {
    final current = categories.firstWhereOrNull((c) => c.id == report.categoryId);
    if (current == null) return;

    if (current.parentId == null) {
      selectedParentCategoryId.value = current.id;
      selectedCategoryId.value = null;
    } else {
      selectedParentCategoryId.value = current.parentId;
      selectedCategoryId.value = current.id;
    }
  }

  List<CategoryModel> get parentCategories =>
      categories.where((c) => c.parentId == null).toList();

  List<CategoryModel> get subCategories =>
      selectedParentCategoryId.value == null
          ? []
          : categories
          .where((c) => c.parentId == selectedParentCategoryId.value)
          .toList();

  bool get showSubCategories => subCategories.isNotEmpty;

  void selectParent(int id) {
    selectedParentCategoryId.value = id;
    selectedCategoryId.value = null;
  }

  int? get effectiveCategoryId =>
      selectedCategoryId.value ?? selectedParentCategoryId.value;

  // ── Géolocalisation ────────────────────────────────────────────────────

  Future<void> locateMe({bool silent = false}) async {
    try {
      isLocating.value = true;

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!silent) {
          Get.snackbar(
            'GPS désactivé',
            'Activez la localisation sur votre téléphone',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppTheme.warning,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) {
        if (!silent) {
          Get.snackbar(
            'Permission refusée',
            'Autorisez la localisation dans les paramètres',
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: AppTheme.error,
            colorText: Colors.white,
            margin: const EdgeInsets.all(16),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      latCtrl.text = position.latitude.toStringAsFixed(6);
      lngCtrl.text = position.longitude.toStringAsFixed(6);

      if (!silent) {
        Get.snackbar(
          'Position mise à jour ✓',
          'Latitude: ${latCtrl.text}',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.success,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        );
      }
    } catch (e) {
      if (!silent) {
        Get.snackbar(
          'Erreur GPS',
          'Impossible d\'obtenir la position',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.error,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
      }
    } finally {
      isLocating.value = false;
    }
  }

  // ── Images ─────────────────────────────────────────────────────────────

  Future<void> pickImage(ImageSource source) async {
    if (images.length >= maxImages) {
      Get.snackbar(
        'Maximum atteint',
        'Vous ne pouvez ajouter que $maxImages photos',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.warning,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file != null) {
        images.add(File(file.path));
      }
    } catch (_) {}
  }

  void removeImage(int index) {
    if (index >= 0 && index < images.length) {
      images.removeAt(index);
    }
  }

  void showImagePicker() {
    Get.bottomSheet(
      Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.greyLight,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Ajouter une photo',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.camera_alt_outlined,
                    color: AppTheme.primaryGreen),
              ),
              title: const Text('Prendre une photo'),
              onTap: () {
                Get.back();
                pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                const Icon(Icons.photo_library_outlined, color: Colors.blue),
              ),
              title: const Text('Choisir depuis la galerie'),
              onTap: () {
                Get.back();
                pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── Sauvegarde ─────────────────────────────────────────────────────────

  Future<void> saveChanges() async {
    if (!formKey.currentState!.validate()) return;

    if (effectiveCategoryId == null) {
      Get.snackbar(
        'Catégorie requise',
        'Veuillez sélectionner une catégorie',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.error,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    if (showSubCategories && selectedCategoryId.value == null) {
      Get.snackbar(
        'Sous-catégorie requise',
        'Veuillez sélectionner une sous-catégorie',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.error,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
      return;
    }

    try {
      isLoading.value = true;

      // 1. Mettre à jour le signalement
      final data = <String, dynamic>{
        'category_id': effectiveCategoryId,
        'title': titleCtrl.text.trim(),
        'description': descriptionCtrl.text.trim(),
        'latitude':
        double.tryParse(latCtrl.text.trim()) ?? report.latitude,
        'longitude':
        double.tryParse(lngCtrl.text.trim()) ?? report.longitude,
        'address': addressCtrl.text.trim(),
        'commune_name': communeCtrl.text.trim(),
        'region_name': regionCtrl.text.trim(),
        'severity': selectedSeverity.value,
        'is_anonymous': isAnonymous.value,
      };

      debugPrint('📤 updateReport data: $data');
      final response = await _api.updateReport(report.id, data);

      debugPrint('📦 response.success: ${response.success}');
      debugPrint('📦 response.data: ${response.data}');

      if (!response.success) {
        Get.snackbar(
          'Erreur',
          response.message ?? 'Une erreur est survenue',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppTheme.error,
          colorText: Colors.white,
          margin: const EdgeInsets.all(16),
        );
        return;
      }

      // 2. Upload nouvelles images si présentes
      if (images.isNotEmpty) {
        debugPrint('✅ Lancement upload images pour report ${report.id}');
        await _uploadImages(reportId: report.id);
      } else {
        debugPrint('⚠️ Aucune nouvelle image → upload ignoré');
      }

      Get.back(result: true);
      Get.snackbar(
        'Modifié ✓',
        'Signalement mis à jour avec succès',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.success,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    } catch (e, stack) {
      debugPrint('❌ Erreur saveChanges: $e');
      debugPrint('📛 Stack: $stack');
      Get.snackbar(
        'Erreur',
        'Impossible de modifier le signalement',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppTheme.error,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _uploadImages({required int reportId}) async {
    debugPrint('🖼️ Upload de ${images.length} image(s) pour report $reportId');

    for (int i = 0; i < images.length; i++) {
      try {
        final imageFormData = FormData.fromMap({
          'image': await MultipartFile.fromFile(
            images[i].path,
            filename: 'photo_${reportId}_$i.jpg',
          ),
          'type': 'initial',
        });

        debugPrint('🌐 Envoi image $i vers /reports/$reportId/images');
        final result = await _api.uploadReportImage(reportId, imageFormData);
        debugPrint('✅ Image $i: ${result.success} — ${result.message}');
      } catch (e) {
        debugPrint('❌ Image $i échouée: $e');
      }
    }
  }
}

// ─── SCREEN ──────────────────────────────────────────────────────────────────

class EditReportScreen extends StatelessWidget {
  final ReportModel report;
  const EditReportScreen({super.key, required this.report});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(EditReportController(report: report));

    return Scaffold(
      backgroundColor: AppTheme.greyLight.withValues(alpha: 0.3),
      appBar: AppBar(
        title: const Text('Modifier le signalement'),
        backgroundColor: AppTheme.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12, top: 15, bottom: 15),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                report.reference,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: ctrl.formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Bandeau info ───────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border:
                  Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.blue, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Vous pouvez modifier ce signalement car il est encore en attente de traitement.',
                        style: TextStyle(
                            color: Colors.blue.shade700,
                            fontSize: 12,
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Catégorie ──────────────────────────────────────────────
              const _SectionTitle(
                  icon: Icons.category_outlined, title: 'Catégorie *'),
              const SizedBox(height: 12),
              Obx(() {
                if (ctrl.isLoadingCategories.value) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryGreen),
                    ),
                  );
                }
                if (ctrl.parentCategories.isEmpty) {
                  return _EmptyCategories(onRetry: ctrl._loadCategories);
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ctrl.parentCategories.map((cat) {
                    return Obx(() {
                      final selected =
                          ctrl.selectedParentCategoryId.value == cat.id;
                      return _CategoryChip(
                        label: cat.name,
                        selected: selected,
                        onTap: () => ctrl.selectParent(cat.id),
                      );
                    });
                  }).toList(),
                );
              }),

              // ── Sous-catégorie ─────────────────────────────────────────
              Obx(() {
                if (!ctrl.showSubCategories) return const SizedBox.shrink();
                return AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      const _SectionTitle(
                          icon: Icons.subdirectory_arrow_right,
                          title: 'Sous-catégorie *'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ctrl.subCategories.map((sub) {
                          return Obx(() {
                            final selected =
                                ctrl.selectedCategoryId.value == sub.id;
                            return _CategoryChip(
                              label: sub.name,
                              selected: selected,
                              isSubCategory: true,
                              onTap: () =>
                              ctrl.selectedCategoryId.value = sub.id,
                            );
                          });
                        }).toList(),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 24),

              // ── Informations ───────────────────────────────────────────
              const _SectionTitle(
                  icon: Icons.info_outline, title: 'Informations'),
              const SizedBox(height: 12),
              _FormCard(
                child: Column(
                  children: [
                    _CRField(
                      controller: ctrl.titleCtrl,
                      label: 'Titre *',
                      hint: 'Ex: Nid de poule dangereux rue principale',
                      icon: Icons.title,
                      validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Titre requis' : null,
                    ),
                    const SizedBox(height: 16),
                    _CRField(
                      controller: ctrl.descriptionCtrl,
                      label: 'Description *',
                      hint: 'Décrivez le problème en détail...',
                      icon: Icons.description_outlined,
                      maxLines: 4,
                      validator: (v) => v == null || v.trim().length < 10
                          ? 'Minimum 10 caractères'
                          : null,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Photos ─────────────────────────────────────────────────
              Row(
                children: [
                  const _SectionTitle(
                      icon: Icons.photo_camera_outlined,
                      title: 'Nouvelles photos'),
                  const SizedBox(width: 8),
                  Obx(() => Text(
                    '(${ctrl.images.length}/${EditReportController.maxImages})',
                    style: TextStyle(fontSize: 13, color: AppTheme.grey),
                  )),
                ],
              ),
              const SizedBox(height: 12),
              Obx(() => _PhotoSection(
                images: ctrl.images.toList(), // ✅ snapshot List<File> ordinaire
                maxImages: EditReportController.maxImages,
                onAdd: ctrl.showImagePicker,
                onRemove: ctrl.removeImage,
              )),

              const SizedBox(height: 20),

              // ── Sévérité ───────────────────────────────────────────────
              const _SectionTitle(
                  icon: Icons.warning_amber_outlined,
                  title: 'Niveau de sévérité'),
              const SizedBox(height: 12),
              Obx(() => Row(
                children: [
                  Expanded(
                    child: _SevBtn(
                      label: 'Faible',
                      color: AppTheme.success,
                      isSelected:
                      ctrl.selectedSeverity.value == 'low',
                      onTap: () => ctrl.selectedSeverity.value = 'low',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SevBtn(
                      label: 'Moyen',
                      color: AppTheme.warning,
                      isSelected:
                      ctrl.selectedSeverity.value == 'medium',
                      onTap: () =>
                      ctrl.selectedSeverity.value = 'medium',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SevBtn(
                      label: 'Élevé',
                      color: AppTheme.error,
                      isSelected:
                      ctrl.selectedSeverity.value == 'high',
                      onTap: () => ctrl.selectedSeverity.value = 'high',
                    ),
                  ),
                ],
              )),

              const SizedBox(height: 20),

              // ── Localisation ───────────────────────────────────────────
              const _SectionTitle(
                  icon: Icons.location_on_outlined, title: 'Localisation'),
              const SizedBox(height: 12),
              _FormCard(
                child: Column(
                  children: [
                    _CRField(
                      controller: ctrl.addressCtrl,
                      label: 'Adresse *',
                      hint: 'Rue, quartier, point de repère...',
                      icon: Icons.location_on_outlined,
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Adresse requise'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _CRField(
                            controller: ctrl.communeCtrl,
                            label: 'Commune *',
                            hint: 'Ex: Dakar',
                            icon: Icons.location_city_outlined,
                            validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Requis' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CRField(
                            controller: ctrl.regionCtrl,
                            label: 'Région *',
                            hint: 'Ex: Dakar',
                            icon: Icons.map_outlined,
                            validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Requis' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _CRField(
                            controller: ctrl.latCtrl,
                            label: 'Latitude',
                            hint: '14.7167',
                            icon: Icons.gps_fixed,
                            keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _CRField(
                            controller: ctrl.lngCtrl,
                            label: 'Longitude',
                            hint: '-17.4677',
                            icon: Icons.gps_not_fixed,
                            keyboardType:
                            const TextInputType.numberWithOptions(
                                decimal: true, signed: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Bouton GPS
                    Obx(() => SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: ctrl.isLocating.value
                            ? null
                            : ctrl.locateMe,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                              color: AppTheme.primaryGreen),
                          padding:
                          const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: ctrl.isLocating.value
                            ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.primaryGreen))
                            : const Icon(Icons.my_location,
                            color: AppTheme.primaryGreen, size: 18),
                        label: Text(
                          ctrl.isLocating.value
                              ? 'Localisation en cours...'
                              : 'Mettre à jour ma position',
                          style: const TextStyle(
                              color: AppTheme.primaryGreen,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ),
                    )),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ── Anonymat ───────────────────────────────────────────────
              _FormCard(
                child: Obx(() => SwitchListTile(
                  value: ctrl.isAnonymous.value,
                  onChanged: (v) => ctrl.isAnonymous.value = v,
                  activeThumbColor: AppTheme.primaryGreen,
                  title: const Text('Signalement anonyme',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text('Votre identité ne sera pas visible',
                      style:
                      TextStyle(fontSize: 12, color: AppTheme.grey)),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color:
                      AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.privacy_tip_outlined,
                        color: AppTheme.primaryGreen, size: 20),
                  ),
                )),
              ),

              const SizedBox(height: 32),

              // ── Boutons Annuler / Enregistrer ──────────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Get.back(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppTheme.greyLight),
                        padding:
                        const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        'Annuler',
                        style: TextStyle(
                            color: AppTheme.grey,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Obx(() => SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: ctrl.isLoading.value
                            ? null
                            : ctrl.saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          disabledBackgroundColor:
                          AppTheme.primaryGreen.withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        child: ctrl.isLoading.value
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        )
                            : const Row(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Enregistrer',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    )),
                  ),
                ],
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── WIDGETS — identiques à create_report_screen.dart ────────────────────────

class _PhotoSection extends StatelessWidget {
  final List<File> images;
  final int maxImages;
  final VoidCallback onAdd;
  final void Function(int) onRemove;

  const _PhotoSection({
    required this.images,
    required this.maxImages,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Miniatures des images sélectionnées
          ...images.asMap().entries.map((entry) {
            return Container(
              width: 100,
              height: 100,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.greyLight),
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(entry.value,
                        width: 100, height: 100, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => onRemove(entry.key),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Colors.red, shape: BoxShape.circle),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Bouton d'ajout
          if (images.length < maxImages)
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.4),
                      style: BorderStyle.solid),
                  color: AppTheme.primaryGreen.withValues(alpha: 0.05),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_a_photo_outlined,
                        color: AppTheme.primaryGreen, size: 28),
                    const SizedBox(height: 4),
                    Text(
                      'Ajouter',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primaryGreen.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyCategories({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_outlined,
              color: AppTheme.error, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text('Impossible de charger les catégories',
                style: TextStyle(fontSize: 13, color: AppTheme.error)),
          ),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isSubCategory;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    this.isSubCategory = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(
            horizontal: isSubCategory ? 14 : 16,
            vertical: isSubCategory ? 8 : 9),
        decoration: BoxDecoration(
          color: selected
              ? (isSubCategory
              ? AppTheme.primaryGreen.withValues(alpha: 0.15)
              : AppTheme.primaryGreen)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primaryGreen : AppTheme.greyLight,
            width: selected && isSubCategory ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isSubCategory ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? (isSubCategory ? AppTheme.primaryGreen : Colors.white)
                : AppTheme.grey,
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.primaryGreen),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.black)),
      ],
    );
  }
}

class _FormCard extends StatelessWidget {
  final Widget child;
  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: child,
    );
  }
}

class _CRField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _CRField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppTheme.grey),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.greyLight)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppTheme.greyLight)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
            const BorderSide(color: AppTheme.primaryGreen, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppTheme.error)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
            const BorderSide(color: AppTheme.error, width: 2)),
        filled: true,
        fillColor: AppTheme.greyLight.withValues(alpha: 0.3),
        labelStyle: TextStyle(color: AppTheme.grey, fontSize: 13),
        hintStyle: TextStyle(
            color: AppTheme.grey.withValues(alpha: 0.6), fontSize: 13),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}

class _SevBtn extends StatelessWidget {
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _SevBtn({
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? color : AppTheme.greyLight),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.warning_amber,
                color: isSelected ? Colors.white : color, size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : color)),
          ],
        ),
      ),
    );
  }
}