import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/balance_model.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';
import '../../models/expense_proposal_model.dart';
import '../../models/group_model.dart';
import '../../models/settlement_record_model.dart';
import '../../services/firestore_service.dart';
import '../widgets/register_settlement_dialog.dart';
import '../widgets/settlement_suggestion_card.dart';
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
          backgroundColor: const Color(0xFFEAF4FB),
          appBar: AppBar(
            title: const Text('Detalle del gasto'),
            backgroundColor: const Color(0xFFEAF4FB),
            foregroundColor: const Color(0xFF173B75),
            elevation: 0,
            scrolledUnderElevation: 0,
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
                    accentColor: const Color(0xFF087F8C),
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
                          accentColor: const Color(0xFF087F8C),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ExpensePaymentsSection(
                    group: group,
                    expense: current,
                    service: firestoreService,
                    currencyFormat: currencyFormat,
                    memberPhotoUrls: memberPhotoUrls,
                  ),
                  const SizedBox(height: 16),
                  _DetailSection(
                    icon: Icons.groups_2_outlined,
                    title: 'Reparto del gasto',
                    trailing:
                        '${current.participantIds.length} ${current.participantIds.length == 1 ? 'persona' : 'personas'}',
                    description:
                        'Cuota promedio: ${currencyFormat.format(averageShare)}',
                    accentColor: const Color(0xFF8859C8),
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
                                accentColor: statusColor,
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () =>
                        _navigate(context, ChatScreen(group: group)),
                    style: FilledButton.styleFrom(
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

class _ExpensePaymentsSection extends StatefulWidget {
  const _ExpensePaymentsSection({
    required this.group,
    required this.expense,
    required this.service,
    required this.currencyFormat,
    required this.memberPhotoUrls,
  });

  final GroupModel group;
  final ExpenseModel expense;
  final FirestoreService service;
  final NumberFormat currencyFormat;
  final Future<Map<String, String>> memberPhotoUrls;

  @override
  State<_ExpensePaymentsSection> createState() =>
      _ExpensePaymentsSectionState();
}

class _ExpensePaymentsSectionState extends State<_ExpensePaymentsSection> {
  late final Stream<List<SettlementRecord>> _settlementsStream;
  bool _isRegisteringPayment = false;

  @override
  void initState() {
    super.initState();
    _settlementsStream = widget.service.watchGroupSettlements(widget.group.id);
  }

  Future<void> _registerPayment(SettlementTransaction settlement) async {
    if (_isRegisteringPayment) return;
    setState(() => _isRegisteringPayment = true);
    try {
      final draft = await showDialog<SettlementDraft>(
        context: context,
        builder: (_) => RegisterSettlementDialog(
          settlement: settlement,
          currencyFormat: widget.currencyFormat,
        ),
      );
      if (!mounted || draft == null) return;
      await widget.service.registerSettlement(
        groupId: widget.group.id,
        fromUid: settlement.fromUid,
        toUid: settlement.toUid,
        amount: draft.amount,
        expenseId: widget.expense.id,
        note: draft.note,
        imageBase64: draft.imageBase64,
        imageContentType: draft.imageContentType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pago registrado y balance actualizado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar el pago: $error')),
      );
    } finally {
      if (mounted) setState(() => _isRegisteringPayment = false);
    }
  }

  Future<void> _showReceipt(SettlementRecord settlement) async {
    try {
      final receipt = await widget.service.getSettlementReceipt(
        groupId: widget.group.id,
        settlementId: settlement.id,
      );
      if (!mounted) return;
      if (receipt == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El comprobante ya no está disponible.'),
          ),
        );
        return;
      }

      final bytes = base64Decode(receipt.imageBase64);
      await showDialog<void>(
        context: context,
        builder: (context) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              title: const Text('Comprobante de pago'),
              leading: IconButton(
                tooltip: 'Cerrar',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
            body: Center(
              child: InteractiveViewer(
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
    } on FormatException catch (error) {
      debugPrint('El comprobante ${settlement.id} no es Base64 válido: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se puede mostrar el comprobante.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo cargar el comprobante: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final relevantUids = {
      ...widget.expense.participantIds,
      ...widget.expense.payerIds,
    };

    return StreamBuilder<List<SettlementRecord>>(
      stream: _settlementsStream,
      builder: (context, settlementSnapshot) {
        final expenseSettlements =
            (settlementSnapshot.data ?? const <SettlementRecord>[])
            .where((settlement) => settlement.expenseId == widget.expense.id)
            .toList();
        final balances = widget.service.calculateBalances(
          group: widget.group,
          expenses: [widget.expense],
          settlements: expenseSettlements,
        );
        final debts = widget.service
            .simplifyDebts(balances)
            .where(
              (debt) =>
                  relevantUids.contains(debt.fromUid) &&
                  relevantUids.contains(debt.toUid),
            )
            .toList();
        final recordedPayments = expenseSettlements
            .where(
              (payment) =>
                  relevantUids.contains(payment.fromUid) &&
                  relevantUids.contains(payment.toUid),
            )
            .take(5)
            .toList();

        return _DetailSection(
          icon: Icons.swap_horiz_rounded,
          title: 'Liquidación sugerida',
          trailing: '${debts.length} pendientes',
          accentColor: const Color(0xFF4F69D6),
          description:
              'Montos de este gasto, sin compensar deudas de otros gastos del grupo.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (settlementSnapshot.hasError)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'No se pudieron actualizar los pagos registrados: ${settlementSnapshot.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (debts.isEmpty)
                _PaymentsEmptyState(
                  message: 'No hay liquidaciones pendientes para este gasto.',
                )
              else
                ...debts.map(
                  (debt) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: SettlementSuggestionCard(
                      settlement: debt,
                      currencyFormat: widget.currencyFormat,
                      memberPhotoUrls: widget.memberPhotoUrls,
                      showRegisterPayment: debt.fromUid == currentUid,
                      isRegistering: _isRegisteringPayment,
                      onRegisterPayment: debt.fromUid == currentUid
                          ? () => _registerPayment(debt)
                          : null,
                    ),
                  ),
                ),
              if (recordedPayments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Pagos registrados',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: const Color(0xFF173B75),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                ...recordedPayments.map(
                  (payment) => _RecordedPaymentTile(
                    settlement: payment,
                    currencyFormat: widget.currencyFormat,
                    onViewReceipt: payment.hasReceipt
                        ? () => _showReceipt(payment)
                        : null,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PaymentsEmptyState extends StatelessWidget {
  const _PaymentsEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F8FB),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.check_circle_outline_rounded,
          color: Color(0xFF087F8C),
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

class _RecordedPaymentTile extends StatelessWidget {
  const _RecordedPaymentTile({
    required this.settlement,
    required this.currencyFormat,
    required this.onViewReceipt,
  });

  final SettlementRecord settlement;
  final NumberFormat currencyFormat;
  final VoidCallback? onViewReceipt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6F5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Color(0xFF087F8C),
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${settlement.fromName} pagó a ${settlement.toName}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF173B75),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                currencyFormat.format(settlement.amount),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF087F8C),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (settlement.note?.isNotEmpty == true) ...[
            const SizedBox(height: 5),
            Text(
              settlement.note!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF526879),
              ),
            ),
          ],
          if (settlement.hasReceipt) ...[
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onViewReceipt,
                icon: const Icon(Icons.image_search_rounded, size: 18),
                label: const Text('Ver comprobante'),
              ),
            ),
          ],
        ],
      ),
    );
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
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2457C5), Color(0xFF087F8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2457C5).withValues(alpha: 0.24),
            blurRadius: 26,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -44,
            top: -72,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.11),
                  width: 24,
                ),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 17,
            child: Icon(
              Icons.receipt_long_rounded,
              size: 78,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(
                        iconForCategory(expense.category),
                        color: Colors.white,
                        size: 25,
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
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.25,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${expense.category} · $formattedDate',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.83),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(15, 13, 16, 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.13),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.17),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MONTO TOTAL',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        currencyFormat.format(expense.amount),
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                if (expense.lastEditedAt != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Editado el ${DateFormat('dd MMM yyyy', 'es').format(expense.lastEditedAt!)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
    this.accentColor = const Color(0xFF087F8C),
    this.trailing,
    this.description,
  });

  final IconData icon;
  final String title;
  final String? trailing;
  final String? description;
  final Widget child;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color.lerp(Colors.white, accentColor, 0.055)!],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.09),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, size: 21, color: accentColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF173B75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      trailing!,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (description != null) ...[
              const SizedBox(height: 5),
              Text(
                description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF687C8D),
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
    this.accentColor,
  });

  final String uid;
  final String name;
  final String subtitle;
  final String amount;
  final IconData icon;
  final Future<Map<String, String>> memberPhotoUrls;
  final Color? amountColor;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tileColor = accentColor ?? amountColor ?? const Color(0xFF087F8C);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: tileColor.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tileColor.withValues(alpha: 0.13)),
        ),
        child: Row(
          children: [
            FutureBuilder<Map<String, String>>(
              future: memberPhotoUrls,
              builder: (context, snapshot) => PersonAvatar(
                name: name,
                photoSource: snapshot.data?[uid],
                radius: 20,
                backgroundColor: tileColor.withValues(alpha: 0.14),
                foregroundColor: tileColor,
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
                      color: const Color(0xFF173B75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF687C8D),
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
                  Icon(icon, size: 16, color: amountColor ?? tileColor),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      amount,
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: amountColor ?? const Color(0xFF173B75),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
