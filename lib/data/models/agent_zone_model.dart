// lib/data/models/agent_zone_model.dart

import 'package:citoyen_alerte_app_backup/data/models/authority_model.dart';
import 'package:citoyen_alerte_app_backup/data/models/user_model.dart';

class AgentZoneModel {
  final int id;
  final int agentId;
  final int? authorityId;
  final int? communeId;
  final String? communeName;
  final String? regionName;
  final double radiusKm;
  final double? centerLat;
  final double? centerLng;
  final bool isPrimary;
  final UserModel? agent;
  final AuthorityModel? authority;

  const AgentZoneModel({
    required this.id,
    required this.agentId,
    this.authorityId,
    this.communeId,
    this.communeName,
    this.regionName,
    this.radiusKm = 5.0,
    this.centerLat,
    this.centerLng,
    required this.isPrimary,
    this.agent,
    this.authority,
  });

  factory AgentZoneModel.fromJson(Map<String, dynamic> json) {
    return AgentZoneModel(
      id: json['id'] as int,
      agentId: json['agent_id'] as int,
      authorityId: json['authority_id'] as int?,
      communeId: json['commune_id'] as int?,
      communeName: json['commune_name'] as String?,
      regionName: json['region_name'] as String?,
      radiusKm: (json['radius_km'] as num?)?.toDouble() ?? 5.0,
      centerLat: (json['center_lat'] as num?)?.toDouble(),
      centerLng: (json['center_lng'] as num?)?.toDouble(),
      isPrimary: json['is_primary'] == true || json['is_primary'] == 1,
      agent: json['agent'] != null
          ? UserModel.fromJson(json['agent'] as Map<String, dynamic>)
          : null,
      authority: json['authority'] != null
          ? AuthorityModel.fromJson(json['authority'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'agent_id': agentId,
    'authority_id': authorityId,
    'commune_id': communeId,
    'commune_name': communeName,
    'region_name': regionName,
    'radius_km': radiusKm,
    'center_lat': centerLat,
    'center_lng': centerLng,
    'is_primary': isPrimary,
  };

  bool get hasGpsCenter => centerLat != null && centerLng != null;

  String get zoneLabel {
    if (communeName != null && regionName != null) {
      return '$communeName, $regionName';
    }
    return communeName ?? regionName ?? 'Zone non définie';
  }
}