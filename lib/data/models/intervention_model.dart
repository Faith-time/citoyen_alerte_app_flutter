class InterventionModel {
  final int id;
  final int agentId;
  final int reportId;
  final int? authorityId;
  final InterventionStatus status;
  final String? notes;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? reportTitle;
  final String? reportReference;
  final String? authorityName;
  final String? reportAddress;
  final String? reportCommune;
  final String? reportRegion;
  final double? reportLatitude;
  final double? reportLongitude;

  const InterventionModel({
    required this.id,
    required this.agentId,
    required this.reportId,
    this.authorityId,
    required this.status,
    this.notes,
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.updatedAt,
    this.reportTitle,

    this.reportReference,
    this.authorityName,
    this.reportAddress,
    this.reportCommune,
    this.reportRegion,
    this.reportLatitude,
    this.reportLongitude,
  });

  factory InterventionModel.fromJson(Map<String, dynamic> json) {
    double? _parseDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    return InterventionModel(
      id:          json['id'] as int,
      agentId:     json['agent_id'] as int,
      reportId:    json['report_id'] as int,
      authorityId: json['authority_id'] != null ? _parseInt(json['authority_id']) : null,
      status:      InterventionStatus.fromString(json['status'] as String? ?? 'pending'),
      notes:       json['notes'] as String?,
      startedAt:   json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      createdAt:   json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,

      updatedAt:   json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      reportTitle:     json['report_title'] as String?,
      reportReference: json['report_reference'] as String?,
      authorityName:   json['authority_name'] as String?,
      reportAddress:   json['report_address'] as String?,
      reportCommune:   json['report_commune'] as String?,
      reportRegion:    json['report_region'] as String?,
      reportLatitude:  _parseDouble(json['report_latitude']),
      reportLongitude: _parseDouble(json['report_longitude']),
    );
  }

  static int _parseInt(dynamic v) =>
      v is int ? v : int.parse(v.toString());

  Map<String, dynamic> toJson() => {
    'id':               id,
    'agent_id':         agentId,
    'report_id':        reportId,
    'authority_id':     authorityId,
    'status':           status.value,
    'notes':            notes,
    'started_at':       startedAt?.toIso8601String(),
    'completed_at':     completedAt?.toIso8601String(),
    'created_at':       createdAt?.toIso8601String(),
    'updated_at':       updatedAt?.toIso8601String(),
    'report_title':     reportTitle,
    'report_reference': reportReference,
    'authority_name':   authorityName,
    'report_address':   reportAddress,

    'report_commune':   reportCommune,
    'report_region':    reportRegion,
    'report_latitude':  reportLatitude,
    'report_longitude': reportLongitude,
  };

  InterventionModel copyWith({
    int? id,
    int? agentId,
    int? reportId,
    int? authorityId,
    InterventionStatus? status,
    String? notes,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? reportTitle,
    String? reportReference,
    String? authorityName,
    String? reportAddress,
    String? reportCommune,
    String? reportRegion,
    double? reportLatitude,
    double? reportLongitude,
  }) {
    return InterventionModel(
      id:              id              ?? this.id,
      agentId:         agentId         ?? this.agentId,
      reportId:        reportId        ?? this.reportId,
      authorityId:     authorityId     ?? this.authorityId,
      status:          status          ?? this.status,

      notes:           notes           ?? this.notes,
      startedAt:       startedAt       ?? this.startedAt,
      completedAt:     completedAt     ?? this.completedAt,
      createdAt:       createdAt       ?? this.createdAt,
      updatedAt:       updatedAt       ?? this.updatedAt,
      reportTitle:     reportTitle     ?? this.reportTitle,
      reportReference: reportReference ?? this.reportReference,
      authorityName:   authorityName   ?? this.authorityName,
      reportAddress:   reportAddress   ?? this.reportAddress,
      reportCommune:   reportCommune   ?? this.reportCommune,
      reportRegion:    reportRegion    ?? this.reportRegion,
      reportLatitude:  reportLatitude  ?? this.reportLatitude,
      reportLongitude: reportLongitude ?? this.reportLongitude,
    );
  }

  bool get isPending    => status == InterventionStatus.pending;
  bool get isInProgress => status == InterventionStatus.inProgress;
  bool get isCompleted  => status == InterventionStatus.completed;
  bool get isCancelled  => status == InterventionStatus.cancelled;

  bool get hasLocation => reportLatitude != null && reportLongitude != null;

  String get locationLabel {
    final parts = [reportAddress, reportCommune, reportRegion]
        .where((s) => s != null && s.isNotEmpty)
        .toList();
    return parts.isNotEmpty ? parts.join(', ') : 'Localisation non précisée';
  }

  @override
  String toString() =>

      'InterventionModel(id: $id, reportId: $reportId, status: ${status.value}, reportTitle: $reportTitle)';
}


enum InterventionStatus {
  pending('pending'),
  inProgress('in_progress'),
  completed('completed'),
  cancelled('cancelled');

  const InterventionStatus(this.value);
  final String value;

  static InterventionStatus fromString(String value) {
    return InterventionStatus.values.firstWhere(
          (e) => e.value == value,
      orElse: () => InterventionStatus.pending,
    );
  }

  String get label => switch (this) {
    InterventionStatus.pending    => 'En attente',
    InterventionStatus.inProgress => 'En cours',
    InterventionStatus.completed  => 'Terminée',
    InterventionStatus.cancelled  => 'Annulée',
  };
}