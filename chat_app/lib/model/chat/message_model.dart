import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String senderType; // "customer" | "agent" | "system"
  final String senderRef; // optional actual sender identifier
  final String clientMessageId; // client-generated id for optimistic dedupe
  final String text;
  final List<String> attachments; // URLs from Firebase Storage
  final DateTime createdAt;
  final String customerRef; // mandatory

  Message({
    required this.id,
    required this.senderType,
    required this.senderRef,
    required this.clientMessageId,
    required this.text,
    required this.attachments,
    required this.createdAt,
    required this.customerRef,
  });

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Message(
      id: doc.id,
      senderType: data['sender_type'] ?? 'customer',
      senderRef: (data['sender_ref'] ?? '').toString(),
      clientMessageId: (data['client_message_id'] ?? '').toString(),
      text: data['text'] ?? '',
      attachments: List<String>.from(data['attachments'] ?? []),
      createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
      customerRef: data['customer_ref'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender_type': senderType,
      'sender_ref': senderRef,
      'client_message_id': clientMessageId,
      'text': text,
      'attachments': attachments,
      'created_at': FieldValue.serverTimestamp(),
      'customer_ref': customerRef,
    };
  }
}
