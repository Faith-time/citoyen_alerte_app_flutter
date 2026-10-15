// lib/data/models/category_model.dart

class CategoryModel {
  final int id;
  final String name;
  final String? description;
  final int? parentId;
  final String? icon;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relations (optionnelles)
  final CategoryModel? parent;
  final List<CategoryModel>? children;

  CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.parentId,
    this.icon,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.parent,
    this.children,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      parentId: json['parent_id'] as int?,
      icon: json['icon'] as String?,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      parent: json['parent'] != null
          ? CategoryModel.fromJson(json['parent'])
          : null,
      children: json['children'] != null
          ? (json['children'] as List)
          .map((child) => CategoryModel.fromJson(child))
          .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'parent_id': parentId,
      'icon': icon,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper methods
  bool get isParent => parentId == null;
  bool get hasChildren => children != null && children!.isNotEmpty;

  String get fullName {
    if (parent != null) {
      return '${parent!.name} > $name';
    }
    return name;
  }

  CategoryModel copyWith({
    int? id,
    String? name,
    String? description,
    int? parentId,
    String? icon,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    CategoryModel? parent,
    List<CategoryModel>? children,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      parentId: parentId ?? this.parentId,
      icon: icon ?? this.icon,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parent: parent ?? this.parent,
      children: children ?? this.children,
    );
  }

  @override
  String toString() {
    return 'CategoryModel(id: $id, name: $name, isActive: $isActive)';
  }
}