// ══════════════════════════════════════════════════════════════════════════
// NOUVEAU FICHIER — feuille modale "Photo de résolution"
//
// À placer par exemple dans :
//   lib/presentation/widgets/resolution_photo_sheet.dart
//
// Rôle : quand l'agent termine une intervention (glisse une carte vers la
// colonne "Terminé" dans le Kanban), cette feuille s'ouvre et l'oblige à
// prendre une photo "après" avant de confirmer. La photo est uploadée en
// type 'after' via ApiService.uploadReportImage — exactement le même
// endpoint (POST /reports/{report}/images) et le même pattern Dio FormData
// que CreateReportScreen utilise déjà pour la photo 'initial' du citoyen.
// C'est cette photo 'after' qui s'affichera dans l'onglet Actualités du
// citoyen, à côté de sa photo 'initial' (ou 'before' si elle existe).
// ══════════════════════════════════════════════════════════════════════════

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:citoyen_alerte_app_backup/core/theme/app_theme.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';

/// Ouvre la feuille et retourne `true` si la photo a bien été prise ET
/// uploadée avec succès, `false` si l'agent a annulé ou si l'upload a
/// échoué. Appelle-la avant de marquer une intervention comme terminée.
Future<bool> showResolutionPhotoSheet({required int reportId}) async {
  final result = await Get.bottomSheet<bool>(
    _ResolutionPhotoSheet(reportId: reportId),
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
  );
  return result ?? false;
}

class _ResolutionPhotoSheet extends StatefulWidget {
  final int reportId;
  const _ResolutionPhotoSheet({required this.reportId});

  @override
  State<_ResolutionPhotoSheet> createState() => _ResolutionPhotoSheetState();
}

class _ResolutionPhotoSheetState extends State<_ResolutionPhotoSheet> {
  final ImagePicker _picker = ImagePicker();
  File? _photo;
  bool _isUploading = false;

  Future<void> _takePhoto() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file != null) setState(() => _photo = File(file.path));
    } catch (_) {}
  }

  Future<void> _confirm() async {
    if (_photo == null) return;
    setState(() => _isUploading = true);

    try {
      final fd = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          _photo!.path,
          filename: 'resolution_${widget.reportId}.jpg',
        ),
        'type': 'after',
      });

      final response = await Get.find<ApiService>()
          .uploadReportImage(widget.reportId, fd);

      if (response.success) {
        Get.back(result: true);
        return;
      }
      _showError();
    } catch (_) {
      _showError();
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError() {
    Get.snackbar(
      'Erreur',
      "Impossible d'envoyer la photo. Réessayez.",
      backgroundColor: AppTheme.error,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radiusXl),
          boxShadow: AppTheme.elevatedShadow(Colors.black),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppTheme.greyLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.camera_alt_rounded,
                      color: AppTheme.success, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Photo de résolution', style: AppTheme.h2),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Prenez une photo du résultat pour confirmer que le problème '
                  'est résolu. Elle sera visible par le citoyen dans "Actualités".',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 12.5,
                color: AppTheme.greyMedium,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            // Aperçu / zone de capture
            GestureDetector(
              onTap: _isUploading ? null : _takePhoto,
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(
                    color: _photo != null
                        ? AppTheme.success.withOpacity(0.4)
                        : AppTheme.greyLight,
                    width: 1.5,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: _photo != null
                    ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(_photo!, fit: BoxFit.cover),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black.withOpacity(0.55),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _isUploading ? null : _takePhoto,
                          child: const Padding(
                            padding: EdgeInsets.all(7),
                            child: Icon(Icons.replay_rounded,
                                color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
                    : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt_outlined,
                          size: 30, color: AppTheme.primaryGreen),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Appuyez pour prendre une photo',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.darkBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isUploading ? null : () => Get.back(result: false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppTheme.greyLight),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    child: const Text('Annuler',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppTheme.greyMedium,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: (_photo == null || _isUploading) ? null : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    child: _isUploading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                        : const Text('Confirmer la résolution',
                        style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}