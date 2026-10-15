// lib/core/services/category_service.dart

import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/data/models/category_model.dart';

class CategoryService extends GetxService {
  static CategoryService get instance => Get.find<CategoryService>();

  final ApiService _api = Get.find<ApiService>();

  final categories = <CategoryModel>[].obs;
  final isLoading = false.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;

  // ── Chargement ────────────────────────────────────────────────────────────

  Future<void> fetchCategories({bool forceRefresh = false}) async {
    if (categories.isNotEmpty && !forceRefresh) return;

    try {
      isLoading.value = true;
      hasError.value = false;

      final response = await _api.getCategories();

      if (response.data != null) {
        final raw = response.data;
        List items = [];

        if (raw is Map) {
          items = (raw['data'] as List?) ?? [];
        } else if (raw is List) {
          items = raw;
        }

        categories.assignAll(
          items.map((e) => CategoryModel.fromJson(e as Map<String, dynamic>)),
        );
      }
    } catch (e) {
      hasError.value = true;
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  // ── Accesseurs ────────────────────────────────────────────────────────────

  /// Catégories racines (sans parent)
  List<CategoryModel> get parentCategories =>
      categories.where((c) => c.parentId == null).toList();

  /// Sous-catégories d'un parent
  List<CategoryModel> subCategoriesOf(int parentId) =>
      categories.where((c) => c.parentId == parentId).toList();

  /// Trouver par ID
  CategoryModel? findById(int id) =>
      categories.firstWhereOrNull((c) => c.id == id);

  /// Nom complet : "Parent > Enfant"
  String fullNameOf(int id) {
    final cat = findById(id);
    if (cat == null) return '';
    if (cat.parentId != null) {
      final parent = findById(cat.parentId!);
      if (parent != null) return '${parent.name} > ${cat.name}';
    }
    return cat.name;
  }

  void clear() => categories.clear();
}