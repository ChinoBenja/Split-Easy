import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../models/balance_model.dart';
import '../../services/firestore_service.dart';
import '../widgets/person_avatar.dart';

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

  @override
  void initState() {
    super.initState();
    _memberPhotoUrls = _firestoreService.getUserPhotoUrls(
      widget.group.memberIds,
    );
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
                  const SizedBox(height: 22),
                  _SectionHeading(
                    title: 'Balance por integrante',
                    subtitle: 'Aportes, gastos asignados y saldo individual',
                    icon: Icons.groups_2_rounded,
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
    );
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
            color: const Color(0xFF176B87).withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -28,
            top: -62,
            child: Container(
              width: 158,
              height: 158,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
            ),
          ),
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
                  Text(
                    'BALANCE DEL GRUPO',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Text(
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
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F3F8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF087F8C), size: 21),
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
    final label = isPositive
        ? 'Le deben ${currencyFormat.format(balance.balance)}'
        : isNegative
        ? 'Debe ${currencyFormat.format(-balance.balance)}'
        : 'Está a mano';

    return FutureBuilder<Map<String, String>>(
      future: memberPhotoUrls,
      builder: (context, snapshot) => Card(
        margin: EdgeInsets.zero,
        elevation: 1,
        shadowColor: const Color(0xFF173B75).withValues(alpha: 0.06),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFDCE8EF)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              PersonAvatar(
                name: balance.name,
                photoSource: snapshot.data?[balance.uid],
                radius: 22,
                backgroundColor: color.withValues(alpha: 0.14),
                foregroundColor: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      balance.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF173B75),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pagó ${currencyFormat.format(balance.totalPaid)} · Le correspondía ${currencyFormat.format(balance.totalOwed)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF687C8D),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
      builder: (context, snapshot) => Card(
        margin: EdgeInsets.zero,
        elevation: 1,
        shadowColor: const Color(0xFF173B75).withValues(alpha: 0.06),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0xFFDCE8EF)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              PersonAvatar(
                name: settlement.fromName,
                photoSource: snapshot.data?[settlement.fromUid],
                radius: 17,
              ),
              const SizedBox(width: 7),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: Color(0xFF087F8C),
              ),
              const SizedBox(width: 7),
              PersonAvatar(
                name: settlement.toName,
                photoSource: snapshot.data?[settlement.toUid],
                radius: 17,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${settlement.fromName} → ${settlement.toName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF173B75),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                currencyFormat.format(settlement.amount),
                maxLines: 1,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF087F8C),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
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
