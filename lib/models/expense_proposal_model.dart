import 'package:cloud_firestore/cloud_firestore.dart';

/// Representa una propuesta de edición sobre un gasto existente.
/// El cambio NO se aplica de inmediato: queda "pendiente" hasta que
/// TODOS los integrantes del grupo la acepten. Si alguno la rechaza,
/// queda descartada. Esto asegura que un cambio de monto/pagadores
/// se haga "a conciencia de todos", como pediste.
class ExpenseProposal {
  final String id;
  final String expenseId;
  final String proposedBy;
  final String proposedByName;
  final DateTime createdAt;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String type; // 'edit' | 'delete'
  final Map<String, dynamic> oldValues; // snapshot previo (para mostrar el diff)
  final Map<String, dynamic> newValues; // solo los campos que cambian (vacío si es 'delete')
  final Map<String, String> responses; // uid -> 'accepted' | 'rejected'

  ExpenseProposal({
    required this.id,
    required this.expenseId,
    required this.proposedBy,
    required this.proposedByName,
    required this.createdAt,
    required this.status,
    this.type = 'edit',
    required this.oldValues,
    required this.newValues,
    required this.responses,
  });

  /// true si el uid dado ya respondió (aceptó o rechazó)
  bool hasResponded(String uid) => responses.containsKey(uid);

  /// Miembros que faltan por responder, dado el listado completo del grupo
  List<String> pendingMembers(List<String> allMemberIds) =>
      allMemberIds.where((id) => !responses.containsKey(id)).toList();

  factory ExpenseProposal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseProposal(
      id: doc.id,
      expenseId: data['expenseId'] ?? '',
      proposedBy: data['proposedBy'] ?? '',
      proposedByName: data['proposedByName'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] ?? 'pending',
      type: data['type'] ?? 'edit',
      oldValues: Map<String, dynamic>.from(data['oldValues'] ?? {}),
      newValues: Map<String, dynamic>.from(data['newValues'] ?? {}),
      responses: Map<String, String>.from(data['responses'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'expenseId': expenseId,
      'proposedBy': proposedBy,
      'proposedByName': proposedByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'type': type,
      'oldValues': oldValues,
      'newValues': newValues,
      'responses': responses,
    };
  }
}
