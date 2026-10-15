// lib/core/services/intervention_service.dart

import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/data/models/intervention_model.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';

class InterventionService extends GetxService {
  static InterventionService get instance => Get.find<InterventionService>();

  final ApiService _api = Get.find<ApiService>();

  // ── Helper — extrait une List depuis une réponse API qui peut renvoyer
  //    soit une List directement, soit un Map { "data": [...] }
  List<dynamic> _extractList(dynamic data) {
    if (data == null) return [];
    if (data is List) return data;
    if (data is Map) {
      final inner = data['data'];
      if (inner is List) return inner;
    }
    return [];
  }

  // ── Helper — extrait un Map depuis une réponse API qui peut renvoyer
  //    soit un Map directement, soit un Map { "data": {...} }
  Map<String, dynamic>? _extractMap(dynamic data) {
    if (data == null) return null;
    if (data is Map<String, dynamic>) {
      if (data.containsKey('data') && data['data'] is Map) {
        return data['data'] as Map<String, dynamic>;
      }
      return data;
    }
    return null;
  }

  // ── READ ──────────────────────────────────────────────────────────────────

  /// Liste toutes les interventions (filtres optionnels)
  Future<List<InterventionModel>> getAll({
    int? agentId,
    int? reportId,
    InterventionStatus? status,
    int page = 1,
  }) async {
    final response = await _api.getInterventions(
      queryParameters: {
        'page': page,
        if (agentId != null)  'agent_id':  agentId,
        if (reportId != null) 'report_id': reportId,
        if (status != null)   'status':    status.value,
      },
    );

    if (response.success && response.data != null) {
      return _extractList(response.data)
          .map((e) => InterventionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Détail d'une intervention
  Future<InterventionModel?> getById(int id) async {
    final response = await _api.getInterventionById(id);
    if (response.success && response.data != null) {
      final map = _extractMap(response.data);
      if (map != null) return InterventionModel.fromJson(map);
    }
    return null;
  }

  /// Interventions de l'agent connecté
  Future<List<InterventionModel>> getMine() async {
    final response = await _api.getMyInterventions();
    if (response.success && response.data != null) {
      return _extractList(response.data)
          .map((e) => InterventionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  // ── WRITE ─────────────────────────────────────────────────────────────────

  /// Créer une nouvelle intervention
  Future<InterventionModel?> create({
    required int reportId,
    int? authorityId,
    String? notes,
  }) async {
    final response = await _api.createIntervention({
      'report_id': reportId,
      if (authorityId != null) 'authority_id': authorityId,
      if (notes != null)       'notes':         notes,
    });

    if (response.success && response.data != null) {
      final map = _extractMap(response.data);
      if (map != null) return InterventionModel.fromJson(map);
    }
    return null;
  }

  /// Mettre à jour le statut d'une intervention
  Future<InterventionModel?> updateStatus(
      int id,
      InterventionStatus newStatus, {
        String? notes,
      }) async {
    final response = await _api.updateInterventionStatus(id, {
      'status': newStatus.value,
      if (notes != null) 'notes': notes,
    });

    if (response.success && response.data != null) {
      final map = _extractMap(response.data);
      if (map != null) return InterventionModel.fromJson(map);
    }
    return null;
  }

  /// Démarrer une intervention (pending → in_progress)
  Future<InterventionModel?> start(int id) =>
      updateStatus(id, InterventionStatus.inProgress);

  /// Terminer une intervention (in_progress → completed)
  Future<InterventionModel?> complete(int id, {String? notes}) async {
    final response = await _api.completeIntervention(id);
    if (response.success && response.data != null) {
      final map = _extractMap(response.data);
      if (map != null) return InterventionModel.fromJson(map);
    }
    return null;
  }

  /// Annuler une intervention
  Future<InterventionModel?> cancel(int id, {String? notes}) =>
      updateStatus(id, InterventionStatus.cancelled, notes: notes);

  /// Mise à jour complète
  Future<InterventionModel?> update(
      int id, {
        InterventionStatus? status,
        String? notes,
        DateTime? startedAt,
        DateTime? completedAt,
      }) async {
    final response = await _api.updateIntervention(id, {
      if (status != null)      'status':       status.value,
      if (notes != null)       'notes':        notes,
      if (startedAt != null)   'started_at':   startedAt.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt.toIso8601String(),
    });

    if (response.success && response.data != null) {
      final map = _extractMap(response.data);
      if (map != null) return InterventionModel.fromJson(map);
    }
    return null;
  }

  /// Supprimer une intervention
  Future<bool> delete(int id) async {
    final response = await _api.deleteIntervention(id);
    return response.success;
  }
}