import 'package:cloud_firestore/cloud_firestore.dart';

/// Una entrada del historial de cambios del grupo: creación de gastos,
/// propuestas de edición/eliminación, aprobaciones, rechazos y
/// liquidaciones confirmadas. Persiste aunque el gasto original se
/// elimine, para mantener trazabilidad completa.
class HistoryEntry {
  final String id;
  final String expenseId;
  final String expenseDescription;
  final String action;
  // 'created' | 'edit_proposed' | 'edit_approved' | 'edit_rejected'
  // 'delete_proposed' | 'delete_approved' | 'delete_rejected'
  // 'deleted_free' | 'settlement_requested' | 'settlement_confirmed'
  // 'settlement_recorded'
  final String performedBy;
  final String performedByName;
  final String? details;
  final String? settlementId;
  final double? settlementAmount;
  final String? settlementFromName;
  final String? settlementToName;
  final bool hasSettlementReceipt;
  final DateTime createdAt;

  HistoryEntry({
    required this.id,
    required this.expenseId,
    required this.expenseDescription,
    required this.action,
    required this.performedBy,
    required this.performedByName,
    this.details,
    this.settlementId,
    this.settlementAmount,
    this.settlementFromName,
    this.settlementToName,
    this.hasSettlementReceipt = false,
    required this.createdAt,
  });

  factory HistoryEntry.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HistoryEntry(
      id: doc.id,
      expenseId: data['expenseId'] ?? '',
      expenseDescription: data['expenseDescription'] ?? '',
      action: data['action'] ?? '',
      performedBy: data['performedBy'] ?? '',
      performedByName: data['performedByName'] ?? '',
      details: data['details'],
      settlementId: data['settlementId'] as String?,
      settlementAmount: (data['settlementAmount'] as num?)?.toDouble(),
      settlementFromName: data['settlementFromName'] as String?,
      settlementToName: data['settlementToName'] as String?,
      hasSettlementReceipt: data['hasSettlementReceipt'] == true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
