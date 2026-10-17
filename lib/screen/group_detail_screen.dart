import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../services/firestore_service.dart';
import 'add_expense_screen.dart';
import 'balance_screen.dart';
import 'chat_screen.dart';
import 'expense_detail_screen.dart';
import 'history_screen.dart';
import 'analytics_dashboard_screen.dart';
import 'reports_screen.dart';

class GroupDetailScreen extends StatefulWidget {
  final GroupModel group;

  const GroupDetailScreen({super.key, required this.group});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> {
  final _firestoreService = FirestoreService();
  final _currencyFormat = NumberFormat.currency(
    locale: 'es_CL',
    symbol: '\$',
    decimalDigits: 0,
  );
  final _dateFormat = DateFormat('dd MMM yyyy', 'es');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.group.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Historial de cambios',
            onPressed: () =>
                _navigateTo(context, HistoryScreen(group: widget.group)),
          ),
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            tooltip: 'Chat del grupo',
            onPressed: () =>
                _navigateTo(context, ChatScreen(group: widget.group)),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            tooltip: 'Balance del grupo',
            onPressed: () =>
                _navigateTo(context, BalanceScreen(group: widget.group)),
          ),
          IconButton(
            icon: const Icon(Icons.insights_rounded),
            tooltip: 'Analítica financiera',
            onPressed: () => _navigateTo(
              context,
              AnalyticsDashboardScreen(group: widget.group),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Reportes y exportación PDF',
            onPressed: () =>
                _navigateTo(context, ReportsScreen(group: widget.group)),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<List<ExpenseModel>>(
        stream: _firestoreService.watchGroupExpenses(widget.group.id),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No se pudieron cargar los gastos.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.error,
                  ),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: colors.primary),
            );
          }

          final expenses = snapshot.data!;
          final totalSpent = expenses.fold<double>(
            0,
            (total, expense) => total + expense.amount,
          );
          final userId = FirebaseAuth.instance.currentUser?.uid;
          final userContribution = userId == null
              ? 0.0
              : expenses.fold<double>(
                  0,
                  (total, expense) => total + (expense.payments[userId] ?? 0),
                );
          final memberBalances = _firestoreService.calculateBalances(
            group: widget.group,
            expenses: expenses,
          );
          final userBalance = userId == null
              ? 0.0
              : memberBalances
                        .where((balance) => balance.uid == userId)
                        .firstOrNull
                        ?.balance ??
                    0.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 112),
                children: [
                  Text(
                    'Resumen financiero',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Consulta los gastos y tu situación en este grupo.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _FinancialSummaryCard(
                    totalSpent: totalSpent,
                    userContribution: userContribution,
                    userBalance: userBalance,
                    currencyFormat: _currencyFormat,
                  ),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Gastos del grupo',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (expenses.isNotEmpty)
                        Text(
                          '${expenses.length} ${expenses.length == 1 ? 'movimiento' : 'movimientos'}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (expenses.isEmpty)
                    const _EmptyExpensesState()
                  else
                    ...expenses.map(
                      (expense) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ExpenseCard(
                          expense: expense,
                          formattedDate: _dateFormat.format(expense.date),
                          currencyFormat: _currencyFormat,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ExpenseDetailScreen(
                                group: widget.group,
                                expense: expense,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar gasto'),
        onPressed: () =>
            _navigateTo(context, AddExpenseScreen(group: widget.group)),
      ),
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _FinancialSummaryCard extends StatelessWidget {
  const _FinancialSummaryCard({
    required this.totalSpent,
    required this.userContribution,
    required this.userBalance,
    required this.currencyFormat,
  });

  final double totalSpent;
  final double userContribution;
  final double userBalance;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isCredit = userBalance > 0.01;
    final isDebt = userBalance < -0.01;
    final balanceColor = isCredit
        ? const Color(0xFFB9F2D0)
        : isDebt
        ? const Color(0xFFFFC6C6)
        : colors.onPrimary;
    final balanceTitle = isCredit
        ? 'TE DEBEN'
        : isDebt
        ? 'DEBES'
        : 'BALANCE';
    final balanceValue = isCredit || isDebt
        ? currencyFormat.format(userBalance.abs())
        : 'Al día';

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
            color: colors.primary.withValues(alpha: 0.19),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GASTO TOTAL DEL GRUPO',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colors.onPrimary.withValues(alpha: 0.76),
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            currencyFormat.format(totalSpent),
            style: theme.textTheme.headlineLarge?.copyWith(
              color: colors.onPrimary,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Divider(
              height: 1,
              color: colors.onPrimary.withValues(alpha: 0.2),
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final contributionMetric = _FinancialMetric(
                title: 'TÚ HAS APORTADO',
                value: currencyFormat.format(userContribution),
                color: colors.onPrimary,
                mutedColor: colors.onPrimary.withValues(alpha: 0.74),
                icon: Icons.account_balance_wallet_outlined,
              );
              final balanceMetric = _FinancialMetric(
                title: balanceTitle,
                value: balanceValue,
                color: balanceColor,
                mutedColor: colors.onPrimary.withValues(alpha: 0.74),
                icon: isDebt
                    ? Icons.south_west_rounded
                    : isCredit
                    ? Icons.north_east_rounded
                    : Icons.check_circle_outline_rounded,
              );

              if (constraints.maxWidth < 480) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    contributionMetric,
                    const SizedBox(height: 18),
                    balanceMetric,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: contributionMetric),
                  const SizedBox(width: 20),
                  Expanded(child: balanceMetric),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FinancialMetric extends StatelessWidget {
  const _FinancialMetric({
    required this.title,
    required this.value,
    required this.color,
    required this.mutedColor,
    required this.icon,
  });

  final String title;
  final String value;
  final Color color;
  final Color mutedColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelSmall?.copyWith(
            color: mutedColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 7),
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({
    required this.expense,
    required this.formattedDate,
    required this.currencyFormat,
    required this.onTap,
  });

  final ExpenseModel expense;
  final String formattedDate;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isSettled = expense.isFullySettled;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: colors.shadow.withValues(alpha: 0.07),
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.55)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: colors.secondaryContainer,
                child: Icon(
                  iconForCategory(expense.category),
                  size: 21,
                  color: colors.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      expense.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${expense.category} · Pagó ${expense.payersSummary}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          formattedDate,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    currencyFormat.format(expense.amount),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isSettled
                          ? const Color(0xFF19734A).withValues(alpha: 0.1)
                          : colors.tertiaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      isSettled
                          ? 'Al día'
                          : '${expense.participantIds.length} personas',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isSettled
                            ? const Color(0xFF19734A)
                            : colors.onTertiaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyExpensesState extends StatelessWidget {
  const _EmptyExpensesState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 34),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: 44,
              color: colors.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Aún no hay gastos registrados',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Agrega el primer gasto del grupo para empezar a organizar las cuentas.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Icon(Icons.south_rounded, size: 20, color: colors.primary),
        ],
      ),
    );
  }
}
