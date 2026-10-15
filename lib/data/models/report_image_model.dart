import 'package:citoyen_alerte_app_backup/data/models/user_model.dart';

class ReportImageModel {
  final int id;
  final int reportId;
  final String imagePath;
  final String type; // 'initial', 'before', 'after', 'evidence'
  final int uploadedBy;
  final int? fileSize;
  final String? mimeType;
  final bool isValidated;
  final double? aiConfidenceScore;
  final Map<String, dynamic>? aiFlags;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relations (optionnelles)
  final UserModel? uploader;

  ReportImageModel({
    required this.id,
    required this.reportId,
    required this.imagePath,
    required this.type,
    required this.uploadedBy,
    this.fileSize,
    this.mimeType,
    required this.isValidated,
    this.aiConfidenceScore,
    this.aiFlags,
    required this.createdAt,
    required this.updatedAt,
    this.uploader,
  });

  factory ReportImageModel.fromJson(Map<String, dynamic> json) {
    return ReportImageModel(
      id: json['id'] as int,
      reportId: json['report_id'] as int,
      imagePath: json['image_path'] as String,
      type: json['type'] as String,
      uploadedBy: json['uploaded_by'] as int,
      fileSize: json['file_size'] as int?,
      mimeType: json['mime_type'] as String?,
      isValidated: json['is_validated'] == 1 || json['is_validated'] == true,
      aiConfidenceScore: json['ai_confidence_score'] != null
          ? double.parse(json['ai_confidence_score'].toString())
          : null,
      aiFlags: json['ai_flags'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      uploader: json['uploader'] != null
          ? UserModel.fromJson(json['uploader'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_id': reportId,
      'image_path': imagePath,
      'type': type,
      'uploaded_by': uploadedBy,
      'file_size': fileSize,
      'mime_type': mimeType,
      'is_validated': isValidated,
      'ai_confidence_score': aiConfidenceScore,
      'ai_flags': aiFlags,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper methods
  bool get isInitial => type == 'initial';
  bool get isBefore => type == 'before';
  bool get isAfter => type == 'after';
  bool get isEvidence => type == 'evidence';

  String get url {
    // TODO: Remplacer par votre URL d'API
    return 'https://api.example.com/storage/$imagePath';
  }

  String get fileSizeFormatted {
    if (fileSize == null) return 'Unknown';

    final bytes = fileSize!;
    if (bytes >= 1073741824) {
      return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
    } else if (bytes >= 1048576) {
      return '${(bytes / 1048576).toStringAsFixed(2)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    }
    return '$bytes bytes';
  }

  ReportImageModel copyWith({
    int? id,
    int? reportId,
    String? imagePath,
    String? type,
    int? uploadedBy,
    int? fileSize,
    String? mimeType,
    bool? isValidated,
    double? aiConfidenceScore,
    Map<String, dynamic>? aiFlags,
    DateTime? createdAt,
    DateTime? updatedAt,
    UserModel? uploader,
  }) {
    return ReportImageModel(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      imagePath: imagePath ?? this.imagePath,
      type: type ?? this.type,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      fileSize: fileSize ?? this.fileSize,
      mimeType: mimeType ?? this.mimeType,
      isValidated: isValidated ?? this.isValidated,
      aiConfidenceScore: aiConfidenceScore ?? this.aiConfidenceScore,
      aiFlags: aiFlags ?? this.aiFlags,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      uploader: uploader ?? this.uploader,
    );
  }

  @override
  String toString() {
    return 'ReportImageModel(id: $id, type: $type, validated: $isValidated)';
  }
}

