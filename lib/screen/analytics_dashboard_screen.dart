import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../services/firestore_service.dart';
import '../widgets/person_avatar.dart';

class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key, required this.group});

  final GroupModel group;

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  final _firestoreService = FirestoreService();
  final _currencyFormat = NumberFormat.currency(
    locale: 'es_CL',
    symbol: '\$',
    decimalDigits: 0,
  );
  int _touchedCategoryIndex = -1;
  late final Future<Map<String, String>> _memberPhotoUrls = _firestoreService
      .getUserPhotoUrls(widget.group.memberIds);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: Text(
          'Analítica financiera',
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
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No se pudieron cargar los datos de analítica.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.error,
                    ),
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
          final analytics = _GroupAnalytics.calculate(
            group: widget.group,
            expenses: expenses,
            currentUid: FirebaseAuth.instance.currentUser?.uid,
          );

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1160),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final contentWidth = math.max(0.0, constraints.maxWidth - 48);
                  final kpiColumns = contentWidth >= 900 ? 4 : 2;
                  final kpiGap = 12.0;
                  final kpiWidth =
                      (contentWidth - (kpiGap * (kpiColumns - 1))) / kpiColumns;
                  final chartsSideBySide = contentWidth >= 760;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    children: [
                      _AnalyticsHeader(
                        groupName: widget.group.name,
                        expenseCount: expenses.length,
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: kpiGap,
                        runSpacing: kpiGap,
                        children: [
                          _KpiCard(
                            width: kpiWidth,
                            icon: Icons.account_balance_wallet_outlined,
                            label: 'Gasto total',
                            value: _currencyFormat.format(analytics.total),
                            accent: colors.primary,
                          ),
                          _KpiCard(
                            width: kpiWidth,
                            icon: analytics.personalBalance > 0.01
                                ? Icons.north_east_rounded
                                : analytics.personalBalance < -0.01
                                ? Icons.south_west_rounded
                                : Icons.check_circle_outline_rounded,
                            label: analytics.personalBalance > 0.01
                                ? 'Te deben'
                                : analytics.personalBalance < -0.01
                                ? 'Debes'
                                : 'Balance personal',
                            value: _currencyFormat.format(
                              analytics.personalBalance.abs(),
                            ),
                            accent: analytics.personalBalance > 0.01
                                ? const Color(0xFF19734A)
                                : analytics.personalBalance < -0.01
                                ? colors.error
                                : colors.primary,
                          ),
                          _KpiCard(
                            width: kpiWidth,
                            icon: Icons.groups_2_outlined,
                            label: 'Promedio por integrante',
                            value: _currencyFormat.format(
                              analytics.averagePerMember,
                            ),
                            accent: const Color(0xFF3B82A0),
                          ),
                          _KpiCard(
                            width: kpiWidth,
                            icon: Icons.pie_chart_outline_rounded,
                            label: 'Mayor categoría',
                            value: analytics.topCategory == null
                                ? 'Sin datos'
                                : '${analytics.topCategory} · ${analytics.topCategoryPercent.toStringAsFixed(0)}%',
                            accent: const Color(0xFF087F8C),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      if (chartsSideBySide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _ChartSection(
                                title: 'Distribución del gasto',
                                subtitle: 'Participación por categoría',
                                icon: Icons.donut_large_rounded,
                                child: _CategoryChartCard(
                                  categories: analytics.categoryTotals,
                                  total: analytics.total,
                                  touchedIndex: _touchedCategoryIndex,
                                  currencyFormat: _currencyFormat,
                                  onTouched: (index) {
                                    setState(
                                      () => _touchedCategoryIndex = index,
                                    );
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _ChartSection(
                                title: 'Aportes por integrante',
                                subtitle: 'Total aportado por cada pagador',
                                icon: Icons.bar_chart_rounded,
                                child: _MemberContributionCard(
                                  contributions: analytics.memberContributions,
                                  memberNames: widget.group.memberNames,
                                  memberPhotoUrls: _memberPhotoUrls,
                                  currencyFormat: _currencyFormat,
                                ),
                              ),
                            ),
                          ],
                        )
                      else ...[
                        _ChartSection(
                          title: 'Distribución del gasto',
                          subtitle: 'Participación por categoría',
                          icon: Icons.donut_large_rounded,
                          child: _CategoryChartCard(
                            categories: analytics.categoryTotals,
                            total: analytics.total,
                            touchedIndex: _touchedCategoryIndex,
                            currencyFormat: _currencyFormat,
                            onTouched: (index) {
                              setState(() => _touchedCategoryIndex = index);
                            },
                          ),
                        ),
                        const SizedBox(height: 22),
                        _ChartSection(
                          title: 'Aportes por integrante',
                          subtitle: 'Total aportado por cada pagador',
                          icon: Icons.bar_chart_rounded,
                          child: _MemberContributionCard(
                            contributions: analytics.memberContributions,
                            memberNames: widget.group.memberNames,
                            memberPhotoUrls: _memberPhotoUrls,
                            currencyFormat: _currencyFormat,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _SectionHeading(
                        title: 'Insights y Patrones de Consumo',
                        subtitle:
                            'Lecturas automáticas del comportamiento del grupo',
                        icon: Icons.auto_awesome_outlined,
                      ),
                      const SizedBox(height: 12),
                      _InsightsCard(
                        analytics: analytics,
                        currencyFormat: _currencyFormat,
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GroupAnalytics {
  const _GroupAnalytics({
    required this.total,
    required this.personalBalance,
    required this.averagePerMember,
    required this.categoryTotals,
    required this.memberContributions,
    required this.topCategory,
    required this.topCategoryPercent,
    required this.outliers,
    required this.peakWeekday,
    required this.peakWeekdayTotal,
    required this.insightSummary,
  });

  final double total;
  final double personalBalance;
  final double averagePerMember;
  final Map<String, double> categoryTotals;
  final Map<String, double> memberContributions;
  final String? topCategory;
  final double topCategoryPercent;
  final List<ExpenseModel> outliers;
  final String? peakWeekday;
  final double peakWeekdayTotal;
  final String insightSummary;

  factory _GroupAnalytics.calculate({
    required GroupModel group,
    required List<ExpenseModel> expenses,
    required String? currentUid,
  }) {
    final total = expenses.fold<double>(
      0,
      (sum, expense) => sum + expense.amount,
    );
    final categoryTotals = <String, double>{};
    final memberTotals = <String, double>{
      for (final id in group.memberIds) id: 0,
    };
    final weekdayTotals = <int, double>{};

    for (final expense in expenses) {
      final category = expense.category.trim().isEmpty
          ? 'Otros'
          : expense.category.trim();
      categoryTotals.update(
        category,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
      for (final entry in expense.payments.entries) {
        memberTotals.update(
          entry.key,
          (value) => value + entry.value,
          ifAbsent: () => entry.value,
        );
      }
      weekdayTotals.update(
        expense.date.weekday,
        (value) => value + expense.amount,
        ifAbsent: () => expense.amount,
      );
    }

    final balances = FirestoreService().calculateBalances(
      group: group,
      expenses: expenses,
    );
    final personalBalance = balances
        .where((balance) => balance.uid == currentUid)
        .fold<double>(0, (sum, balance) => sum + balance.balance);
    final averagePerMember = group.memberIds.isEmpty
        ? 0.0
        : total / group.memberIds.length;

    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategory = sortedCategories.isEmpty
        ? null
        : sortedCategories.first.key;
    final topCategoryPercent = total <= 0 || sortedCategories.isEmpty
        ? 0.0
        : sortedCategories.first.value / total * 100;

    final averageExpense = expenses.isEmpty ? 0.0 : total / expenses.length;
    final outliers =
        averageExpense <= 0
              ? <ExpenseModel>[]
              : expenses
                    .where((expense) => expense.amount >= averageExpense * 2)
                    .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));
    final peakWeekdayEntry = weekdayTotals.entries.isEmpty
        ? null
        : weekdayTotals.entries.reduce(
            (first, second) => second.value > first.value ? second : first,
          );
    const weekdayNames = {
      DateTime.monday: 'lunes',
      DateTime.tuesday: 'martes',
      DateTime.wednesday: 'miércoles',
      DateTime.thursday: 'jueves',
      DateTime.friday: 'viernes',
      DateTime.saturday: 'sábado',
      DateTime.sunday: 'domingo',
    };
    final peakWeekday = peakWeekdayEntry == null
        ? null
        : weekdayNames[peakWeekdayEntry.key];

    final insightSummary = expenses.isEmpty
        ? 'Cuando el grupo registre sus primeros gastos, aquí aparecerán patrones de consumo y actividad.'
        : _makeInsightSummary(
            total: total,
            expenses: expenses,
            topCategory: topCategory,
            topCategoryPercent: topCategoryPercent,
            peakWeekday: peakWeekday,
            outlierCount: outliers.length,
          );

    return _GroupAnalytics(
      total: total,
      personalBalance: personalBalance,
      averagePerMember: averagePerMember,
      categoryTotals: categoryTotals,
      memberContributions: memberTotals,
      topCategory: topCategory,
      topCategoryPercent: topCategoryPercent,
      outliers: outliers,
      peakWeekday: peakWeekday,
      peakWeekdayTotal: peakWeekdayEntry?.value ?? 0,
      insightSummary: insightSummary,
    );
  }
}

String _makeInsightSummary({
  required double total,
  required List<ExpenseModel> expenses,
  required String? topCategory,
  required double topCategoryPercent,
  required String? peakWeekday,
  required int outlierCount,
}) {
  final parts = <String>[
    'El grupo ha registrado ${expenses.length} ${expenses.length == 1 ? 'gasto' : 'gastos'} por un total de ${NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0).format(total)}.',
  ];
  if (topCategory != null) {
    parts.add(
      '$topCategory concentra el mayor gasto (${topCategoryPercent.toStringAsFixed(0)}% del total).',
    );
  }
  if (peakWeekday != null) {
    parts.add('El mayor flujo de dinero ocurre los $peakWeekday.');
  }
  if (outlierCount > 0) {
    parts.add(
      '${outlierCount == 1 ? 'Se detectó un gasto' : 'Se detectaron $outlierCount gastos'} atípico${outlierCount == 1 ? '' : 's'} (al menos el doble del promedio por gasto).',
    );
  } else {
    parts.add('No se detectan gastos que superen el doble del promedio.');
  }
  return parts.join(' ');
}

class _AnalyticsHeader extends StatelessWidget {
  const _AnalyticsHeader({required this.groupName, required this.expenseCount});

  final String groupName;
  final int expenseCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
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
            top: -54,
            child: Container(
              width: 156,
              height: 156,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.09),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 68,
            bottom: -72,
            child: Container(
              width: 124,
              height: 124,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Text(
                      'ANALÍTICA DEL GRUPO',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
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
                const SizedBox(height: 7),
                Text(
                  'Indicadores y patrones basados en los gastos registrados.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.17),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.receipt_long_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 7),
                      Text(
                        '$expenseCount ${expenseCount == 1 ? 'gasto registrado' : 'gastos registrados'}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.width,
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final double width;
  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      height: 96,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1,
        shadowColor: const Color(0xFF173B75).withValues(alpha: 0.07),
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: accent.withValues(alpha: 0.22)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF687C8D),
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (value.startsWith('\$'))
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          value,
                          maxLines: 1,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      )
                    else
                      Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                          height: 1.15,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
    final colors = theme.colorScheme;
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
                style: theme.textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF173B75),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeading(title: title, subtitle: subtitle, icon: icon),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _CategoryChartCard extends StatelessWidget {
  const _CategoryChartCard({
    required this.categories,
    required this.total,
    required this.touchedIndex,
    required this.currencyFormat,
    required this.onTouched,
  });

  final Map<String, double> categories;
  final double total;
  final int touchedIndex;
  final NumberFormat currencyFormat;
  final ValueChanged<int> onTouched;

  static const _palette = [
    Color(0xFF087F8C),
    Color(0xFF2457C5),
    Color(0xFF54A6C7),
    Color(0xFF3B82A0),
    Color(0xFF176B87),
    Color(0xFF6FB8C7),
    Color(0xFF3D7191),
    Color(0xFF8ACAD5),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final entries = categories.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final sections = entries.asMap().entries.map((indexedEntry) {
      final index = indexedEntry.key;
      final entry = indexedEntry.value;
      final isTouched = index == touchedIndex;
      return PieChartSectionData(
        color: _palette[index % _palette.length],
        value: entry.value,
        title: total <= 0
            ? ''
            : '${(entry.value / total * 100).toStringAsFixed(0)}%',
        radius: isTouched ? 62 : 52,
        titleStyle: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
        titlePositionPercentageOffset: 0.58,
      );
    }).toList();

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: const Color(0xFF173B75).withValues(alpha: 0.06),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFDCE8EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            SizedBox(
              height: 210,
              child: entries.isEmpty || total <= 0
                  ? _ChartEmptyState(label: 'Aún no hay datos por categoría')
                  : PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            final index =
                                response?.touchedSection?.touchedSectionIndex ??
                                -1;
                            onTouched(index);
                          },
                        ),
                        sections: sections,
                        sectionsSpace: 3,
                        centerSpaceRadius: 58,
                        startDegreeOffset: -90,
                      ),
                    ),
            ),
            if (entries.isNotEmpty) ...[
              const SizedBox(height: 8),
              ...entries.asMap().entries.map((entry) {
                final index = entry.key;
                final category = entry.value;
                final percentage = total <= 0
                    ? 0.0
                    : category.value / total * 100;
                final isSelected = touchedIndex == index;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onTouched(isSelected ? -1 : index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: _palette[index % _palette.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              category.key,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 96,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    currencyFormat.format(category.value),
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Text(
                                  '${percentage.toStringAsFixed(1)}%',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

class _MemberContributionCard extends StatelessWidget {
  const _MemberContributionCard({
    required this.contributions,
    required this.memberNames,
    required this.memberPhotoUrls,
    required this.currencyFormat,
  });

  final Map<String, double> contributions;
  final Map<String, String> memberNames;
  final Future<Map<String, String>> memberPhotoUrls;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final entries = contributions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxValue = entries.fold<double>(
      0,
      (maximum, entry) => math.max(maximum, entry.value),
    );
    final chartMaxY = maxValue <= 0 ? 1.0 : maxValue * 1.2;
    final axisInterval = maxValue <= 0 ? 1.0 : chartMaxY / 4;
    final barColor = colors.primary;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: const Color(0xFF173B75).withValues(alpha: 0.06),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFDCE8EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
        child: entries.isEmpty
            ? const SizedBox(
                height: 230,
                child: _ChartEmptyState(label: 'No hay aportes registrados'),
              )
            : Column(
                children: [
                  SizedBox(
                    height: 220,
                    child: BarChart(
                      BarChartData(
                        maxY: chartMaxY,
                        alignment: BarChartAlignment.spaceAround,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final entry = entries[group.x];
                              return BarTooltipItem(
                                '${memberNames[entry.key] ?? 'Usuario'}\n${currencyFormat.format(entry.value)}',
                                theme.textTheme.labelMedium!.copyWith(
                                  color: colors.onInverseSurface,
                                  fontWeight: FontWeight.w700,
                                ),
                              );
                            },
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: axisInterval,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: const Color(0xFFDCE8EF),
                            strokeWidth: 1,
                            dashArray: [4, 4],
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 54,
                              interval: axisInterval,
                              getTitlesWidget: (value, meta) {
                                if (value >= chartMaxY - axisInterval * 0.2) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Text(
                                    _compactCurrency(value),
                                    textAlign: TextAlign.right,
                                    maxLines: 1,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 42,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= entries.length) {
                                  return const SizedBox.shrink();
                                }
                                final name =
                                    memberNames[entries[index].key] ??
                                    'Usuario';
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    top: 6,
                                    left: 2,
                                    right: 2,
                                  ),
                                  child: SizedBox(
                                    width: entries.length > 5 ? 48 : 68,
                                    child: Text(
                                      name,
                                      maxLines: 2,
                                      softWrap: true,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.labelSmall
                                          ?.copyWith(
                                            color: colors.onSurfaceVariant,
                                            fontSize: 9,
                                            height: 1.05,
                                          ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        barGroups: entries.asMap().entries.map((indexed) {
                          final index = indexed.key;
                          final entry = indexed.value;
                          return BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value,
                                width: entries.length > 8 ? 14 : 22,
                                color: barColor,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(7),
                                ),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: chartMaxY,
                                  color: const Color(0xFFEAF4FB),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          FutureBuilder<Map<String, String>>(
                            future: memberPhotoUrls,
                            builder: (context, snapshot) => PersonAvatar(
                              name: memberNames[entry.key] ?? 'Usuario',
                              photoSource: snapshot.data?[entry.key],
                              radius: 13,
                              backgroundColor: colors.primaryContainer,
                              foregroundColor: colors.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              memberNames[entry.key] ?? 'Usuario',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                          Text(
                            currencyFormat.format(entry.value),
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.analytics, required this.currencyFormat});

  final _GroupAnalytics analytics;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: const Color(0xFF173B75).withValues(alpha: 0.06),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFDCE8EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F3F8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.lightbulb_outline_rounded,
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      analytics.insightSummary,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.45,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (analytics.peakWeekday != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5FAFD),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFDCE8EF)),
                ),
                child: _InsightRow(
                  icon: Icons.calendar_view_week_rounded,
                  label: 'Día con mayor flujo',
                  value:
                      '${_capitalize(analytics.peakWeekday!)} · ${currencyFormat.format(analytics.peakWeekdayTotal)}',
                  color: colors.primary,
                ),
              ),
            ],
            if (analytics.outliers.isNotEmpty) ...[
              const SizedBox(height: 14),
              _InsightRow(
                icon: Icons.trending_up_rounded,
                label: 'Gastos atípicos',
                value: '${analytics.outliers.length} detectado(s)',
                color: colors.error,
              ),
              const SizedBox(height: 9),
              ...analytics.outliers
                  .take(3)
                  .map(
                    (expense) => Padding(
                      padding: const EdgeInsets.only(left: 34, top: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              expense.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            currencyFormat.format(expense.amount),
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ChartEmptyState extends StatelessWidget {
  const _ChartEmptyState({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insert_chart_outlined_rounded,
            size: 42,
            color: colors.outline,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

String _compactCurrency(double value) {
  if (value >= 1000000) {
    return '\$${(value / 1000000).toStringAsFixed(1)}M';
  }
  if (value >= 1000) {
    final thousands = value / 1000;
    final formatted = thousands.toStringAsFixed(thousands >= 10 ? 0 : 1);
    return '\$${formatted.endsWith('.0') ? formatted.substring(0, formatted.length - 2) : formatted}k';
  }
  return '\$${value.toStringAsFixed(0)}';
}

String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
