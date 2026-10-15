import 'package:citoyen_alerte_app_backup/data/models/report_model.dart';

class AgentDashboardModel {
  final int assignedReports;
  final int completedToday;
  final int totalInterventions;
  final int pendingReports;
  final int inProgress;
  final List<ReportModel> recentAssignments;

  final int? authorityId;
  final String? authorityName;
  final String? authorityType;

  const AgentDashboardModel({
    required this.assignedReports,
    required this.completedToday,
    required this.totalInterventions,
    required this.pendingReports,
    required this.inProgress,
    this.recentAssignments = const [],
    this.authorityId,
    this.authorityName,
    this.authorityType,
  });

  factory AgentDashboardModel.fromJson(Map<String, dynamic> json) {
    final List<ReportModel> assignments = [];
    final rawList = json['recent_assignments'] as List?;
    if (rawList != null) {
      for (final item in rawList) {
        try {
          if (item is Map<String, dynamic>) {
            assignments.add(ReportModel.fromJson(item));
          }
        } catch (_) {
        }
      }
    }

    return AgentDashboardModel(
      assignedReports:    (json['assigned_reports']    as num?)?.toInt() ?? 0,
      completedToday:     (json['completed_today']     as num?)?.toInt() ?? 0,
      totalInterventions: (json['total_interventions'] as num?)?.toInt() ?? 0,
      pendingReports:     (json['pending_reports']     as num?)?.toInt() ?? 0,
      inProgress:         (json['in_progress']         as num?)?.toInt() ?? 0,
      recentAssignments:  assignments,
      authorityId:        (json['authority_id']        as num?)?.toInt(),
      authorityName:       json['authority_name']       as String?,
      authorityType:       json['authority_type']       as String?,
    );
  }

  String get authorityTypeLabel => switch (authorityType) {
    'government'   => 'Gouvernement',
    'municipality' => 'Mairie',
    'company'      => 'Entreprise',
    'ngo'          => 'ONG',
    'security'     => 'Sécurité',
    'health'       => 'Santé',
    'environment'  => 'Environnement',
    _              => authorityType ?? '',
  };

  bool get hasAuthority => authorityId != null;
}

// ─── ADMIN DASHBOARD ──────────────────────────────────────────────────────────

class AdminOverviewModel {
  final int totalUsers;
  final int totalCitizens;
  final int totalAgents;
  final int totalReports;
  final int reportsToday;
  final int pendingReports;
  final int resolvedReports;

  const AdminOverviewModel({
    required this.totalUsers,
    required this.totalCitizens,
    required this.totalAgents,
    required this.totalReports,
    required this.reportsToday,
    required this.pendingReports,
    required this.resolvedReports,
  });

  factory AdminOverviewModel.fromJson(Map<String, dynamic> json) {
    return AdminOverviewModel(
      totalUsers:     (json['total_users']     as num?)?.toInt() ?? 0,
      totalCitizens:  (json['total_citizens']  as num?)?.toInt() ?? 0,
      totalAgents:    (json['total_agents']    as num?)?.toInt() ?? 0,
      totalReports:   (json['total_reports']   as num?)?.toInt() ?? 0,
      reportsToday:   (json['reports_today']   as num?)?.toInt() ?? 0,
      pendingReports: (json['pending_reports'] as num?)?.toInt() ?? 0,
      resolvedReports:(json['resolved_reports']as num?)?.toInt() ?? 0,
    );
  }
}

class AdminReportsByStatus {
  final int pending;
  final int routed;
  final int inProgress;
  final int resolved;

  const AdminReportsByStatus({
    required this.pending,
    required this.routed,
    required this.inProgress,
    required this.resolved,
  });

  factory AdminReportsByStatus.fromJson(Map<String, dynamic> json) {
    return AdminReportsByStatus(
      pending:    (json['pending']     as num?)?.toInt() ?? 0,
      routed:     (json['routed']      as num?)?.toInt() ?? 0,
      inProgress: (json['in_progress'] as num?)?.toInt() ?? 0,
      resolved:   (json['resolved']    as num?)?.toInt() ?? 0,
    );
  }

  int get total => pending + routed + inProgress + resolved;
}

class AdminReportsBySeverity {
  final int low;
  final int medium;
  final int high;

  const AdminReportsBySeverity({
    required this.low,
    required this.medium,
    required this.high,
  });

