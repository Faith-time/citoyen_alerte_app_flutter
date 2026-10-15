// lib/data/models/report_model.dart

import 'package:citoyen_alerte_app_backup/data/models/report_image_model.dart';
import 'package:citoyen_alerte_app_backup/data/models/report_routing_model.dart';
import 'category_model.dart';
import 'package:citoyen_alerte_app_backup/data/models/user_model.dart';
import 'chat_message_model.dart';

class ReportModel {
  final int id;
  final int citizenId;
  final int categoryId;
  final String reference;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final String address;
  final String communeName;
  final String regionName;
  final String severity;
  final String status;
  final bool isAnonymous;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relations (optionnelles)
  final UserModel? citizen;
  final CategoryModel? category;
  final List<ReportImageModel>? images;
  final List<ReportRoutingModel>? routings;

  ReportModel({
    required this.id,
    required this.citizenId,
    required this.categoryId,
    required this.reference,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.communeName,
    required this.regionName,
    required this.severity,
    required this.status,
    required this.isAnonymous,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
    this.citizen,
    this.category,
    this.images,
    this.routings,
  });

  /// Parse défensif : fonctionne aussi avec les objets partiels
  /// renvoyés par les endpoints dashboard (recent_assignments, etc.)
  /// qui n'incluent pas tous les champs du modèle complet.
  factory ReportModel.fromJson(Map<String, dynamic> json) {
    // ── Champs numériques ───────────────────────────────────────────────
    final id         = (json['id']          as num?)?.toInt() ?? 0;
    final citizenId  = (json['citizen_id']  as num?)?.toInt() ?? 0;
    final categoryId = (json['category_id'] as num?)?.toInt() ?? 0;

    // ── Champs texte ────────────────────────────────────────────────────
    final reference  = (json['reference']   as String?) ?? '';
    final title      = (json['title']       as String?) ?? '';
    final description= (json['description'] as String?) ?? '';
    final address    = (json['address']     as String?) ?? '';
    final communeName= (json['commune_name']as String?) ?? '';
    final regionName = (json['region_name'] as String?) ?? '';
    final severity   = (json['severity']    as String?) ?? 'low';
    final status     = (json['status']      as String?) ?? 'pending';

    // ── Coordonnées ─────────────────────────────────────────────────────
    double latitude  = 0.0;
    double longitude = 0.0;
    try { latitude  = double.parse(json['latitude'].toString()); } catch (_) {}
    try { longitude = double.parse(json['longitude'].toString()); } catch (_) {}

    // ── Booléen ─────────────────────────────────────────────────────────
    final isAnonymous =
        json['is_anonymous'] == 1 || json['is_anonymous'] == true;

    // ── Dates ───────────────────────────────────────────────────────────
    DateTime? resolvedAt;
    try {
      if (json['resolved_at'] != null) {
        resolvedAt = DateTime.parse(json['resolved_at'] as String);
      }
    } catch (_) {}

    DateTime createdAt = DateTime.now();
    try {
      if (json['created_at'] != null) {
        createdAt = DateTime.parse(json['created_at'] as String);
      }
    } catch (_) {}

    DateTime updatedAt = DateTime.now();
    try {
      if (json['updated_at'] != null) {
        updatedAt = DateTime.parse(json['updated_at'] as String);
      }
    } catch (_) {}

    // ── Relations optionnelles ──────────────────────────────────────────
    UserModel? citizen;
    try {
      if (json['citizen'] != null) {
        citizen = UserModel.fromJson(json['citizen'] as Map<String, dynamic>);
      }
    } catch (_) {}

    CategoryModel? category;
    try {
      if (json['category'] != null) {
        category = CategoryModel.fromJson(
            json['category'] as Map<String, dynamic>);
      }
    } catch (_) {}

    List<ReportImageModel>? images;
    try {
      if (json['images'] != null) {
        images = (json['images'] as List)
            .map((img) => ReportImageModel.fromJson(img))
            .toList();
      }
    } catch (_) {}

    List<ReportRoutingModel>? routings;
    try {
      if (json['routings'] != null) {
        routings = (json['routings'] as List)
            .map((r) => ReportRoutingModel.fromJson(r))
            .toList();
      }
    } catch (_) {}

    return ReportModel(
      id: id,
      citizenId: citizenId,
      categoryId: categoryId,
      reference: reference,
      title: title,
      description: description,
      latitude: latitude,
      longitude: longitude,
      address: address,
      communeName: communeName,
      regionName: regionName,
      severity: severity,
      status: status,
      isAnonymous: isAnonymous,
      resolvedAt: resolvedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
      citizen: citizen,
      category: category,
      images: images,
      routings: routings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'citizen_id': citizenId,
      'category_id': categoryId,
      'reference': reference,
      'title': title,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'commune_name': communeName,
      'region_name': regionName,
      'severity': severity,
      'status': status,
      'is_anonymous': isAnonymous,
      'resolved_at': resolvedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isPending    => status == 'pending';
  bool get isRouted     => status == 'routed';
  bool get isInProgress => status == 'in_progress';
  bool get isResolved   => status == 'resolved';
  bool get isUrgent     => severity == 'high';

  String get statusLabel => switch (status) {
    'pending'     => 'En attente',
    'routed'      => 'Routé',
    'in_progress' => 'En cours',
    'resolved'    => 'Résolu',
    _             => status,
  };

  String get severityLabel => switch (severity) {
    'low'    => 'Faible',
    'medium' => 'Moyen',
    'high'   => 'Élevé',
    _        => severity,
  };

  Map<String, dynamic> get location => {
    'latitude':  latitude,
    'longitude': longitude,
    'address':   address,
    'commune':   communeName,
    'region':    regionName,
  };

  ReportModel copyWith({
    int? id,
    int? citizenId,
    int? categoryId,
    String? reference,
    String? title,
    String? description,
    double? latitude,
    double? longitude,
    String? address,
    String? communeName,
    String? regionName,
    String? severity,
    String? status,
    bool? isAnonymous,
    DateTime? resolvedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserModel? citizen,
    CategoryModel? category,
    List<ReportImageModel>? images,
    List<ReportRoutingModel>? routings,
  }) {
    return ReportModel(
      id:           id           ?? this.id,
      citizenId:    citizenId    ?? this.citizenId,
      categoryId:   categoryId   ?? this.categoryId,
      reference:    reference    ?? this.reference,
      title:        title        ?? this.title,
      description:  description  ?? this.description,
      latitude:     latitude     ?? this.latitude,
      longitude:    longitude    ?? this.longitude,
      address:      address      ?? this.address,
      communeName:  communeName  ?? this.communeName,
      regionName:   regionName   ?? this.regionName,
      severity:     severity     ?? this.severity,
      status:       status       ?? this.status,
      isAnonymous:  isAnonymous  ?? this.isAnonymous,
      resolvedAt:   resolvedAt   ?? this.resolvedAt,
      createdAt:    createdAt    ?? this.createdAt,
      updatedAt:    updatedAt    ?? this.updatedAt,
      citizen:      citizen      ?? this.citizen,
      category:     category     ?? this.category,
      images:       images       ?? this.images,
      routings:     routings     ?? this.routings,
    );
  }

  @override
  String toString() =>
      'ReportModel(id: $id, reference: $reference, title: $title, status: $status)';
}