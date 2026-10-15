// lib/core/services/location_service.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:geolocator/geolocator.dart';

class LocationService extends GetxService {
  static LocationService get instance => Get.find<LocationService>();

  final currentPosition = Rx<Position?>(null);
  final isLocating = false.obs;
  final hasPermission = false.obs;
  final locationError = ''.obs;

  // ── Initialisation ────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final permission = await Geolocator.checkPermission();
    hasPermission.value = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // ── Demande de permission ─────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      locationError.value = 'Le service de localisation est désactivé';
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        locationError.value = 'Permission de localisation refusée';
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      locationError.value =
      'Permission définitivement refusée. Modifiez-la dans les paramètres.';
      return false;
    }

    hasPermission.value = true;
    locationError.value = '';
    return true;
  }

  // ── Obtenir la position ───────────────────────────────────────────────────

  Future<Position?> getCurrentPosition({bool silent = false}) async {
    try {
      if (!silent) isLocating.value = true;
      locationError.value = '';

      final granted = await requestPermission();
      if (!granted) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      currentPosition.value = position;
      return position;
    } catch (e) {
      locationError.value = 'Impossible d\'obtenir la position: ${e.toString()}';
      return null;
    } finally {
      if (!silent) isLocating.value = false;
    }
  }

  /// Obtenir la position avec un snackbar de feedback
  Future<Position?> locateWithFeedback({
    String successMessage = 'Position obtenue ✓',
  }) async {
    final position = await getCurrentPosition();

    if (position != null) {
      Get.snackbar(
        successMessage,
        '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      );
    } else if (locationError.isNotEmpty) {
      Get.snackbar(
        'Localisation impossible',
        locationError.value,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        margin: const EdgeInsets.all(16),
      );
    }

    return position;
  }

  // ── Distance ──────────────────────────────────────────────────────────────

  /// Distance en km entre deux points
  static double distanceBetween(
      double lat1, double lng1,
      double lat2, double lng2,
      ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2) / 1000;
  }

  /// Distance entre la position actuelle et un point
  double? distanceTo(double lat, double lng) {
    final pos = currentPosition.value;
    if (pos == null) return null;
    return distanceBetween(pos.latitude, pos.longitude, lat, lng);
  }

  String? distanceLabel(double lat, double lng) {
    final d = distanceTo(lat, lng);
    if (d == null) return null;
    if (d < 1) return '${(d * 1000).round()} m';
    return '${d.toStringAsFixed(1)} km';
  }
}