  factory AdminReportsBySeverity.fromJson(Map<String, dynamic> json) {
    return AdminReportsBySeverity(
      low:    (json['low']    as num?)?.toInt() ?? 0,
      medium: (json['medium'] as num?)?.toInt() ?? 0,
      high:   (json['high']   as num?)?.toInt() ?? 0,
    );
  }

  int get total => low + medium + high;
}

class AdminCategoryStatModel {
  final int id;
  final String name;
  final int count;

  const AdminCategoryStatModel({
    required this.id,
    required this.name,
    required this.count,
  });

  factory AdminCategoryStatModel.fromJson(Map<String, dynamic> json) {
    return AdminCategoryStatModel(
      id:    (json['id']    as num?)?.toInt() ?? 0,
      name:   json['name']  as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class AdminAgentPerformanceModel {
  final int id;
  final String name;
  final int totalAssigned;
  final int totalResolved;

  const AdminAgentPerformanceModel({
    required this.id,
    required this.name,
    required this.totalAssigned,
    required this.totalResolved,
  });

  factory AdminAgentPerformanceModel.fromJson(Map<String, dynamic> json) {
    return AdminAgentPerformanceModel(
      id:            (json['id']             as num?)?.toInt() ?? 0,
      name:           json['name']            as String? ?? '',
      totalAssigned: (json['total_assigned'] as num?)?.toInt() ?? 0,
      totalResolved: (json['total_resolved'] as num?)?.toInt() ?? 0,
    );
  }

  double get resolutionRate =>
      totalAssigned > 0 ? (totalResolved / totalAssigned) * 100 : 0;
}

class AdminRecentPeriodModel {
  final int newReports;
  final int resolved;
  final int newUsers;

  const AdminRecentPeriodModel({
    required this.newReports,
    required this.resolved,
    required this.newUsers,
  });

  factory AdminRecentPeriodModel.fromJson(Map<String, dynamic> json) {
    return AdminRecentPeriodModel(
      newReports: (json['new_reports'] as num?)?.toInt() ?? 0,
      resolved:   (json['resolved']    as num?)?.toInt() ?? 0,
      newUsers:   (json['new_users']   as num?)?.toInt() ?? 0,
    );
  }
}

class AdminDashboardModel {
  final AdminOverviewModel overview;
  final AdminReportsByStatus reportsByStatus;
  final AdminReportsBySeverity reportsBySeverity;
  final List<AdminCategoryStatModel> reportsByCategory;
  final AdminRecentPeriodModel recentPeriod;
  final List<AdminAgentPerformanceModel> agentPerformance;
  final List<ReportModel> recentReports;
  final int flaggedReports;
  final int pendingAppeals;

  const AdminDashboardModel({
    required this.overview,
    required this.reportsByStatus,
    required this.reportsBySeverity,
    this.reportsByCategory = const [],
    required this.recentPeriod,
    this.agentPerformance = const [],
    this.recentReports = const [],
    this.flaggedReports = 0,
    this.pendingAppeals = 0,
  });

  factory AdminDashboardModel.fromJson(Map<String, dynamic> json) {
    final byStatus   = json['reports_by_status']   as Map<String, dynamic>? ?? {};
    final bySeverity = json['reports_by_severity'] as Map<String, dynamic>? ?? {};

    final List<ReportModel> recentReports = [];
    final rawRecent = json['recent'] as List?;
    if (rawRecent != null) {
      for (final item in rawRecent) {
        try {
          if (item is Map<String, dynamic>) {
            recentReports.add(ReportModel.fromJson(item));
          }
        } catch (_) {}
      }
    }

    return AdminDashboardModel(
      overview: AdminOverviewModel.fromJson(
          json['overview'] as Map<String, dynamic>? ?? {}),
      reportsByStatus:   AdminReportsByStatus.fromJson(byStatus),
      reportsBySeverity: AdminReportsBySeverity.fromJson(bySeverity),
      reportsByCategory: (json['reports_by_category'] as List?)
          ?.map((e) => AdminCategoryStatModel.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      recentPeriod: AdminRecentPeriodModel.fromJson(
          json['recent_period'] as Map<String, dynamic>? ?? {}),
      agentPerformance: (json['agent_performance'] as List?)
          ?.map((e) => AdminAgentPerformanceModel.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      recentReports: recentReports,
      flaggedReports: (json['flagged_reports'] as num?)?.toInt() ?? 0,
      pendingAppeals: (json['pending_appeals'] as num?)?.toInt() ?? 0,
    );
  }
}