import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de mensaje en el chat grupal:
/// - text: mensaje normal
/// - proposal: tarjeta de propuesta de edición/eliminación de un gasto
/// - settlement_request: aviso de "ya pagué mi cuota"
/// - system: aviso automático del sistema
class ChatMessage {
  final String id;
  final String type;
  final String senderId;
  final String senderName;
  final String? text;
  final String? expenseId;
  final String? expenseDescription;
  final String? proposalId;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.type,
    required this.senderId,
    required this.senderName,
    this.text,
    this.expenseId,
    this.expenseDescription,
    this.proposalId,
    required this.createdAt,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      type: data['type'] ?? 'text',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      text: data['text'],
      expenseId: data['expenseId'],
      expenseDescription: data['expenseDescription'],
      proposalId: data['proposalId'],
      createdAt:
          (data['timestamp'] as Timestamp?)?.toDate() ??
          (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }
}
