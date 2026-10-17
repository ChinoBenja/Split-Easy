import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/group_model.dart';
import '../../models/history_entry_model.dart';
import '../../services/firestore_service.dart';

class HistoryScreen extends StatelessWidget {
  final GroupModel group;
  const HistoryScreen({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final dateFormat = DateFormat('dd MMM yyyy · HH:mm', 'es');

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de cambios')),
      body: StreamBuilder<List<HistoryEntry>>(
        stream: firestoreService.watchHistory(group.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return Center(
              child: Text('Todavía no hay movimientos registrados.',
                  style: TextStyle(color: Colors.grey.shade600)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              final config = _configFor(entry.action);
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: config.color.withValues(alpha: 0.15),
                    child: Icon(config.icon, color: config.color, size: 20),
                  ),
                  title: Text('${entry.performedByName} ${config.verb} "${entry.expenseDescription}"'),
                  subtitle: Text(
                    entry.details != null
                        ? '${entry.details}\n${dateFormat.format(entry.createdAt)}'
                        : dateFormat.format(entry.createdAt),
                  ),
                  isThreeLine: entry.details != null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  _HistoryConfig _configFor(String action) {
    switch (action) {
      case 'created':
        return _HistoryConfig(Icons.add_circle_outline, Colors.green, 'creó');
      case 'edit_proposed':
        return _HistoryConfig(Icons.edit_note, Colors.blue, 'propuso editar');
      case 'edit_approved':
        return _HistoryConfig(Icons.check_circle_outline, Colors.green, 'editó (aprobado)');
      case 'edit_rejected':
        return _HistoryConfig(Icons.cancel_outlined, Colors.red, 'intentó editar (rechazado)');
      case 'delete_proposed':
        return _HistoryConfig(Icons.delete_outline, Colors.orange, 'propuso eliminar');
      case 'delete_approved':
        return _HistoryConfig(Icons.delete_forever_outlined, Colors.red, 'eliminó (aprobado)');
      case 'delete_rejected':
        return _HistoryConfig(Icons.cancel_outlined, Colors.red, 'intentó eliminar (rechazado)');
      case 'deleted_free':
        return _HistoryConfig(Icons.delete_outline, Colors.grey, 'eliminó');
      case 'settlement_requested':
        return _HistoryConfig(Icons.payments_outlined, Colors.blue, 'avisó pago en');
      case 'settlement_confirmed':
        return _HistoryConfig(Icons.check_circle_outline, Colors.green, 'confirmó pago en');
      default:
        return _HistoryConfig(Icons.circle_outlined, Colors.grey, 'modificó');
    }
  }
}

class _HistoryConfig {
  final IconData icon;
  final Color color;
  final String verb;
  _HistoryConfig(this.icon, this.color, this.verb);
}
