import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../services/firestore_service.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Analítica financiera'),
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
                  final contentWidth = constraints.maxWidth - 48;
                  final kpiColumns = contentWidth >= 900
                      ? 4
                      : contentWidth >= 560
                      ? 2
                      : 1;
                  final kpiGap = 12.0;
                  final kpiWidth =
                      (contentWidth - (kpiGap * (kpiColumns - 1))) / kpiColumns;
                  final chartsSideBySide = contentWidth >= 760;

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    children: [
                      Text(
                        widget.group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Indicadores y patrones basados en los gastos registrados.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
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
                            accent: const Color(0xFF6750A4),
                          ),
                          _KpiCard(
                            width: kpiWidth,
                            icon: Icons.pie_chart_outline_rounded,
                            label: 'Mayor categoría',
                            value: analytics.topCategory == null
                                ? 'Sin datos'
                                : '${analytics.topCategory} · ${analytics.topCategoryPercent.toStringAsFixed(0)}%',
                            accent: const Color(0xFFB85C38),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
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
                                  contributions:
                                      analytics.memberContributions,
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
                            currencyFormat: _currencyFormat,
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
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
    final colors = theme.colorScheme;
    return SizedBox(
      width: width,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 1,
        shadowColor: colors.shadow.withValues(alpha: 0.06),
        color: colors.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(height: 13),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
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
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: colors.onPrimaryContainer, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
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
    Color(0xFF6750A4),
    Color(0xFFB85C38),
    Color(0xFF3B6B57),
    Color(0xFF4267A8),
    Color(0xFF9A4775),
    Color(0xFF8A6D1D),
    Color(0xFF53717A),
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
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            SizedBox(
              height: 230,
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
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onTouched(isSelected ? -1 : index),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 5,
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
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            currencyFormat.format(category.value),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
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
    required this.currencyFormat,
  });

  final Map<String, double> contributions;
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
    final barColor = colors.primary;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 18, 18, 14),
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
                        maxY: maxValue <= 0 ? 1 : maxValue * 1.2,
                        alignment: BarChartAlignment.spaceAround,
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final entry = entries[group.x];
                              return BarTooltipItem(
                                '${entry.key}\n${currencyFormat.format(entry.value)}',
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
                          horizontalInterval: maxValue <= 0 ? 1 : maxValue / 4,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: colors.outlineVariant.withValues(alpha: 0.5),
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
                              reservedSize: 48,
                              getTitlesWidget: (value, meta) => Text(
                                _compactCurrency(value),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 36,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();
                                if (index < 0 || index >= entries.length) {
                                  return const SizedBox.shrink();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _shortName(entries[index].key),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 10,
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
                                  toY: maxValue <= 0 ? 1 : maxValue * 1.2,
                                  color: colors.surfaceContainerHighest
                                      .withValues(alpha: 0.55),
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
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: colors.primaryContainer,
                            child: Text(
                              entry.key.trim().isEmpty
                                  ? '?'
                                  : entry.key
                                        .trim()
                                        .characters
                                        .first
                                        .toUpperCase(),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: colors.onPrimaryContainer,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              entry.key,
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
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6750A4).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Color(0xFF6750A4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    analytics.insightSummary,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                  ),
                ),
              ],
            ),
            if (analytics.peakWeekday != null) ...[
              const SizedBox(height: 18),
              _InsightRow(
                icon: Icons.calendar_view_week_rounded,
                label: 'Día con mayor flujo',
                value:
                    '${_capitalize(analytics.peakWeekday!)} · ${currencyFormat.format(analytics.peakWeekdayTotal)}',
                color: colors.primary,
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
  if (value >= 1000000) return '\$${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '\$${(value / 1000).toStringAsFixed(0)}k';
  return '\$${value.toStringAsFixed(0)}';
}

String _shortName(String name) {
  final trimmed = name.trim();
  if (trimmed.length <= 9) return trimmed;
  return '${trimmed.substring(0, 8)}…';
}

String _capitalize(String value) =>
    value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
