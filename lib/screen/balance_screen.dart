import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../models/balance_model.dart';
import '../../services/firestore_service.dart';

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
  final _currencyFormat =
      NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);

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
              const Text('Balance por integrante',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...balances.map((b) => _BalanceTile(
                    balance: b,
                    currencyFormat: _currencyFormat,
                  )),
              const SizedBox(height: 24),
              const Text('Liquidación sugerida',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                ...settlements.map((s) => Card(
                      child: ListTile(
                        leading: const Icon(Icons.arrow_forward),
                        title: Text('${s.fromName} → ${s.toName}'),
                        trailing: Text(
                          _currencyFormat.format(s.amount),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )),
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

  const _BalanceTile({required this.balance, required this.currencyFormat});

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

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text(
            balance.name.isNotEmpty ? balance.name[0].toUpperCase() : '?',
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(balance.name),
        subtitle: Text(
            'Pagó ${currencyFormat.format(balance.totalPaid)} · Le correspondía ${currencyFormat.format(balance.totalOwed)}'),
        trailing: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
