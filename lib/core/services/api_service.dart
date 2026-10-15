// lib/core/services/api_service.dart

import 'package:dio/dio.dart';
import 'package:citoyen_alerte_app_backup/core/services/auth_service.dart';
import 'package:citoyen_alerte_app_backup/core/network/dio_client.dart';
import 'package:citoyen_alerte_app_backup/core/network/api_response.dart';
import 'package:citoyen_alerte_app_backup/core/constants/api_constants.dart';

class ApiService {
  final DioClient _dioClient;

  ApiService(this._dioClient);

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPER INTERNE
  // ══════════════════════════════════════════════════════════════════════════

  ApiResponse _parse(Response response) => ApiResponse.fromJson(
    response.data,
    null,
    httpStatusCode: response.statusCode,
  );

  // ══════════════════════════════════════════════════════════════════════════
  //  HELPERS GÉNÉRIQUES (utilisés par AdminDashboardController via _api.get)
  // ══════════════════════════════════════════════════════════════════════════

  Future<ApiResponse> getResolvedNewsFeed({
    Map<String, dynamic>? queryParameters,
  }) async {
    return get(
      '${ApiConstants.reports}/resolved-feed',
      queryParameters: queryParameters,
    );
  }

  Future<ApiResponse> get(
      String path, {
        Map<String, dynamic>? queryParameters,
      }) async {
    final response = await _dioClient.get(
      path,
      queryParameters: queryParameters,
    );
    return _parse(response);
  }

  Future<ApiResponse> post(
      String path, {
        dynamic data,
      }) async {
    final response = await _dioClient.post(path, data: data);
    return _parse(response);
  }

  Future<ApiResponse> put(
      String path, {
        dynamic data,
      }) async {
    final response = await _dioClient.put(path, data: data);
    return _parse(response);
  }

