import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // 'payment', 'admission', 'seat', 'expiry', 'announcement', 'general'
  final bool read;
  final DateTime createdAt;
  final String targetRole; // 'admin', 'student', 'all'
  final String? targetUserId;
  final String? actionRoute;
  final Map<String, dynamic> metadata;

  const AppNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.read,
    required this.createdAt,
    required this.targetRole,
    this.targetUserId,
    this.actionRoute,
    this.metadata = const {},
  });

  factory AppNotificationModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    DateTime created;
    final rawDate = data['createdAt'];
    if (rawDate is Timestamp) {
      created = rawDate.toDate();
    } else if (rawDate is String) {
      created = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }

    return AppNotificationModel(
      id: doc.id,
      title: data['title'] as String? ?? 'Notice',
      body: data['body'] as String? ?? '',
      type: data['type'] as String? ?? 'general',
      read: data['read'] as bool? ?? false,
      createdAt: created,
      targetRole: data['targetRole'] as String? ?? 'all',
      targetUserId: data['targetUserId'] as String?,
      actionRoute: data['actionRoute'] as String?,
      metadata: (data['metadata'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'body': body,
      'type': type,
      'read': read,
      'createdAt': Timestamp.fromDate(createdAt),
      'targetRole': targetRole,
      'targetUserId': targetUserId,
      'actionRoute': actionRoute,
      'metadata': metadata,
    };
  }

  AppNotificationModel copyWith({
    String? id,
    String? title,
    String? body,
    String? type,
    bool? read,
    DateTime? createdAt,
    String? targetRole,
    String? targetUserId,
    String? actionRoute,
    Map<String, dynamic>? metadata,
  }) {
    return AppNotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      type: type ?? this.type,
      read: read ?? this.read,
      createdAt: createdAt ?? this.createdAt,
      targetRole: targetRole ?? this.targetRole,
      targetUserId: targetUserId ?? this.targetUserId,
      actionRoute: actionRoute ?? this.actionRoute,
      metadata: metadata ?? this.metadata,
    );
  }
}
