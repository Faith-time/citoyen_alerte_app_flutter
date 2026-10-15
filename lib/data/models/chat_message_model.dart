// lib/data/models/chat_message_model.dart

import 'package:citoyen_alerte_app_backup/data/models/user_model.dart'; // ← AJOUTER

class ChatMessageModel {
  final int id;
  final int reportId;
  final int senderId;
  final int receiverId;
  final String message;
  final String? attachmentPath;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  final UserModel? sender;
  final UserModel? receiver;

  ChatMessageModel({
    required this.id,
    required this.reportId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.attachmentPath,
    required this.isRead,
    this.readAt,
    required this.createdAt,
    this.sender,
    this.receiver,
  });

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    return ChatMessageModel(
      id: json['id'] as int,
      reportId: json['report_id'] as int,
      senderId: json['sender_id'] as int,
      receiverId: json['receiver_id'] as int,
      message: json['message'] as String,
      attachmentPath: json['attachment_path'] as String?,
      isRead: json['is_read'] == 1 || json['is_read'] == true,
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      sender: json['sender'] != null
          ? UserModel.fromJson(json['sender'])
          : null,
      receiver: json['receiver'] != null
          ? UserModel.fromJson(json['receiver'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'report_id': reportId,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'message': message,
      'attachment_path': attachmentPath,
      'is_read': isRead,
      'read_at': readAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get hasAttachment => attachmentPath != null;

  String? get attachmentUrl {
    if (attachmentPath == null) return null;
    return 'https://api.example.com/storage/$attachmentPath';
  }

  ChatMessageModel copyWith({
    int? id,
    int? reportId,
    int? senderId,
    int? receiverId,
    String? message,
    String? attachmentPath,
    bool? isRead,
    DateTime? readAt,
    DateTime? createdAt,
    UserModel? sender,
    UserModel? receiver,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      reportId: reportId ?? this.reportId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      message: message ?? this.message,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      sender: sender ?? this.sender,
      receiver: receiver ?? this.receiver,
    );
  }

  @override
  String toString() {
    return 'ChatMessageModel(id: $id, isRead: $isRead)';
  }
}
