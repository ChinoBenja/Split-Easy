import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../models/balance_model.dart';
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
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2457C5)),
            );
          }

          final expenses = snapshot.data!;
          final balances = _firestoreService.calculateBalances(
            group: widget.group,
            expenses: expenses,
          );
          final settlements = _firestoreService.simplifyDebts(balances);

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
                    settlementCount: settlements.length,
                  ),
                  const SizedBox(height: 16),
                  _BalanceSummaryStrip(
                    totalExpenses: expenses.fold<double>(
                      0,
                      (total, expense) => total + expense.amount,
                    ),
                    totalToSettle: settlements.fold<double>(
                      0,
                      (total, settlement) => total + settlement.amount,
                    ),
                    currencyFormat: _currencyFormat,
                  ),
                  const SizedBox(height: 24),
                  _SectionHeading(
                    title: 'Balance por integrante',
                    subtitle: 'Aportes, gastos asignados y saldo individual',
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
                    trailingLabel: '${settlements.length}',
                  ),
                  const SizedBox(height: 12),
                  if (settlements.isEmpty)
                    const _SettledCard()
                  else
                    ...settlements.map(
                      (settlement) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _SettlementTile(
                          settlement: settlement,
                          currencyFormat: _currencyFormat,
                          memberPhotoUrls: _memberPhotoUrls,
                        ),
                      ),
                    ),
                ],
              ),
            ),
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
        if (trailingLabel != null)
          Container(
            constraints: const BoxConstraints(minWidth: 32),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFDCEFF2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              trailingLabel!,
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
  });

  final SettlementTransaction settlement;
  final NumberFormat currencyFormat;
  final Future<Map<String, String>> memberPhotoUrls;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Map<String, String>>(
      future: memberPhotoUrls,
      builder: (context, snapshot) => Container(
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
                  photoSource: snapshot.data?[settlement.fromUid],
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
                  photoSource: snapshot.data?[settlement.toUid],
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
          ],
        ),
      ),
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
