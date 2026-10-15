import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:get/get.dart';

class ImageUploadService {
  static final ImageUploadService _instance = ImageUploadService._internal();
  factory ImageUploadService() => _instance;
  ImageUploadService._internal();

  final ImagePicker _picker = ImagePicker();

  /// Sélectionner une image depuis la galerie
  Future<File?> pickImageFromGallery() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('❌ Erreur sélection image: $e');
      rethrow;
    }
  }

  /// Prendre une photo avec la caméra
  Future<File?> pickImageFromCamera() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        return File(image.path);
      }
      return null;
    } catch (e) {
      print('❌ Erreur capture photo: $e');
      rethrow;
    }
  }

  /// Uploader l'avatar vers le serveur
  Future<String?> uploadAvatar(File imageFile) async {
    try {
      final apiService = Get.find<ApiService>();

      final response = await apiService.uploadFile(
        path: '/api/v1/upload/avatar',
        filePath: imageFile.path,
        fieldName: 'avatar',
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return data['avatar_url'] as String?;
      }

      return null;
    } catch (e) {
      print('❌ Erreur upload avatar: $e');
      rethrow;
    }
  }

  /// Afficher une boîte de dialogue pour choisir la source
  Future<File?> showImageSourceDialog() async {
    return await Get.dialog<File?>(
      AlertDialog(
        title: const Text('Choisir une photo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () async {
                Get.back();
                final image = await pickImageFromGallery();
                Get.back(result: image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Caméra'),
              onTap: () async {
                Get.back();
                final image = await pickImageFromCamera();
                Get.back(result: image);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }
}