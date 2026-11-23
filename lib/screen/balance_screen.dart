import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../models/balance_model.dart';
import '../../models/settlement_record_model.dart';
import '../../services/firestore_service.dart';
import '../widgets/main_navigation_bar.dart';
import '../widgets/person_avatar.dart';
import 'add_expense_screen.dart';
import 'assistant_chat_screen.dart';
import 'create_group_screen.dart';
import 'profile_screen.dart';

/// Pantalla de balance del grupo.
class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key, required this.group});

  final GroupModel group;

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
  Future<String?>? _userPhotoFuture;
  bool _isRegisteringSettlement = false;

  @override
  void initState() {
    super.initState();
    _memberPhotoUrls = _firestoreService.getUserPhotoUrls(
      widget.group.memberIds,
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _userPhotoFuture = _firestoreService.getUserPhoto(uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: Text(
          'Balance del grupo',
          style: theme.textTheme.titleLarge?.copyWith(
            color: const Color(0xFF173B75),
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: const Color(0xFFEAF4FB),
        foregroundColor: const Color(0xFF173B75),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: StreamBuilder<List<ExpenseModel>>(
        stream: _firestoreService.watchGroupExpenses(widget.group.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _BalanceMessage(
              icon: Icons.cloud_off_rounded,
              title: 'No se pudo cargar el balance',
              message:
                  'Revisa tu conexión e inténtalo nuevamente.\n${snapshot.error}',
              isError: true,
            );
          }
          final expenses = snapshot.data;
          if (!snapshot.hasData || expenses == null) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2457C5)),
            );
          }

          return StreamBuilder<List<SettlementRecord>>(
            stream: _firestoreService.watchGroupSettlements(widget.group.id),
            builder: (context, settlementSnapshot) {
              if (settlementSnapshot.hasError) {
                return _BalanceMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'No se pudieron cargar los pagos registrados',
                  message:
                      'Revisa tu conexión e inténtalo nuevamente.\n${settlementSnapshot.error}',
                  isError: true,
                );
              }
              final recordedSettlements = settlementSnapshot.data;
              if (!settlementSnapshot.hasData || recordedSettlements == null) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2457C5)),
                );
              }
              final balances = _firestoreService.calculateBalances(
                group: widget.group,
                expenses: expenses,
                settlements: recordedSettlements,
              );
              final suggestedSettlements = _firestoreService.simplifyDebts(
                balances,
              );
              final currentUid = FirebaseAuth.instance.currentUser?.uid;

              if (expenses.isEmpty) {
                return _BalanceMessage(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Aún no hay gastos',
                  message:
                      'Cuando el grupo registre gastos, aquí podrás revisar los saldos y las liquidaciones sugeridas.',
                );
              }

              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      _BalanceHeader(
                        groupName: widget.group.name,
                        memberCount: balances.length,
                        settlementCount: suggestedSettlements.length,
                      ),
                      const SizedBox(height: 16),
                      _BalanceSummaryStrip(
                        totalExpenses: expenses.fold<double>(
                          0,
                          (total, expense) => total + expense.amount,
                        ),
                        totalToSettle: suggestedSettlements.fold<double>(
                          0,
                          (total, settlement) => total + settlement.amount,
                        ),
                        currencyFormat: _currencyFormat,
                      ),
                      const SizedBox(height: 24),
                      _SectionHeading(
                        title: 'Balance por integrante',
                        subtitle:
                            'Aportes, gastos asignados y saldo individual',
                        icon: Icons.groups_2_rounded,
                        trailingLabel: '${balances.length}',
                      ),
                      const SizedBox(height: 12),
                      ...balances.map(
                        (balance) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _BalanceTile(
                            balance: balance,
                            currencyFormat: _currencyFormat,
                            memberPhotoUrls: _memberPhotoUrls,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      _SectionHeading(
                        title: 'Liquidación sugerida',
                        subtitle:
                            'El mínimo de pagos para que todos queden a mano.',
                        icon: Icons.swap_horiz_rounded,
                        trailingLabel: '${suggestedSettlements.length}',
                      ),
                      const SizedBox(height: 12),
                      if (suggestedSettlements.isEmpty)
                        const _SettledCard()
                      else
                        ...suggestedSettlements.map(
                          (settlement) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _SettlementTile(
                              settlement: settlement,
                              currencyFormat: _currencyFormat,
                              memberPhotoUrls: _memberPhotoUrls,
                              showRegisterPayment:
                                  settlement.fromUid == currentUid,
                              onRegisterPayment:
                                  _isRegisteringSettlement ||
                                      settlement.fromUid != currentUid
                                  ? null
                                  : () => _registerSettlement(settlement),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      bottomNavigationBar: MainNavigationBar(
        onHomeTap: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        onGroupsTap: _openGroups,
        onAssistantTap: () => _navigateTo(const AssistantChatScreen()),
        onCreateGroupTap: () => _navigateTo(const CreateGroupScreen()),
        onAddExpenseTap: () =>
            _navigateTo(AddExpenseScreen(group: widget.group)),
        onProfileTap: _openProfile,
        profilePhotoFuture: _userPhotoFuture ?? Future<String?>.value(null),
      ),
    );
  }

  Future<void> _registerSettlement(SettlementTransaction settlement) async {
    if (_isRegisteringSettlement) return;
    setState(() => _isRegisteringSettlement = true);
    try {
      final draft = await showDialog<_SettlementDraft>(
        context: context,
        builder: (context) => _RegisterSettlementDialog(
          settlement: settlement,
          currencyFormat: _currencyFormat,
        ),
      );
      if (!mounted || draft == null) return;
      await _firestoreService.registerSettlement(
        groupId: widget.group.id,
        fromUid: settlement.fromUid,
        toUid: settlement.toUid,
        amount: draft.amount,
        note: draft.note,
        imageBase64: draft.imageBase64,
        imageContentType: draft.imageContentType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Pago registrado. El balance del grupo fue actualizado.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar el pago: $error')),
      );
    } finally {
      if (mounted) setState(() => _isRegisteringSettlement = false);
    }
  }

  Future<void> _openGroups() async {
    final navigator = Navigator.of(context);
    await navigator.maybePop();
    if (navigator.canPop()) await navigator.maybePop();
  }

  Future<void> _openProfile() async {
    await _navigateTo(const ProfileScreen());
    if (!mounted) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      setState(() {
        _userPhotoFuture = _firestoreService.getUserPhoto(uid);
      });
    }
  }

  Future<void> _navigateTo(Widget screen) {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _BalanceHeader extends StatelessWidget {
  const _BalanceHeader({
    required this.groupName,
    required this.memberCount,
    required this.settlementCount,
  });

  final String groupName;
  final int memberCount;
  final int settlementCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = settlementCount == 0
        ? 'Todos están a mano'
        : '$settlementCount ${settlementCount == 1 ? 'pago sugerido' : 'pagos sugeridos'}';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3B82B8), Color(0xFF69B8D0)],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF176B87).withValues(alpha: 0.24),
            blurRadius: 26,
            offset: const Offset(0, 11),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -38,
            top: -76,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(right: 7, top: 10, child: _BalanceDocumentDecoration()),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      'BALANCE DEL GRUPO',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 76),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: (MediaQuery.sizeOf(context).width - 180)
                    .clamp(120.0, 250.0)
                    .toDouble(),
                child: Text(
                  groupName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (MediaQuery.sizeOf(context).width - 180)
                      .clamp(120.0, 250.0)
                      .toDouble(),
                ),
                child: Text(
                  'Un resumen claro para que el grupo quede en equilibrio.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _HeaderMetric(
                      label: 'INTEGRANTES',
                      value: '$memberCount',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 38,
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                  Expanded(
                    child: _HeaderMetric(
                      label: 'LIQUIDACIÓN',
                      value: statusLabel,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceDocumentDecoration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.11,
      child: Container(
        width: 66,
        height: 84,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.account_balance_wallet_rounded,
              size: 20,
              color: Colors.white,
            ),
            const SizedBox(height: 8),
            ...List.generate(
              3,
              (index) => Container(
                width: index == 2 ? 26 : 40,
                height: 3,
                margin: const EdgeInsets.only(bottom: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceSummaryStrip extends StatelessWidget {
  const _BalanceSummaryStrip({
    required this.totalExpenses,
    required this.totalToSettle,
    required this.currencyFormat,
  });

  final double totalExpenses;
  final double totalToSettle;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BalanceSummaryCard(
            icon: Icons.receipt_long_rounded,
            label: 'GASTOS DEL GRUPO',
            value: currencyFormat.format(totalExpenses),
            colors: const [Color(0xFF087F8C), Color(0xFF22A6A1)],
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: _BalanceSummaryCard(
            icon: Icons.swap_horiz_rounded,
            label: 'POR LIQUIDAR',
            value: currencyFormat.format(totalToSettle),
            colors: const [Color(0xFF2457C5), Color(0xFF5682D7)],
          ),
        ),
      ],
    );
  }
}

class _BalanceSummaryCard extends StatelessWidget {
  const _BalanceSummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
  });

  final IconData icon;
  final String label;
  final String value;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailingLabel,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String? trailingLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF087F8C), Color(0xFF25A9A7)],
            ),
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF087F8C).withValues(alpha: 0.17),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: const Color(0xFF173B75),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF687C8D),
                ),
              ),
            ],
          ),
        ),
        if (trailingLabel case final label?)
          Container(
            constraints: const BoxConstraints(minWidth: 32),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFDCEFF2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge?.copyWith(
                color: const Color(0xFF087F8C),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({
    required this.balance,
    required this.currencyFormat,
    required this.memberPhotoUrls,
  });

  final MemberBalance balance;
  final NumberFormat currencyFormat;
  final Future<Map<String, String>> memberPhotoUrls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPositive = balance.balance > 0.01;
    final isNegative = balance.balance < -0.01;
    final color = isPositive
        ? const Color(0xFF2E9D68)
        : isNegative
        ? const Color(0xFFD94E61)
        : const Color(0xFF687C8D);
    final status = isPositive
        ? 'A FAVOR'
        : isNegative
        ? 'DEBE'
        : 'AL DÍA';
    final balanceValue = isPositive
        ? balance.balance
        : isNegative
        ? -balance.balance
        : 0.0;
    final statusIcon = isPositive
        ? Icons.arrow_downward_rounded
        : isNegative
        ? Icons.arrow_upward_rounded
        : Icons.check_rounded;

    return FutureBuilder<Map<String, String>>(
      future: memberPhotoUrls,
      builder: (context, snapshot) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: color.withValues(alpha: 0.18)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF173B75).withValues(alpha: 0.055),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: IntrinsicHeight(
            child: Row(
              children: [
                Container(width: 4, color: color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 13, 14, 13),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            PersonAvatar(
                              name: balance.name,
                              photoSource: snapshot.data?[balance.uid],
                              radius: 23,
                              backgroundColor: color.withValues(alpha: 0.14),
                              foregroundColor: color,
                            ),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text(
                                balance.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: const Color(0xFF173B75),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(statusIcon, color: color, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    status,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'SALDO NETO',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: const Color(0xFF8093A1),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currencyFormat.format(balanceValue),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      color: color,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _BalanceMiniMetric(
                                  label: 'Pagó',
                                  value: currencyFormat.format(
                                    balance.totalPaid,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _BalanceMiniMetric(
                                  label: 'Le toca',
                                  value: currencyFormat.format(
                                    balance.totalOwed,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                _BalanceMiniMetric(
                                  label: 'Pagos netos',
                                  value:
                                      '${balance.settlementAdjustment > 0
                                          ? '+'
                                          : balance.settlementAdjustment < 0
                                          ? '−'
                                          : ''}${currencyFormat.format(balance.settlementAdjustment.abs())}',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BalanceMiniMetric extends StatelessWidget {
  const _BalanceMiniMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: style?.copyWith(color: const Color(0xFF8093A1))),
        Text(
          value,
          style: style?.copyWith(
            color: const Color(0xFF35536D),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SettlementTile extends StatelessWidget {
  const _SettlementTile({
    required this.settlement,
    required this.currencyFormat,
    required this.memberPhotoUrls,
    required this.onRegisterPayment,
    required this.showRegisterPayment,
  });

  final SettlementTransaction settlement;
  final NumberFormat currencyFormat;
  final Future<Map<String, String>> memberPhotoUrls;
  final VoidCallback? onRegisterPayment;
  final bool showRegisterPayment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Map<String, String>>(
      future: memberPhotoUrls,
      builder: (context, snapshot) {
        final photoUrls =
            snapshot.connectionState == ConnectionState.done &&
                !snapshot.hasError
            ? snapshot.data ?? const <String, String>{}
            : const <String, String>{};
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF7FBFD)],
            ),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFDCE8EF)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF173B75).withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F3F8),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'PAGO SUGERIDO',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF087F8C),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.45,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: Color(0xFF78A9BB),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Liquidación simple',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF8093A1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  PersonAvatar(
                    name: settlement.fromName,
                    photoSource: photoUrls[settlement.fromUid],
                    radius: 22,
                    backgroundColor: const Color(0xFFE2F0F6),
                    foregroundColor: const Color(0xFF35536D),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          settlement.fromName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: const Color(0xFF173B75),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'paga a',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF8093A1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 34,
                    height: 34,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE5F4F2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Color(0xFF087F8C),
                    ),
                  ),
                  const SizedBox(width: 9),
                  PersonAvatar(
                    name: settlement.toName,
                    photoSource: photoUrls[settlement.toUid],
                    radius: 22,
                    backgroundColor: const Color(0xFFE5F4F2),
                    foregroundColor: const Color(0xFF087F8C),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      settlement.toName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF173B75),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF6F5),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      size: 18,
                      color: Color(0xFF087F8C),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Monto a transferir',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF526879),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      currencyFormat.format(settlement.amount),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF087F8C),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              if (showRegisterPayment) ...[
                const SizedBox(height: 11),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onRegisterPayment,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2457C5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text('Registrar pago o abono'),
                  ),
                ),
                const SizedBox(height: 7),
                Center(
                  child: Text(
                    'Solo queda constancia; no se transfiere dinero desde la app.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF8093A1),
                    ),
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

class _SettlementDraft {
  const _SettlementDraft({
    required this.amount,
    required this.note,
    required this.imageBase64,
    required this.imageContentType,
  });

  final double amount;
  final String? note;
  final String? imageBase64;
  final String? imageContentType;
}

class _RegisterSettlementDialog extends StatefulWidget {
  const _RegisterSettlementDialog({
    required this.settlement,
    required this.currencyFormat,
  });

  final SettlementTransaction settlement;
  final NumberFormat currencyFormat;

  @override
  State<_RegisterSettlementDialog> createState() =>
      _RegisterSettlementDialogState();
}

class _RegisterSettlementDialogState extends State<_RegisterSettlementDialog> {
  late final TextEditingController _amountController = TextEditingController(
    text: widget.settlement.amount % 1 == 0
        ? widget.settlement.amount.toStringAsFixed(0)
        : widget.settlement.amount.toStringAsFixed(2),
  );
  final _noteController = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageBase64;
  String? _imageContentType;
  String? _validationMessage;
  bool _isPickingImage = false;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    if (_isPickingImage) return;
    setState(() {
      _isPickingImage = true;
      _validationMessage = null;
    });
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 75,
      );
      if (!mounted || image == null) return;
      final bytes = await image.readAsBytes().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException(
          'No se pudo leer la imagen del dispositivo.',
        ),
      );
      final encodedImage = base64Encode(bytes);
      if (encodedImage.length > FirestoreService.maxChatImageBase64Length) {
        setState(() {
          _imageBytes = null;
          _imageBase64 = null;
          _imageContentType = null;
          _validationMessage =
              'El comprobante comprimido supera los 700 KB. '
              'Recórtalo o selecciona una imagen más liviana.';
        });
        return;
      }
      setState(() {
        _imageBytes = bytes;
        _imageBase64 = encodedImage;
        final mimeType = image.mimeType;
        _imageContentType = mimeType != null && mimeType.startsWith('image/')
            ? mimeType
            : 'image/jpeg';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _validationMessage = 'No se pudo adjuntar el comprobante: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  void _submit() {
    final amount = double.tryParse(
      _amountController.text.trim().replaceAll(',', '.'),
    );
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(
        () => _validationMessage = 'Ingresa un monto válido mayor que 0.',
      );
      return;
    }
    if (amount > widget.settlement.amount + 0.01) {
      setState(
        () => _validationMessage =
            'El abono no puede superar la deuda pendiente '
            '(${widget.currencyFormat.format(widget.settlement.amount)}).',
      );
      return;
    }
    Navigator.of(context).pop(
      _SettlementDraft(
        amount: amount,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        imageBase64: _imageBase64,
        imageContentType: _imageContentType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(22, 21, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 8),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE7F3F8),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: Color(0xFF087F8C),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              'Registrar pago',
              style: theme.textTheme.titleLarge?.copyWith(
                color: const Color(0xFF173B75),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.settlement.fromName} → ${widget.settlement.toName}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF35536D),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Deuda pendiente: ${widget.currencyFormat.format(widget.settlement.amount)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF687C8D),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Monto pagado o abonado',
                  prefixText: '\$ ',
                  filled: true,
                  fillColor: const Color(0xFFF3F8FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFFDCE8EF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFFDCE8EF)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLength: FirestoreService.maxSettlementNoteLength,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Nota (opcional)',
                  hintText: 'Ej. Transferencia del 22 de noviembre',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: const Color(0xFFF3F8FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFFDCE8EF)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Color(0xFFDCE8EF)),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (_imageBytes case final imageBytes?) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(
                    imageBytes,
                    height: 150,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() {
                      _imageBytes = null;
                      _imageBase64 = null;
                      _imageContentType = null;
                    }),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Quitar comprobante'),
                  ),
                ),
              ] else
                OutlinedButton.icon(
                  onPressed: _isPickingImage ? null : _pickReceipt,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    foregroundColor: const Color(0xFF087F8C),
                    side: const BorderSide(color: Color(0xFFB7DCE8)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _isPickingImage
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_photo_alternate_rounded),
                  label: Text(
                    _isPickingImage
                        ? 'Preparando imagen...'
                        : 'Adjuntar comprobante',
                  ),
                ),
              if (_validationMessage case final validationMessage?) ...[
                const SizedBox(height: 10),
                Text(
                  validationMessage,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFD94E61),
                    height: 1.35,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF6E8),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: const Color(0xFFF3D7A7)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Color(0xFFB27216),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Esto solo registra el pago para el grupo. La app no realiza transferencias.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF77551F),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _isPickingImage ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2457C5),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.check_rounded, size: 18),
          label: const Text('Guardar registro'),
        ),
      ],
    );
  }
}

class _SettledCard extends StatelessWidget {
  const _SettledCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: const Color(0xFF173B75).withValues(alpha: 0.06),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFDCE8EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF2E9D68).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.check_rounded, color: Color(0xFF2E9D68)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '¡Todos están a mano!',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF173B75),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceMessage extends StatelessWidget {
  const _BalanceMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = isError ? const Color(0xFFD94E61) : const Color(0xFF087F8C);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: Card(
            elevation: 1,
            shadowColor: const Color(0xFF173B75).withValues(alpha: 0.06),
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: Color(0xFFDCE8EF)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Icon(icon, size: 29, color: accent),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF173B75),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF687C8D),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
