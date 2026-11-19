import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';
import '../../models/expense_proposal_model.dart';
import '../../models/group_model.dart';
import '../../services/firestore_service.dart';
import 'chat_screen.dart';
import 'edit_expense_screen.dart';
import '../widgets/person_avatar.dart';

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
    final memberPhotoUrls = firestoreService.getUserPhotoUrls(group.memberIds);
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
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Proponer cambio',
                onPressed: () => _navigate(
                  context,
                  EditExpenseScreen(group: group, expense: current),
                ),
              ),
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
                          uid: entry.key,
                          name: name,
                          subtitle: 'Aporte al gasto',
                          amount: currencyFormat.format(entry.value),
                          icon: Icons.north_east_rounded,
                          memberPhotoUrls: memberPhotoUrls,
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
                                uid: uid,
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
                                memberPhotoUrls: memberPhotoUrls,
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
                  const SizedBox(height: 16),
                  _ExpenseDeletionSection(
                    group: group,
                    expense: current,
                    service: firestoreService,
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
}

class _ExpenseDeletionSection extends StatefulWidget {
  const _ExpenseDeletionSection({
    required this.group,
    required this.expense,
    required this.service,
  });

  final GroupModel group;
  final ExpenseModel expense;
  final FirestoreService service;

  @override
  State<_ExpenseDeletionSection> createState() =>
      _ExpenseDeletionSectionState();
}

class _ExpenseDeletionSectionState extends State<_ExpenseDeletionSection> {
  late Stream<List<ExpenseProposal>> _proposalsStream;
  bool _isSubmitting = false;
  final Set<String> _handledApprovedProposals = {};

  @override
  void initState() {
    super.initState();
    _proposalsStream = widget.service.watchProposals(
      widget.group.id,
      widget.expense.id,
    );
  }

  Future<void> _deleteOrPropose(List<ExpenseProposal> proposals) async {
    if (_isSubmitting) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showMessage('Inicia sesión para eliminar este gasto.');
      return;
    }

    final hasPendingProposal = proposals.any(
      (proposal) => proposal.type == 'delete' && proposal.status == 'pending',
    );
    if (hasPendingProposal) {
      _showMessage('Ya hay una propuesta de eliminación pendiente.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.how_to_vote_outlined),
        title: const Text('Proponer eliminación'),
        content: Text(
          'Se enviará una propuesta para eliminar "${widget.expense.description}". '
          'El gasto se eliminará solo si todos los integrantes aceptan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Enviar propuesta'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isSubmitting = true);
    final performedByName =
        widget.group.memberNames[user.uid] ??
        user.displayName ??
        user.email ??
        'Usuario';
    try {
      await widget.service.proposeExpenseDeletion(
        groupId: widget.group.id,
        expenseId: widget.expense.id,
        proposedBy: user.uid,
        proposedByName: performedByName,
        expenseSnapshot: widget.expense.toMap(),
      );
      if (!mounted) return;
      _showMessage('Propuesta enviada a todos los integrantes del grupo.');
    } catch (error) {
      _showMessage('No se pudo procesar la eliminación: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _respond(ExpenseProposal proposal, String response) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      final status = await widget.service.respondToProposal(
        groupId: widget.group.id,
        expenseId: widget.expense.id,
        proposalId: proposal.id,
        uid: user.uid,
        response: response,
        groupMemberIds: widget.group.memberIds,
      );
      if (!mounted) return;

      if (status == 'approved') {
        _showMessage('Todos aceptaron. El gasto fue eliminado.');
        Navigator.of(context).pop();
      } else if (status == 'rejected') {
        _showMessage('La propuesta de eliminación fue rechazada.');
      } else {
        _showMessage(
          response == 'accepted'
              ? 'Registramos tu aceptación.'
              : 'Registramos tu rechazo.',
        );
      }
    } catch (error) {
      _showMessage('No se pudo registrar tu respuesta: $error');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _memberName(String uid) =>
      widget.group.memberNames[uid] ?? 'Integrante';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return StreamBuilder<List<ExpenseProposal>>(
      stream: _proposalsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'No se pudieron cargar las propuestas: ${snapshot.error}',
                style: TextStyle(color: colors.error),
              ),
              const SizedBox(height: 12),
              _deleteButton(const [], canDelete: false),
            ],
          );
        }

