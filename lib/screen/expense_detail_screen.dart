import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../services/firestore_service.dart';
import 'chat_screen.dart';
import 'edit_expense_screen.dart';

/// Detalle completo de un gasto y su balance individual por participante.
class ExpenseDetailScreen extends StatelessWidget {
  const ExpenseDetailScreen({
    super.key,
    required this.group,
    required this.expense,
  });

  final GroupModel group;
  final ExpenseModel expense;

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final currencyFormat = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMMM yyyy', 'es');
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return StreamBuilder<ExpenseModel?>(
      stream: firestoreService.watchExpense(group.id, expense.id),
      initialData: expense,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Detalle del gasto')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudo actualizar el detalle.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.error,
                  ),
                ),
              ),
            ),
          );
        }

        final current = snapshot.data ?? expense;
        final totalShares = current.participantShares.values.fold<double>(
          0,
          (sum, share) => sum + share,
        );
        final averageShare = current.participantShares.isEmpty
            ? 0.0
            : totalShares / current.participantShares.length;

        return Scaffold(
          backgroundColor: colors.surface,
          appBar: AppBar(
            title: const Text('Detalle del gasto'),
            surfaceTintColor: Colors.transparent,
            actions: [
              IconButton(
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                tooltip: 'Chat del grupo',
                onPressed: () => _navigate(context, ChatScreen(group: group)),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Proponer cambio',
                onPressed: () => _navigate(
                  context,
                  EditExpenseScreen(group: group, expense: current),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Eliminar gasto',
                onPressed: () =>
                    _confirmDelete(context, firestoreService, current),
              ),
              const SizedBox(width: 4),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                children: [
                  _ExpenseHeader(
                    expense: current,
                    formattedDate: dateFormat.format(current.date),
                    currencyFormat: currencyFormat,
                  ),
                  const SizedBox(height: 24),
                  _DetailSection(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Quién pagó',
                    trailing: '${current.payments.length}',
                    child: Column(
                      children: current.payments.entries.map((entry) {
                        final name = current.payerNames[entry.key] ?? 'Usuario';
                        return _PersonAmountTile(
                          name: name,
                          subtitle: 'Aporte al gasto',
                          amount: currencyFormat.format(entry.value),
                          icon: Icons.north_east_rounded,
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    icon: Icons.groups_2_outlined,
                    title: 'Reparto del gasto',
                    trailing:
                        '${current.participantIds.length} ${current.participantIds.length == 1 ? 'persona' : 'personas'}',
                    description:
                        'Cuota promedio: ${currencyFormat.format(averageShare)}',
                    child: current.participantIds.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Text(
                              'Este gasto no tiene participantes asignados.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          )
                        : Column(
                            children: current.participantIds.map((uid) {
                              final name = group.memberNames[uid] ?? 'Usuario';
                              final paid = current.payments[uid] ?? 0;
                              final share = current.participantShares[uid] ?? 0;
                              final net = paid - share;
                              final isCredit = net > 0.5;
                              final isDebt = net < -0.5;
                              final statusColor = isCredit
                                  ? const Color(0xFF19734A)
                                  : isDebt
                                  ? colors.error
                                  : colors.onSurfaceVariant;
                              final status = isCredit
                                  ? 'Le deben ${currencyFormat.format(net)}'
                                  : isDebt
                                  ? 'Debe ${currencyFormat.format(net.abs())}'
                                  : 'Está a mano';

                              return _PersonAmountTile(
                                name: name,
                                subtitle:
                                    'Cuota: ${currencyFormat.format(share)}',
                                amount: status,
                                amountColor: statusColor,
                                icon: isCredit
                                    ? Icons.north_east_rounded
                                    : isDebt
                                    ? Icons.south_west_rounded
                                    : Icons.check_rounded,
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () =>
                        _navigate(context, ChatScreen(group: group)),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded),
                    label: const Text('Ver conversación del grupo'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _navigate(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _confirmDelete(
    BuildContext context,
    FirestoreService service,
    ExpenseModel current,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded),
        title: const Text('Eliminar gasto'),
        content: Text(
          '¿Eliminar "${current.description}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await service.deleteExpense(group.id, current.id);
      if (context.mounted) Navigator.of(context).pop();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo eliminar el gasto: $error')),
        );
      }
    }
  }
}

class _ExpenseHeader extends StatelessWidget {
  const _ExpenseHeader({
    required this.expense,
    required this.formattedDate,
    required this.currencyFormat,
  });

  final ExpenseModel expense;
  final String formattedDate;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary,
            Color.lerp(colors.primary, colors.tertiary, 0.34)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colors.onPrimary.withValues(alpha: 0.15),
                child: Icon(
                  iconForCategory(expense.category),
                  color: colors.onPrimary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${expense.category} · $formattedDate',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onPrimary.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'MONTO TOTAL',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.76),
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            currencyFormat.format(expense.amount),
            style: theme.textTheme.displaySmall?.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
            ),
          ),
          if (expense.lastEditedAt != null) ...[
            const SizedBox(height: 10),
            Text(
              'Editado el ${DateFormat('dd MMM yyyy', 'es').format(expense.lastEditedAt!)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onPrimary.withValues(alpha: 0.76),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
    this.description,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final String? description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: colors.shadow.withValues(alpha: 0.06),
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 21, color: colors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 5),
              Text(
                description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _PersonAmountTile extends StatelessWidget {
  const _PersonAmountTile({
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.icon,
    this.amountColor,
  });

  final String name;
  final String subtitle;
  final String amount;
  final IconData icon;
  final Color? amountColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final avatarText = name.trim().isEmpty
        ? '?'
        : name.trim().characters.first.toUpperCase();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.secondaryContainer,
            child: Text(
              avatarText,
              style: TextStyle(
                color: colors.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: amountColor ?? colors.primary),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    amount,
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: amountColor ?? colors.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
