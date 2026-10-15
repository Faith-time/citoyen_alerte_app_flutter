// lib/core/services/dashboard_service.dart

import 'package:get/get.dart';
import 'package:citoyen_alerte_app_backup/core/services/api_service.dart';
import 'package:citoyen_alerte_app_backup/data/models/dashboard_model.dart';

class DashboardService extends GetxService {
  static DashboardService get instance => Get.find<DashboardService>();

  final ApiService _api = Get.find<ApiService>();

  // ── Agent ─────────────────────────────────────────────────────────────────

  final agentDashboard = Rx<AgentDashboardModel?>(null);
  final isLoadingAgent = false.obs;
  final agentError = ''.obs;

  Future<AgentDashboardModel?> fetchAgentDashboard({bool silent = false}) async {
    try {
      if (!silent) isLoadingAgent.value = true;
      agentError.value = '';

      final response = await _api.getAgentDashboard();

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        // ApiService extrait déjà data['data'] — on vérifie les deux cas
        final payload = (data.containsKey('assigned_reports')
            ? data
            : data['data'] ?? data) as Map<String, dynamic>;

        // Parse défensif : si fromJson plante, on renvoie un modèle vide
        AgentDashboardModel model;
        try {
          model = AgentDashboardModel.fromJson(payload);
        } catch (parseError) {
          // Construire un modèle minimal avec les champs simples
          model = AgentDashboardModel(
            assignedReports:
            (payload['assigned_reports'] as num?)?.toInt() ?? 0,
            completedToday:
            (payload['completed_today'] as num?)?.toInt() ?? 0,
            totalInterventions:
            (payload['total_interventions'] as num?)?.toInt() ?? 0,
            pendingReports:
            (payload['pending_reports'] as num?)?.toInt() ?? 0,
            inProgress: (payload['in_progress'] as num?)?.toInt() ?? 0,
            recentAssignments: const [],
          );
        }

        agentDashboard.value = model;
        return model;
      }

      agentError.value = response.message ?? 'Erreur lors du chargement';
      return null;
    } catch (e) {
      agentError.value = e.toString();
      return null;
    } finally {
      if (!silent) isLoadingAgent.value = false;
    }
  }

  // ── Admin ─────────────────────────────────────────────────────────────────

  final adminDashboard = Rx<AdminDashboardModel?>(null);
  final isLoadingAdmin = false.obs;
  final adminError = ''.obs;

  Future<AdminDashboardModel?> fetchAdminDashboard({
    String period = 'month',
    bool silent = false,
  }) async {
    try {
      if (!silent) isLoadingAdmin.value = true;
      adminError.value = '';

      final response = await _api.getAdminDashboard(period: period);

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final payload = data['data'] ?? data;
        final model =
        AdminDashboardModel.fromJson(payload as Map<String, dynamic>);
        adminDashboard.value = model;
        return model;
      }

      adminError.value = response.message ?? 'Erreur lors du chargement';
      return null;
    } catch (e) {
      adminError.value = e.toString();
      return null;
    } finally {
      if (!silent) isLoadingAdmin.value = false;
    }
  }

  // ── Citizen ───────────────────────────────────────────────────────────────

  final citizenDashboard = Rx<Map<String, dynamic>?>(null);
  final isLoadingCitizen = false.obs;

  Future<Map<String, dynamic>?> fetchCitizenDashboard(
      {bool silent = false}) async {
    try {
      if (!silent) isLoadingCitizen.value = true;

      final response = await _api.getCitizenDashboard();

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final payload = (data['data'] ?? data) as Map<String, dynamic>;
        citizenDashboard.value = payload;
        return payload;
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      if (!silent) isLoadingCitizen.value = false;
    }
  }

  void clearAll() {
    agentDashboard.value = null;
    adminDashboard.value = null;
    citizenDashboard.value = null;
  }
}