        final deletionProposals = (snapshot.data ?? const <ExpenseProposal>[])
            .where((proposal) => proposal.type == 'delete')
            .toList();
        final activeProposal = deletionProposals
            .cast<ExpenseProposal?>()
            .firstWhere(
              (proposal) => proposal?.status == 'pending',
              orElse: () => null,
            );

        for (final proposal in deletionProposals) {
          if (proposal.status == 'approved' &&
              _handledApprovedProposals.add(proposal.id)) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              }
            });
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final proposal in deletionProposals)
              _proposalCard(proposal, colors),
            _deleteButton(deletionProposals, activeProposal: activeProposal),
          ],
        );
      },
    );
  }

  Widget _deleteButton(
    List<ExpenseProposal> proposals, {
    ExpenseProposal? activeProposal,
    bool canDelete = true,
  }) {
    return FilledButton.icon(
      onPressed: _isSubmitting || activeProposal != null || !canDelete
          ? null
          : () => _deleteOrPropose(proposals),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      icon: _isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.how_to_vote_outlined),
      label: Text(
        activeProposal != null
            ? 'Esperando respuestas'
            : 'Proponer eliminación',
      ),
    );
  }

  Widget _proposalCard(ExpenseProposal proposal, ColorScheme colors) {
    final accepted = widget.group.memberIds
        .where((uid) => proposal.responses[uid] == 'accepted')
        .map(_memberName)
        .toList();
    final rejected = widget.group.memberIds
        .where((uid) => proposal.responses[uid] == 'rejected')
        .map(_memberName)
        .toList();
    final pending = proposal.status == 'pending'
        ? proposal.pendingMembers(widget.group.memberIds)
        : const <String>[];
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final canRespond =
        proposal.status == 'pending' &&
        currentUid != null &&
        !proposal.hasResponded(currentUid);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      color: colors.errorContainer.withValues(alpha: 0.45),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.how_to_vote_outlined, color: colors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${proposal.proposedByName} propuso eliminar este gasto',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (accepted.isNotEmpty)
              _responseLine(
                Icons.check_circle_outline_rounded,
                'Aceptado por ${accepted.join(', ')}',
                colors.primary,
              ),
            if (rejected.isNotEmpty)
              _responseLine(
                Icons.cancel_outlined,
                'Rechazado por ${rejected.join(', ')}',
                colors.error,
              ),
            if (pending.isNotEmpty)
              _responseLine(
                Icons.schedule_rounded,
                'Pendiente de ${pending.map(_memberName).join(', ')}',
                colors.onSurfaceVariant,
              ),
            if (proposal.status == 'approved')
              _responseLine(
                Icons.check_circle_rounded,
                'Todos aceptaron; el gasto fue eliminado.',
                colors.primary,
              ),
            if (proposal.status == 'rejected' && rejected.isEmpty)
              _responseLine(
                Icons.cancel_rounded,
                'La propuesta fue rechazada.',
                colors.error,
              ),
            if (canRespond) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => _respond(proposal, 'rejected'),
                      child: const Text('Rechazar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => _respond(proposal, 'accepted'),
                      child: const Text('Aceptar eliminación'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _responseLine(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 7),
          Expanded(child: Text(text)),
        ],
      ),
    );
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
    required this.uid,
    required this.name,
    required this.subtitle,
    required this.amount,
    required this.icon,
    required this.memberPhotoUrls,
    this.amountColor,
  });

  final String uid;
  final String name;
  final String subtitle;
  final String amount;
  final IconData icon;
  final Future<Map<String, String>> memberPhotoUrls;
  final Color? amountColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          FutureBuilder<Map<String, String>>(
            future: memberPhotoUrls,
            builder: (context, snapshot) => PersonAvatar(
              name: name,
              photoSource: snapshot.data?[uid],
              radius: 20,
              backgroundColor: colors.secondaryContainer,
              foregroundColor: colors.onSecondaryContainer,
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
