/// Representa el balance neto de un miembro dentro de un grupo.
/// balance > 0  -> le deben plata (pagó de más)
/// balance < 0  -> debe plata (pagó de menos)
class MemberBalance {
  final String uid;
  final String name;
  final double totalPaid;
  final double totalOwed;
  double get balance => totalPaid - totalOwed;

  MemberBalance({
    required this.uid,
    required this.name,
    required this.totalPaid,
    required this.totalOwed,
  });
}

/// Representa una transacción de saldo simplificada: "A le debe X a B"
class SettlementTransaction {
  final String fromUid;
  final String fromName;
  final String toUid;
  final String toName;
  final double amount;

  SettlementTransaction({
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    required this.amount,
  });
}
