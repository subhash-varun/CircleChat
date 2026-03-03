import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final String customerId;
  final String? assignedTo;
  final String status; // "open"
  final String lastMessage;
  final DateTime lastMessageAt;
  final String type; // "general" | "order" | "delivery"
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.customerId,
    this.assignedTo,
    required this.status,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      customerId: data['customer_id'] ?? '',
      assignedTo: data['assigned_to'],
      status: data['status'] ?? 'open',
      lastMessage: data['last_message'] ?? '',
      lastMessageAt: (data['last_message_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: data['type'] ?? 'general',
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customer_id': customerId,
      'assigned_to': assignedTo,
      'status': status,
      'last_message': lastMessage,
      'last_message_at': FieldValue.serverTimestamp(),
      'type': type,
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };
  }
}
