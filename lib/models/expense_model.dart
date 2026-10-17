import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final String description;
  final double amount;
  final String category;
  final Map<String, double> payments; // uid -> monto pagado
  final Map<String, String> payerNames; // uid -> nombre (denormalizado)
  final Map<String, double> participantShares; // uid -> monto que le corresponde pagar
  final String splitMode; // 'equal' | 'percentage' | 'custom'
  final List<String> settledParticipantIds; // ya confirmados como pagados
  final List<String> pendingSettlementIds; // avisaron que pagaron, falta confirmar
  final DateTime date;
  final DateTime createdAt;
  final DateTime? lastEditedAt;

  ExpenseModel({
    required this.id,
    required this.description,
    required this.amount,
    required this.category,
    required this.payments,
    required this.payerNames,
    required this.participantShares,
    required this.splitMode,
    required this.settledParticipantIds,
    required this.pendingSettlementIds,
    required this.date,
    required this.createdAt,
    this.lastEditedAt,
  });

  List<String> get participantIds => participantShares.keys.toList();
  List<String> get payerIds => payments.keys.toList();

  String get payersSummary {
    final names = payerIds.map((id) => payerNames[id] ?? 'Alguien').toList();
    if (names.isEmpty) return '—';
    if (names.length == 1) return names.first;
    if (names.length == 2) return '${names[0]} y ${names[1]}';
    return '${names[0]} y ${names.length - 1} más';
  }

  /// Un participante ya está "resuelto" para este gasto si pagó lo
  /// suficiente por sí mismo (fue pagador y cubrió su propia cuota) o
  /// si un pagador confirmó que recibió su pago.
  bool isParticipantSettled(String uid) {
    final ownShare = participantShares[uid] ?? 0;
    final ownPayment = payments[uid] ?? 0;
    if (ownPayment >= ownShare - 0.5) return true;
    return settledParticipantIds.contains(uid);
  }

  /// true si ya no queda ninguna deuda pendiente asociada a este gasto
  /// específico (todos los participantes están resueltos). Solo en
  /// ese caso se puede eliminar el gasto sin necesidad de consenso.
  bool get isFullySettled =>
      participantShares.keys.every((uid) => isParticipantSettled(uid));

  factory ExpenseModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ExpenseModel(
      id: doc.id,
      description: data['description'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      category: data['category'] ?? 'Otros',
      payments: Map<String, double>.from(
        (data['payments'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      payerNames: Map<String, String>.from(data['payerNames'] ?? {}),
      participantShares: Map<String, double>.from(
        (data['participantShares'] ?? {}).map((k, v) => MapEntry(k, (v as num).toDouble())),
      ),
      splitMode: data['splitMode'] ?? 'equal',
      settledParticipantIds: List<String>.from(data['settledParticipantIds'] ?? []),
      pendingSettlementIds: List<String>.from(data['pendingSettlementIds'] ?? []),
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastEditedAt: (data['lastEditedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'description': description,
      'amount': amount,
      'category': category,
      'payments': payments,
      'payerNames': payerNames,
      'participantShares': participantShares,
      'splitMode': splitMode,
      'settledParticipantIds': settledParticipantIds,
      'pendingSettlementIds': pendingSettlementIds,
      'date': Timestamp.fromDate(date),
      'createdAt': Timestamp.fromDate(createdAt),
      if (lastEditedAt != null) 'lastEditedAt': Timestamp.fromDate(lastEditedAt!),
    };
  }
}
