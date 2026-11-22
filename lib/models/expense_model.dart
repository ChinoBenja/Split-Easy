import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final String description;
  final double amount;
  final String category;
  final Map<String, double> payments; // uid -> monto pagado
  final Map<String, String> payerNames; // uid -> nombre (denormalizado)
  final Map<String, double>
  participantShares; // uid -> monto que le corresponde pagar
  final String splitMode; // 'equal' | 'percentage' | 'custom'
  final List<String> settledParticipantIds; // ya confirmados como pagados
  final List<String>
  pendingSettlementIds; // avisaron que pagaron, falta confirmar
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
    final rawData = doc.data();
    final data = rawData is Map ? rawData : const <Object?, Object?>{};
    return ExpenseModel(
      id: doc.id,
      description: _stringValue(data['description'], fallback: ''),
      amount: _numberValue(data['amount']),
      category: _stringValue(data['category'], fallback: 'Otros'),
      payments: _numberMap(data['payments']),
      payerNames: _stringMap(data['payerNames']),
      participantShares: _numberMap(data['participantShares']),
      splitMode: _stringValue(data['splitMode'], fallback: 'equal'),
      settledParticipantIds: _stringList(data['settledParticipantIds']),
      pendingSettlementIds: _stringList(data['pendingSettlementIds']),
      date: _dateValue(data['date']) ?? DateTime.now(),
      createdAt: _dateValue(data['createdAt']) ?? DateTime.now(),
      lastEditedAt: _dateValue(data['lastEditedAt']),
    );
  }

  static String _stringValue(Object? value, {required String fallback}) =>
      value is String ? value : fallback;

  static double _numberValue(Object? value) {
    if (value is! num) return 0;
    final number = value.toDouble();
    return number.isFinite ? number : 0;
  }

  static Map<String, double> _numberMap(Object? value) {
    if (value is! Map) return <String, double>{};
    return {
      for (final entry in value.entries)
        if (entry.key case final String key)
          if (entry.value case final num number) key: _numberValue(number),
    };
  }

  static Map<String, String> _stringMap(Object? value) {
    if (value is! Map) return <String, String>{};
    return {
      for (final entry in value.entries)
        if (entry.key case final String key)
          if (entry.value case final String item) key: item,
    };
  }

  static List<String> _stringList(Object? value) {
    if (value is! Iterable) return <String>[];
    return value.whereType<String>().toList();
  }

  static DateTime? _dateValue(Object? value) =>
      value is Timestamp ? value.toDate() : null;

  Map<String, dynamic> toMap() {
    final editedAt = lastEditedAt;
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
      if (editedAt != null) 'lastEditedAt': Timestamp.fromDate(editedAt),
    };
  }
}