  Future<ApiResponse> deleteGeneric(String path, {dynamic data}) async {
    final response = await _dioClient.delete(path, data: data);
    return _parse(response);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  AUTH
  // ══════════════════════════════════════════════════════════════════════════

  /// ✅ Login — extrait authority_id et le persiste dans AuthService
  Future<ApiResponse> login(String email, String password) async {
    final response = await _dioClient.post(
      ApiConstants.login,
      data: {'email': email, 'password': password},
    );

    final apiResp = _parse(response);

    if (apiResp.success && apiResp.data != null) {
      final data  = apiResp.data as Map<String, dynamic>;
      final user  = data['user']         as Map<String, dynamic>;
      final token = data['access_token'] as String;

      // ✅ authority_id : null = admin système, int = mairie
      final authorityId = user['authority_id'] as int?;

      await AuthService.instance.saveLoginData(
        id          : user['id'].toString(),
        name        : (user['name']  as String?) ?? '',
        email       : (user['email'] as String?) ?? '',
        token       : token,
        phone       : user['phone']  as String?,
        avatar      : user['avatar'] as String?,
        role        : (user['role']  as String?) ?? 'citizen',
        authorityId : authorityId, // ✅
      );

      _dioClient.updateAuthToken(token);
    }

    return apiResp;
  }

  Future<ApiResponse> register(Map<String, dynamic> data) async {
    final response  = await _dioClient.post(ApiConstants.register, data: data);
    final apiResp   = _parse(response);

    if (apiResp.success && apiResp.data != null) {
      final body  = apiResp.data as Map<String, dynamic>;
      final user  = body['user']         as Map<String, dynamic>;
      final token = body['access_token'] as String;

      await AuthService.instance.saveLoginData(
        id          : user['id'].toString(),
        name        : (user['name']  as String?) ?? '',
        email       : (user['email'] as String?) ?? '',
        token       : token,
        phone       : user['phone']  as String?,
        avatar      : user['avatar'] as String?,
        role        : (user['role']  as String?) ?? 'citizen',
        authorityId : user['authority_id'] as int?,
        provider    : 'email',
      );
      _dioClient.updateAuthToken(token);
    }
    return apiResp;
  }

  Future<ApiResponse> googleAuth(Map<String, dynamic> googleData) async {
    final response = await _dioClient.post(
      ApiConstants.googleAuth,
      data: googleData,
    );
    final apiResp = _parse(response);

    if (apiResp.success && apiResp.data != null) {
      final body  = apiResp.data as Map<String, dynamic>;
      final user  = body['user']         as Map<String, dynamic>;
      final token = body['access_token'] as String;

      await AuthService.instance.saveLoginData(
        id          : user['id'].toString(),
        name        : (user['name']  as String?) ?? '',
        email       : (user['email'] as String?) ?? '',
        token       : token,
        phone       : user['phone']  as String?,
        avatar      : user['avatar'] as String?,
        role        : (user['role']  as String?) ?? 'citizen',
        authorityId : user['authority_id'] as int?,
        provider    : 'google',
      );
      _dioClient.updateAuthToken(token);
    }
    return apiResp;
  }

  Future<ApiResponse> logout() async {
    try {
      final response = await _dioClient.post(ApiConstants.logout);
      await AuthService.instance.logout();
      return _parse(response);
    } catch (e) {
      await AuthService.instance.logout();
      rethrow;
    }
  }

  Future<ApiResponse> refreshToken() async {
    final response = await _dioClient.post(ApiConstants.refresh);
    final apiResp  = _parse(response);

    if (apiResp.success && apiResp.data != null) {
      final body     = apiResp.data as Map<String, dynamic>;
      final newToken = body['access_token'] as String;
      await AuthService.instance.updateToken(newToken);
      _dioClient.updateAuthToken(newToken);
    }
    return apiResp;
  }

  Future<ApiResponse> getCurrentUser() async {
    final response = await _dioClient.get(ApiConstants.me);
    final apiResp  = _parse(response);

    if (apiResp.success && apiResp.data != null) {
      final user = apiResp.data as Map<String, dynamic>;
      await AuthService.instance.updateProfile(
        name  : user['name']   as String?,
        email : user['email']  as String?,
        phone : user['phone']  as String?,
        avatar: user['avatar'] as String?,
      );
    }
    return apiResp;
  }

  Future<ApiResponse> updateProfile(Map<String, dynamic> data) async {
    final response = await _dioClient.put(
      ApiConstants.updateProfile,
      data: data,
    );
    final apiResp = _parse(response);

    if (apiResp.success && apiResp.data != null) {
      final user = apiResp.data as Map<String, dynamic>;
      await AuthService.instance.updateProfile(
        name  : user['name']   as String?,
        email : user['email']  as String?,
        phone : user['phone']  as String?,
        avatar: user['avatar'] as String?,
      );
    }
    return apiResp;
  }

  Future<ApiResponse> changePassword(Map<String, dynamic> data) async {
    final response = await _dioClient.post(
      ApiConstants.changePassword,
      data: data,
    );
    final apiResp = _parse(response);

    if (apiResp.success && apiResp.data != null) {
      final body = apiResp.data as Map<String, dynamic>;
      if (body.containsKey('access_token')) {
        final newToken = body['access_token'] as String;
        await AuthService.instance.updateToken(newToken);
        _dioClient.updateAuthToken(newToken);
      }
    }
    return apiResp;
  }

  Future<ApiResponse> forgotPassword(String email) async {
    final response = await _dioClient.post(
      ApiConstants.forgotPassword,
      data: {'email': email},
    );
    return _parse(response);
  }

  Future<ApiResponse> resetPassword({
    required String email,
    required String token,
    required String password,
    required String passwordConfirmation,
  }) async {
    final response = await _dioClient.post(
      ApiConstants.resetPassword,
      data: {
        'email'                : email,
        'token'                : token,
        'password'             : password,
        'password_confirmation': passwordConfirmation,
      },
    );
    return _parse(response);
  }

  Future<ApiResponse> verifyPhone(String code) async {
    final response = await _dioClient.post(
      ApiConstants.verifyPhone,
      data: {'verification_code': code},
    );
    return _parse(response);
  }

  Future<ApiResponse> sendVerificationCode() async {
    final response = await _dioClient.post(ApiConstants.sendVerificationCode);
    return _parse(response);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  REPORTS
  // ══════════════════════════════════════════════════════════════════════════

  /// ✅ Supporte authority_id pour filtrer les signalements d'une mairie
  Future<ApiResponse> getReports({
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dioClient.get(
      ApiConstants.reports,
      queryParameters: queryParameters,
    );
    return _parse(response);
  }

  Future<ApiResponse> getReportById(int id) async {
    final response = await _dioClient.get('${ApiConstants.reports}/$id');
    return _parse(response);
  }

  Future<ApiResponse> createReport(FormData formData) async {
    final response = await _dioClient.post(
      ApiConstants.reports,
      data: formData,
    );
    return _parse(response);
  }

  Future<ApiResponse> updateReport(int id, Map<String, dynamic> data) async {
    final response = await _dioClient.put(
      '${ApiConstants.reports}/$id',
      data: data,
    );
    return _parse(response);
  }

  Future<ApiResponse> deleteReport(int id) async {
    final response = await _dioClient.delete('${ApiConstants.reports}/$id');
    return _parse(response);
  }

  Future<ApiResponse> updateReportStatus(int id, String status) async {
    final response = await _dioClient.put(
      '${ApiConstants.reports}/$id/status',
      data: {'status': status},
    );
    return _parse(response);
  }

  Future<ApiResponse> getNearbyReports({
    required double lat,
    required double lng,
    double radius = 5.0,
  }) async {
    final response = await _dioClient.post(
      ApiConstants.reportNearby,
      data: {'latitude': lat, 'longitude': lng, 'radius': radius},
    );
    return _parse(response);
  }

  Future<ApiResponse> getUserReports(
      String userId, {
        Map<String, dynamic>? queryParameters,
      }) async {
    final response = await _dioClient.get(
      '${ApiConstants.reports}/user/$userId',
      queryParameters: {
        'per_page'   : 100,
        'sort_by'    : 'created_at',
        'sort_order' : 'desc',
        ...?queryParameters,
      },
    );
    return _parse(response);
  }

  Future<ApiResponse> assignAgentToReport(int reportId, int agentId) {
    return post(ApiConstants.interventions, data: {
      'report_id': reportId,
      'agent_id': agentId,
    });
  }

  Future<ApiResponse> assignReport(int id, int agentId) async {
    final response = await _dioClient.post(
      ApiConstants.reportAssign.replaceAll('{id}', id.toString()),
      data: {'agent_id': agentId},
    );
    return _parse(response);
  }

  Future<ApiResponse> acceptReport(int reportId, int routingId) async {
    final path = ApiConstants.reportAccept
        .replaceAll('{id}', reportId.toString())
        .replaceAll('{rid}', routingId.toString());
    return put(path);
  }

  Future<ApiResponse> resolveReport(int reportId, int routingId, String notes) async {
    final path = ApiConstants.reportResolve
        .replaceAll('{id}', reportId.toString())
        .replaceAll('{rid}', routingId.toString());
    return put(path, data: {'resolution_notes': notes});
  }

  // ── Images ────────────────────────────────────────────────────────────────

  Future<ApiResponse> getReportImages(int reportId) async {
    final response = await _dioClient.get(
      '${ApiConstants.reports}/$reportId/images',
    );
    return _parse(response);
  }

  Future<ApiResponse> uploadReportImage(
      int reportId,
      FormData formData,
      ) async {
    final response = await _dioClient.post(
      '${ApiConstants.reports}/$reportId/images',
      data: formData,
    );
    return _parse(response);
  }

  Future<ApiResponse> uploadReportImages(
      int reportId,
      FormData formData,
      ) async {
    final response = await _dioClient.post(
      '${ApiConstants.reports}/$reportId/images/multiple',
      data: formData,
    );
    return _parse(response);
  }

  Future<ApiResponse> deleteReportImage(int reportId, int imageId) async {
    final response = await _dioClient.delete(
      '${ApiConstants.reports}/$reportId/images/$imageId',
    );
    return _parse(response);
  }

  // ── Routage ───────────────────────────────────────────────────────────────

  Future<ApiResponse> getReportRoutings(int reportId) async {
    final response = await _dioClient.get(
      '${ApiConstants.reports}/$reportId/routings',
    );
    return _parse(response);
  }

  Future<ApiResponse> createReportRouting(
      int reportId,
      Map<String, dynamic> data,
      ) async {
    final response = await _dioClient.post(
      '${ApiConstants.reports}/$reportId/routings',
      data: data,
    );
    return _parse(response);
  }

  Future<ApiResponse> updateRoutingStatus(
      int reportId,
      int routingId,
      String action,
      ) async {
    final response = await _dioClient.put(
      '${ApiConstants.reports}/$reportId/routings/$routingId/$action',
    );
    return _parse(response);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CATEGORIES
  // ══════════════════════════════════════════════════════════════════════════

  Future<ApiResponse> getCategories({
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dioClient.get(
      ApiConstants.categories,
      queryParameters: queryParameters,
    );
    return _parse(response);
  }

  Future<ApiResponse> getCategoryById(int id) async {
    final response = await _dioClient.get('${ApiConstants.categories}/$id');
    return _parse(response);
  }

  Future<ApiResponse> getCategoryAuthorities(int categoryId) async {
    final response = await _dioClient.get(
      '${ApiConstants.categories}/$categoryId/authorities',
    );
    return _parse(response);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  AUTHORITIES
  // ══════════════════════════════════════════════════════════════════════════

  Future<ApiResponse> getAuthorities({
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dioClient.get(
      ApiConstants.authorities,
      queryParameters: queryParameters,
    );
    return _parse(response);
  }

  Future<ApiResponse> getAuthorityById(int id) async {
    final response = await _dioClient.get('${ApiConstants.authorities}/$id');
    return _parse(response);
  }

  Future<ApiResponse> getAuthoritiesForCategory(int categoryId) async {
    final response = await _dioClient.get(
      '${ApiConstants.authorities}/for-category/$categoryId',
    );
    return _parse(response);
  }

  Future<ApiResponse> suggestAuthorities(int categoryId) async {
    final response = await _dioClient.post(
      '${ApiConstants.authorities}/suggest',
      data: {'category_id': categoryId},
    );
    return _parse(response);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  REGIONS & COMMUNES
  // ══════════════════════════════════════════════════════════════════════════

  Future<ApiResponse> getRegions({
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dioClient.get(
      ApiConstants.regions,
      queryParameters: queryParameters,
    );
    return _parse(response);
  }

  Future<ApiResponse> getCommunes({
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dioClient.get(
      ApiConstants.communes,
      queryParameters: queryParameters,
    );
    return _parse(response);
  }

  Future<ApiResponse> getCommunesByRegion(int regionId) async {
    final response = await _dioClient.get(
      ApiConstants.communes,
      queryParameters: {'region_id': regionId},
    );
    return _parse(response);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  AGENT ZONES
  // ══════════════════════════════════════════════════════════════════════════

  Future<ApiResponse> getAgentZones({
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dioClient.get(
      ApiConstants.agentZones,
      queryParameters: queryParameters,
    );
    return _parse(response);
  }

  Future<ApiResponse> getAgentZoneById(int id) async {
    final response = await _dioClient.get('${ApiConstants.agentZones}/$id');
    return _parse(response);
  }

  Future<ApiResponse> createAgentZone(Map<String, dynamic> data) async {
    final response = await _dioClient.post(
      ApiConstants.agentZones,
      data: data,
    );
    return _parse(response);
  }

  Future<ApiResponse> updateAgentZone(int id, Map<String, dynamic> data) async {
    final response = await _dioClient.put(
      '${ApiConstants.agentZones}/$id',
      data: data,
    );
    return _parse(response);
  }

  Future<ApiResponse> deleteAgentZone(int id) async {
    final response = await _dioClient.delete('${ApiConstants.agentZones}/$id');
    return _parse(response);
  }

  Future<ApiResponse> setAgentZonePrimary(int id) async {
    final response = await _dioClient.put(
      '${ApiConstants.agentZones}/$id/set-primary',
    );
    return _parse(response);
  }

  Future<ApiResponse> getAvailableAgents({
    required double lat,
    required double lng,
    int? authorityId,
  }) async {
    final response = await _dioClient.get(
      '${ApiConstants.agentZones}/available',
      queryParameters: {
        'lat': lat,
        'lng': lng,
        if (authorityId != null) 'authority_id': authorityId,
      },
    );
    return _parse(response);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  NOTIFICATIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<ApiResponse> getNotifications({
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dioClient.get(
      ApiConstants.notifications,
      queryParameters: queryParameters,
    );
    return _parse(response);
  }

  Future<ApiResponse> markNotificationAsRead(int id) async {
    final response = await _dioClient.post(
      ApiConstants.notificationsMarkAsRead.replaceAll('{id}', id.toString()),
    );
    return _parse(response);
  }

  Future<ApiResponse> markAllNotificationsAsRead() async {
    final response = await _dioClient.post(
      ApiConstants.notificationsMarkAllAsRead,
    );
    return _parse(response);
  }

  Future<ApiResponse> getUnreadNotificationsCount() async {
    final response = await _dioClient.get(
      '${ApiConstants.notifications}/unread/count',
    );
    return _parse(response);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  VOTES & COMMENTS
  // ══════════════════════════════════════════════════════════════════════════

  Future<ApiResponse> voteReport({
    required int reportId,
    required String type,
  }) async {
    final response = await _dioClient.post(
      ApiConstants.votes,
      data: {'report_id': reportId, 'type': type},
    );
    return _parse(response);
  }

  Future<ApiResponse> getComments(int reportId) async {
    final response = await _dioClient.get(
      ApiConstants.comments,
      queryParameters: {'report_id': reportId},
    );
    return _parse(response);
  }

  Future<ApiResponse> createComment({
    required int reportId,
    required String comment,
    int? parentId,
  }) async {
    final response = await _dioClient.post(
      ApiConstants.comments,
      data: {
        'report_id': reportId,
        'comment'  : comment,
        if (parentId != null) 'parent_id': parentId,
      },
    );
    return _parse(response);
  }

  Future<ApiResponse> deleteComment(int id) async {
    final response = await _dioClient.delete('${ApiConstants.comments}/$id');
    return _parse(response);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  EMERGENCY CONTACTS
  // ══════════════════════════════════════════════════════════════════════════

  Future<ApiResponse> getEmergencyContacts({
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dioClient.get(
      ApiConstants.emergencyContacts,
      queryParameters: queryParameters,
    );
    return _parse(response);
  }

  Future<ApiResponse> getNearbyEmergencyContacts({
    required double lat,
    required double lng,
    double radius = 10.0,
  }) async {
    final response = await _dioClient.post(
      '${ApiConstants.emergencyContacts}/nearby',
      data: {'latitude': lat, 'longitude': lng, 'radius': radius},
    );
    return _parse(response);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DASHBOARDS
  // ══════════════════════════════════════════════════════════════════════════

  Future<ApiResponse> getCitizenDashboard() async {
    final response = await _dioClient.get(ApiConstants.dashboardCitizen);
    return _parse(response);
  }

  Future<ApiResponse> getAgentDashboard() async {
    final response = await _dioClient.get(ApiConstants.dashboardAgent);
    return _parse(response);
  }

  Future<ApiResponse> getAdminDashboard({String period = 'month'}) async {
    final response = await _dioClient.get(
      ApiConstants.dashboardAdmin,
      queryParameters: {'period': period},
    );
    return _parse(response);
  }

  /// ✅ Dashboard mairie (admin + authority_id non null)
  Future<ApiResponse> getMairieDashboard() async {
    final response = await _dioClient.get(ApiConstants.dashboardMairie);
    return _parse(response);
  }

  /// ✅ Dashboard authority
  Future<ApiResponse> getAuthorityDashboard() async {
    final response = await _dioClient.get(ApiConstants.dashboardAuthority);
    return _parse(response);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INTERVENTIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<ApiResponse> getInterventions({
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dioClient.get(
      ApiConstants.interventions,
      queryParameters: queryParameters,
    );
    return _parse(response);
  }

  Future<ApiResponse> getInterventionById(int id) async {
    final response = await _dioClient.get(
      '${ApiConstants.interventions}/$id',
    );
    return _parse(response);
  }

  Future<ApiResponse> getMyInterventions({
    Map<String, dynamic>? queryParameters,
  }) async {
    final response = await _dioClient.get(
      '${ApiConstants.interventions}/mine',
      queryParameters: queryParameters,
    );
    return _parse(response);
  }

  Future<ApiResponse> createIntervention(Map<String, dynamic> data) async {
    final response = await _dioClient.post(
      ApiConstants.interventions,
      data: data,
    );
    return _parse(response);
  }

  Future<ApiResponse> updateIntervention(
      int id,
      Map<String, dynamic> data,
      ) async {
    final response = await _dioClient.put(
      '${ApiConstants.interventions}/$id',
      data: data,
    );
    return _parse(response);
  }

  Future<ApiResponse> updateInterventionStatus(
      int id,
      Map<String, dynamic> data,
      ) async {
    final response = await _dioClient.put(
      '${ApiConstants.interventions}/$id/status',
      data: data,
    );
    return _parse(response);
  }

  Future<ApiResponse> completeIntervention(int id) async {
    final response = await _dioClient.post(
      '${ApiConstants.interventions}/$id/complete',
    );
    return _parse(response);
  }

  Future<ApiResponse> deleteIntervention(int id) async {
    final response = await _dioClient.delete(
      '${ApiConstants.interventions}/$id',
    );
    return _parse(response);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SETTINGS
  // ══════════════════════════════════════════════════════════════════════════

  Future<ApiResponse> getPublicSettings() async {
    final response = await _dioClient.get(ApiConstants.settingsPublic);
    return _parse(response);
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  UPLOAD
  // ══════════════════════════════════════════════════════════════════════════

  Future<ApiResponse> uploadFile({
    required String path,
    required String filePath,
    String fieldName = 'file',
    Map<String, dynamic>? additionalData,
  }) async {
    final formData = FormData.fromMap({
      fieldName: await MultipartFile.fromFile(filePath),
      if (additionalData != null) ...additionalData,
    });
    final response = await _dioClient.post(path, data: formData);
    return _parse(response);
  }

  Future<String?> uploadAvatar(String filePath) async {
    final response = await uploadFile(
      path      : '/upload/avatar',
      filePath  : filePath,
      fieldName : 'avatar',
    );
    if (response.success && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      return data['avatar_url'] as String?;
    }
    return null;
  }
}