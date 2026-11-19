import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../models/balance_model.dart';
import '../../services/firestore_service.dart';
import '../widgets/person_avatar.dart';

/// Pantalla de balance del grupo (Requerimiento funcional:
/// "Calcular automáticamente cuánto debe cada persona del grupo")
class BalanceScreen extends StatefulWidget {
  final GroupModel group;
  const BalanceScreen({super.key, required this.group});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  final _firestoreService = FirestoreService();
  final _currencyFormat = NumberFormat.currency(
    locale: 'es_CL',
    symbol: '\$',
    decimalDigits: 0,
  );
  late final Future<Map<String, String>> _memberPhotoUrls;

  @override
  void initState() {
    super.initState();
    _memberPhotoUrls = _firestoreService.getUserPhotoUrls(
      widget.group.memberIds,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Balance del grupo')),
      body: StreamBuilder<List<ExpenseModel>>(
        stream: _firestoreService.watchGroupExpenses(widget.group.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final expenses = snapshot.data!;
          final balances = _firestoreService.calculateBalances(
            group: widget.group,
            expenses: expenses,
          );
          final settlements = _firestoreService.simplifyDebts(balances);

          if (expenses.isEmpty) {
            return Center(
              child: Text(
                'Aún no hay gastos para calcular el balance.',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Balance por integrante',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...balances.map(
                (b) => _BalanceTile(
                  balance: b,
                  currencyFormat: _currencyFormat,
                  memberPhotoUrls: _memberPhotoUrls,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Liquidación sugerida',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Con estas transacciones todos quedan a mano, con el mínimo de pagos posible.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              if (settlements.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('¡Todos están a mano! 🎉'),
                )
              else
                ...settlements.map(
                  (settlement) => FutureBuilder<Map<String, String>>(
                    future: _memberPhotoUrls,
                    builder: (context, snapshot) => Card(
                      child: ListTile(
                        minLeadingWidth: 62,
                        horizontalTitleGap: 8,
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PersonAvatar(
                              name: settlement.fromName,
                              photoSource: snapshot.data?[settlement.fromUid],
                              radius: 16,
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 6),
                              child: Icon(Icons.arrow_forward, size: 18),
                            ),
                            PersonAvatar(
                              name: settlement.toName,
                              photoSource: snapshot.data?[settlement.toUid],
                              radius: 16,
                            ),
                          ],
                        ),
                        title: Text(
                          '${settlement.fromName} → ${settlement.toName}',
                        ),
                        trailing: Text(
                          _currencyFormat.format(settlement.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _BalanceTile extends StatelessWidget {
  final MemberBalance balance;
  final NumberFormat currencyFormat;
  final Future<Map<String, String>> memberPhotoUrls;

  const _BalanceTile({
    required this.balance,
    required this.currencyFormat,
    required this.memberPhotoUrls,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = balance.balance > 0.01;
    final isNegative = balance.balance < -0.01;
    final color = isPositive
        ? Colors.green
        : isNegative
        ? Colors.red
        : Colors.grey;
    final label = isPositive
        ? 'Le deben ${currencyFormat.format(balance.balance)}'
        : isNegative
        ? 'Debe ${currencyFormat.format(-balance.balance)}'
        : 'Está a mano';

    return FutureBuilder<Map<String, String>>(
      future: memberPhotoUrls,
      builder: (context, snapshot) => Card(
        child: ListTile(
          leading: PersonAvatar(
            name: balance.name,
            photoSource: snapshot.data?[balance.uid],
            backgroundColor: color.withValues(alpha: 0.15),
            foregroundColor: color,
          ),
          title: Text(balance.name),
          subtitle: Text(
            'Pagó ${currencyFormat.format(balance.totalPaid)} · Le correspondía ${currencyFormat.format(balance.totalOwed)}',
          ),
          trailing: Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
