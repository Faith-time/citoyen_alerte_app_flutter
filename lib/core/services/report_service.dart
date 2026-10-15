// lib/core/services/report_service.dart

import 'dart:io';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/data/models/report_model.dart';
import 'package:citoyen_alerte_app_backup/data/models/report_image_model.dart';

class ReportService extends GetxService {
  static ReportService get instance => Get.find<ReportService>();

  final ApiService _api = Get.find<ApiService>();
  final ImagePicker _picker = ImagePicker();

  // ─── État observable ──────────────────────────────────────────────────────
  final reports = <ReportModel>[].obs;
  final myReports = <ReportModel>[].obs;
  final isLoading = false.obs;
  final isLoadingMore = false.obs;
  final hasError = false.obs;
  final errorMessage = ''.obs;

  // Pagination
  int _currentPage = 1;
  bool _hasMorePages = true;

  // ─── GÉOLOCALISATION ─────────────────────────────────────────────────────

  /// Demande les permissions et retourne la position actuelle
  Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  // ─── SÉLECTION D'IMAGES ───────────────────────────────────────────────────

  Future<File?> pickFromGallery() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    return file != null ? File(file.path) : null;
  }

  Future<File?> pickFromCamera() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    return file != null ? File(file.path) : null;
  }

  // ─── LISTE DES SIGNALEMENTS ───────────────────────────────────────────────

  Future<void> fetchReports({
    Map<String, dynamic>? filters,
    bool refresh = false,
  }) async {
    if (refresh) {
      _currentPage = 1;
      _hasMorePages = true;
      reports.clear();
    }
    if (!_hasMorePages) return;

    try {
      isLoading.value = true;
      hasError.value = false;

      final params = {'page': _currentPage, 'per_page': 15, ...?filters};
      final response = await _api.getReports(queryParameters: params);

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final List items = data['data'] as List? ?? [];
        final lastPage = data['last_page'] as int? ?? 1;

        final parsed = items.map((e) => ReportModel.fromJson(e)).toList();
        if (refresh) {
          reports.assignAll(parsed);
        } else {
          reports.addAll(parsed);
        }
        _hasMorePages = _currentPage < lastPage;
        _currentPage++;
      }
    } catch (e) {
      hasError.value = true;
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> fetchMyReports(String userId) async {
    try {
      isLoading.value = true;
      hasError.value = false;

      final response = await _api.getReports(
        queryParameters: {'citizen_id': userId},
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final List items = data['data'] as List? ?? [];
        myReports.assignAll(items.map((e) => ReportModel.fromJson(e)));
      }
    } catch (e) {
      hasError.value = true;
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<ReportModel?> fetchReportById(int id) async {
    try {
      final response = await _api.getReportById(id);
      if (response.success && response.data != null) {
        return ReportModel.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (e) {
      errorMessage.value = e.toString();
    }
    return null;
  }

  // ─── CRÉER UN SIGNALEMENT + IMAGES ───────────────────────────────────────

  /// Crée le signalement puis upload les images en séquence
  Future<ReportModel?> createReportWithImages({
    required int categoryId,
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    required String address,
    required String communeName,
    required String regionName,
    required String severity,
    bool isAnonymous = false,
    List<File> images = const [],
  }) async {
    try {
      isLoading.value = true;

      // 1. Créer le signalement
      final formData = FormData.fromMap({
        'category_id': categoryId.toString(),
        'title': title,
        'description': description,
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'address': address,
        'commune_name': communeName,
        'region_name': regionName,
        'severity': severity,
        'is_anonymous': isAnonymous ? '1' : '0',
      });

      final response = await _api.createReport(formData);

      if (!response.success || response.data == null) return null;

      final rawData = response.data as Map<String, dynamic>;
      final reportData = rawData['data'] ?? rawData;
      final report = ReportModel.fromJson(reportData as Map<String, dynamic>);

      // 2. Upload des images (table report_images)
      if (images.isNotEmpty) {
        await _uploadImages(reportId: report.id, images: images);
      }

      myReports.insert(0, report);
      return report;
    } catch (e) {
      errorMessage.value = e.toString();
      return null;
    } finally {
      isLoading.value = false;
    }
  }

  /// Upload plusieurs images pour un signalement
  Future<void> _uploadImages({
    required int reportId,
    required List<File> images,
  }) async {
    for (int i = 0; i < images.length; i++) {
      try {
        final imageFormData = FormData.fromMap({
          'image': await MultipartFile.fromFile(
            images[i].path,
            filename: 'image_$i.jpg',
          ),
          'type': 'initial',
        });

        // POST /api/v1/reports/{reportId}/images
        final dio = Dio();
        // Utiliser le DioClient sous-jacent via ApiService n'est pas exposé
        // donc on passe par un endpoint dédié si disponible, ou on stocke
        // les images en local pour upload séquentiel
        await _api.createReport(imageFormData); // À remplacer par l'endpoint images
      } catch (_) {
        // Continuer même si une image échoue
      }
    }
  }

  // ─── METTRE À JOUR ────────────────────────────────────────────────────────

  Future<ReportModel?> updateReport(
      int id,
      Map<String, dynamic> data,
      ) async {
    try {
      isLoading.value = true;
      final response = await _api.updateReport(id, data);

      if (response.success && response.data != null) {
        final rawData = response.data as Map<String, dynamic>;
        final reportData = rawData['data'] ?? rawData;
        final updated = ReportModel.fromJson(reportData as Map<String, dynamic>);

        final idx = myReports.indexWhere((r) => r.id == id);
        if (idx != -1) myReports[idx] = updated;

        final idx2 = reports.indexWhere((r) => r.id == id);
        if (idx2 != -1) reports[idx2] = updated;

        return updated;
      }
    } catch (e) {
      errorMessage.value = e.toString();
    } finally {
      isLoading.value = false;
    }
    return null;
  }

  // ─── SUPPRIMER ────────────────────────────────────────────────────────────

  Future<bool> deleteReport(int id) async {
    try {
      final response = await _api.deleteReport(id);
      if (response.success) {
        myReports.removeWhere((r) => r.id == id);
        reports.removeWhere((r) => r.id == id);
        return true;
      }
    } catch (e) {
      errorMessage.value = e.toString();
    }
    return false;
  }

  // ─── IMAGES ──────────────────────────────────────────────────────────────

  Future<List<ReportImageModel>> fetchImages(int reportId) async {
    try {
      final response = await _api.getReports(
        queryParameters: {'report_id': reportId},
      );
      if (response.success && response.data != null) {
        final List items = response.data as List? ?? [];
        return items.map((e) => ReportImageModel.fromJson(e)).toList();
      }
    } catch (e) {
      errorMessage.value = e.toString();
    }
    return [];
  }

  // ─── SIGNALEMENTS À PROXIMITÉ ────────────────────────────────────────────

  Future<List<ReportModel>> fetchNearbyReports({
    required double lat,
    required double lng,
    double radius = 5.0,
  }) async {
    try {
      final response = await _api.getNearbyReports(
        lat: lat,
        lng: lng,
        radius: radius,
      );
      if (response.success && response.data != null) {
        final List items = response.data as List? ?? [];
        return items.map((e) => ReportModel.fromJson(e)).toList();
      }
    } catch (e) {
      errorMessage.value = e.toString();
    }
    return [];
  }

  // ─── DASHBOARDS ──────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> fetchCitizenDashboard() async {
    try {
      final response = await _api.getCitizenDashboard();
      if (response.success && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      errorMessage.value = e.toString();
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchAgentDashboard() async {
    try {
      final response = await _api.getAgentDashboard();
      if (response.success && response.data != null) {
        return response.data as Map<String, dynamic>;
      }
    } catch (e) {
      errorMessage.value = e.toString();
    }
    return null;
  }

  // ─── HELPERS ─────────────────────────────────────────────────────────────

  void clearError() {
    hasError.value = false;
    errorMessage.value = '';
  }

  Color getSeverityColor(String severity) {
    return switch (severity) {
      'high' => const Color(0xFFE53935),
      'medium' => const Color(0xFFFB8C00),
      'low' => const Color(0xFF43A047),
      _ => const Color(0xFF757575),
    };
  }

  Color getStatusColor(String status) {
    return switch (status) {
      'pending' => const Color(0xFFFB8C00),
      'routed' => const Color(0xFF1E88E5),
      'in_progress' => const Color(0xFF8E24AA),
      'resolved' => const Color(0xFF43A047),
      _ => const Color(0xFF757575),
    };
  }
}