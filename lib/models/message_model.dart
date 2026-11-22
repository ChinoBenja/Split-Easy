import 'package:cloud_firestore/cloud_firestore.dart';

/// Tipos de mensaje en el chat grupal:
/// - text: mensaje normal
/// - proposal: tarjeta de propuesta de edición/eliminación de un gasto
/// - group_delete_proposal: votación para eliminar el grupo
/// - settlement_request: aviso de "ya pagué mi cuota"
/// - system: aviso automático del sistema
class ChatMessage {
  final String id;
  final String type;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String? text;
  final String? imageUrl;
  final String? imageBase64;
  final String? imageContentType;
  final String? expenseId;
  final String? expenseDescription;
  final String? proposalId;
  final DateTime createdAt;

  ChatMessage({
    required this.id,
    required this.type,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    this.text,
    this.imageUrl,
    this.imageBase64,
    this.imageContentType,
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
      senderPhotoUrl: data['senderPhotoUrl'] ?? data['photoUrl'],
      text: data['text'],
      imageUrl: data['imageUrl'] is String ? data['imageUrl'] as String : null,
      imageBase64: data['imageBase64'] is String
          ? data['imageBase64'] as String
          : null,
      imageContentType: data['imageContentType'] is String
          ? data['imageContentType'] as String
          : null,
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
