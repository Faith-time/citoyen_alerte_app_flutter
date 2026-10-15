import 'package:citoyen_alerte_app_backup/data/models/category_model.dart';

class AuthorityModel {
  final int id;
  final String name;
  final String type;
  final String? description;
  final String? website;
  final String? email;
  final String? phone;
  final bool isActive;
  final List<CategoryModel> categories;
  final Map<String, int>? stats;
  final DateTime? createdAt;

  const AuthorityModel({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.website,
    this.email,
    this.phone,
    required this.isActive,
    this.categories = const [],
    this.stats,
    this.createdAt,
  });

  factory AuthorityModel.fromJson(Map<String, dynamic> json) {
    return AuthorityModel(
      id: json['id'] as int,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'government',
      description: json['description'] as String?,
      website: json['website'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      isActive: json['is_active'] == true || json['is_active'] == 1,
      categories: (json['categories'] as List?)
          ?.map((c) => CategoryModel.fromJson(c as Map<String, dynamic>))
          .toList() ??
          [],
      stats: json['stats'] != null
          ? Map<String, int>.from(
        (json['stats'] as Map<String, dynamic>).map(
              (k, v) => MapEntry(k, (v as num).toInt()),
        ),
      )
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'description': description,
    'website': website,
    'email': email,
    'phone': phone,
    'is_active': isActive,
  };

  String get typeLabel => switch (type) {
    'government' => 'Gouvernement',
    'municipality' => 'Mairie',
    'company' => 'Entreprise',
    'ngo' => 'ONG',
    _ => type,
  };

  int get pendingCount => stats?['pending'] ?? 0;
  int get inProgressCount => stats?['in_progress'] ?? 0;
  int get resolvedCount => stats?['resolved'] ?? 0;
}