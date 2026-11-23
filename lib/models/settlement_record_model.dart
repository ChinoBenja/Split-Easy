import 'package:cloud_firestore/cloud_firestore.dart';

class SettlementRecord {
  const SettlementRecord({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    required this.amount,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    required this.hasReceipt,
    this.expenseId,
    this.note,
  });

  final String id;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String toName;
  final double amount;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final bool hasReceipt;
  final String? expenseId;
  final String? note;

  factory SettlementRecord.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    final data = rawData is Map ? rawData : const <Object?, Object?>{};
    final amount = data['amount'];
    final createdAt = data['createdAt'];
    return SettlementRecord(
      id: doc.id,
      fromUid: _stringValue(data['fromUid']),
      fromName: _stringValue(data['fromName'], fallback: 'Integrante'),
      toUid: _stringValue(data['toUid']),
      toName: _stringValue(data['toName'], fallback: 'Integrante'),
      amount: _numberValue(amount),
      createdBy: _stringValue(data['createdBy']),
      createdByName: _stringValue(
        data['createdByName'],
        fallback: 'Integrante',
      ),
      createdAt: createdAt is Timestamp ? createdAt.toDate() : DateTime.now(),
      hasReceipt: data['hasReceipt'] == true,
      expenseId: _optionalString(data['expenseId']),
      note: _optionalString(data['note']),
    );
  }

  static String _stringValue(Object? value, {String fallback = ''}) =>
      value is String ? value : fallback;

  static double _numberValue(Object? value) {
    if (value is! num) return 0;
    final number = value.toDouble();
    return number.isFinite ? number : 0;
  }

  static String? _optionalString(Object? value) =>
      value is String ? value : null;
}

class SettlementReceipt {
  const SettlementReceipt({
    required this.imageBase64,
    required this.imageContentType,
  });

  final String imageBase64;
  final String imageContentType;

  factory SettlementReceipt.fromFirestore(DocumentSnapshot doc) {
    final rawData = doc.data();
    final data = rawData is Map ? rawData : const <Object?, Object?>{};
    final imageBase64 = data['imageBase64'];
    final imageContentType = data['imageContentType'];
    return SettlementReceipt(
      imageBase64: imageBase64 is String ? imageBase64 : '',
      imageContentType: imageContentType is String
          ? imageContentType
          : 'image/jpeg',
    );
  }
}
