// lib/data/models/user_model.dart

class UserModel {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role; // 'citizen', 'agent', 'admin'
  final String? avatar;
  final DateTime? emailVerifiedAt;
  final DateTime? phoneVerifiedAt;
  final bool isVerified;
  final bool isActive;
  final bool isBanned;
  final String? banReason;
  final DateTime? bannedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    this.avatar,
    this.emailVerifiedAt,
    this.phoneVerifiedAt,
    required this.isVerified,
    required this.isActive,
    required this.isBanned,
    this.banReason,
    this.bannedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  // Factory constructor from JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      avatar: json['avatar'] as String?,
      emailVerifiedAt: json['email_verified_at'] != null
          ? DateTime.parse(json['email_verified_at'])
          : null,
      phoneVerifiedAt: json['phone_verified_at'] != null
          ? DateTime.parse(json['phone_verified_at'])
          : null,
      isVerified: json['is_verified'] == 1 || json['is_verified'] == true,
      isActive: json['is_active'] == 1 || json['is_active'] == true,
      isBanned: json['is_banned'] == 1 || json['is_banned'] == true,
      banReason: json['ban_reason'] as String?,
      bannedAt: json['banned_at'] != null
          ? DateTime.parse(json['banned_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'avatar': avatar,
      'email_verified_at': emailVerifiedAt?.toIso8601String(),
      'phone_verified_at': phoneVerifiedAt?.toIso8601String(),
      'is_verified': isVerified,
      'is_active': isActive,
      'is_banned': isBanned,
      'ban_reason': banReason,
      'banned_at': bannedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper methods (like Eloquent helpers)
  bool get isCitizen => role == 'citizen';
  bool get isAgent => role == 'agent';
  bool get isAdmin => role == 'admin';
  bool get canReport => isActive && !isBanned && isVerified;

  String? get avatarUrl {
    if (avatar == null) return null;
    // TODO: Remplacer par votre URL d'API
    return 'https://api.example.com/storage/$avatar';
  }

  // CopyWith method for immutability
  UserModel copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? avatar,
    DateTime? emailVerifiedAt,
    DateTime? phoneVerifiedAt,
    bool? isVerified,
    bool? isActive,
    bool? isBanned,
    String? banReason,
    DateTime? bannedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      avatar: avatar ?? this.avatar,
      emailVerifiedAt: emailVerifiedAt ?? this.emailVerifiedAt,
      phoneVerifiedAt: phoneVerifiedAt ?? this.phoneVerifiedAt,
      isVerified: isVerified ?? this.isVerified,
      isActive: isActive ?? this.isActive,
      isBanned: isBanned ?? this.isBanned,
      banReason: banReason ?? this.banReason,
      bannedAt: bannedAt ?? this.bannedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, name: $name, email: $email, role: $role)';
  }
}