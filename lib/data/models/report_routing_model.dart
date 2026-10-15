// lib/data/models/report_routing_model.dart

import 'authority_model.dart';

class ReportRoutingModel {
  final int id;
  final int reportId;
  final int authorityId;
  final String status; // 'routed', 'in_progress', 'resolved'
  final DateTime routedAt;
  final DateTime? resolvedAt;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relations (optionnelles)
  final AuthorityModel? authority;

  ReportRoutingModel({
    required this.id,
    required this.reportId,
    required this.authorityId,
    required this.status,
    required this.routedAt,
    this.resolvedAt,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.authority,
  });

  factory ReportRoutingModel.fromJson(Map<String, dynamic> json) {
    return ReportRoutingModel(
      id: json['id'] as int,
      reportId: json['report_id'] as int,
      authorityId: json['authority_id'] as int,
      status: json['status'] as String,
      routedAt: DateTime.parse(json['routed_at']),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      authority: json['authority'] != null
          ? AuthorityModel.fromJson(json['authority'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_id': reportId,
      'authority_id': authorityId,
      'status': status,
      'routed_at': routedAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isPending => status == 'routed';
  bool get isInProgress => status == 'in_progress';
  bool get isResolved => status == 'resolved';

  String get statusLabel {
    switch (status) {
      case 'routed':
        return 'Routé';
      case 'in_progress':
        return 'En cours';
      case 'resolved':
        return 'Résolu';
      default:
        return status;
    }
  }

  int? get durationInHours {
    if (resolvedAt != null) {
      return resolvedAt!.difference(routedAt).inHours;
    }
    return DateTime.now().difference(routedAt).inHours;
  }

  ReportRoutingModel copyWith({
    int? id,
    int? reportId,
    int? authorityId,
    String? status,
    DateTime? routedAt,
    DateTime? resolvedAt,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
    AuthorityModel? authority,
  }) {
    return ReportRoutingModel(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      authorityId: authorityId ?? this.authorityId,
      status: status ?? this.status,
      routedAt: routedAt ?? this.routedAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      authority: authority ?? this.authority,
    );
  }

  @override
  String toString() {
    return 'ReportRoutingModel(id: $id, status: $status)';
  }
}