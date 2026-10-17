import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../services/firestore_service.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';

/// Pantalla principal tras el login: lista de grupos del usuario (H.4)
class GroupsListScreen extends StatefulWidget {
  const GroupsListScreen({super.key});

  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> {
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  Stream<List<GroupModel>>? _groupsStream;
  String? _streamUid;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sesión no iniciada')));
    }
    if (_streamUid != uid || _groupsStream == null) {
      _streamUid = uid;
      _groupsStream = _firestoreService.watchUserGroups(uid);
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final displayName = user?.displayName?.trim();
    final greetingName = displayName != null && displayName.isNotEmpty
        ? displayName.split(' ').first
        : 'de nuevo';

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 20,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 20,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'SplitEasy',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Perfil y configuración',
            icon: CircleAvatar(
              radius: 17,
              backgroundColor: colors.secondaryContainer,
              child: Icon(
                Icons.person_outline_rounded,
                size: 20,
                color: colors.onSecondaryContainer,
              ),
            ),
            onSelected: (value) {
              if (value == 'sign_out') {
                FirebaseAuth.instance.signOut();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: SizedBox(
                  width: 210,
                  child: Text(
                    user?.email ?? 'Cuenta SplitEasy',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'sign_out',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 20),
                    SizedBox(width: 12),
                    Text('Cerrar sesión'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<GroupModel>>(
        stream: _groupsStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'No se pudieron cargar tus grupos.\n${snapshot.error}',
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

          final groups = snapshot.data!;
          final filteredGroups = groups.where((group) {
            return group.name.toLowerCase().contains(
              _searchQuery.trim().toLowerCase(),
            );
          }).toList();

          return _GroupsDashboard(
            groups: groups,
            visibleGroups: filteredGroups,
            uid: uid,
            greetingName: greetingName,
            searchController: _searchController,
            showSearch: groups.length > 2,
            onSearchChanged: (value) {
              setState(() => _searchQuery = value);
            },
            onCreateGroup: _openCreateGroup,
            onGroupTap: (group) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => GroupDetailScreen(group: group),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo grupo'),
        onPressed: _openCreateGroup,
      ),
    );
  }

  void _openCreateGroup() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
  }
}

class _GroupsDashboard extends StatefulWidget {
  const _GroupsDashboard({
    required this.groups,
    required this.visibleGroups,
    required this.uid,
    required this.greetingName,
    required this.searchController,
    required this.showSearch,
    required this.onSearchChanged,
    required this.onCreateGroup,
    required this.onGroupTap,
  });

  final List<GroupModel> groups;
  final List<GroupModel> visibleGroups;
  final String uid;
  final String greetingName;
  final TextEditingController searchController;
  final bool showSearch;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onCreateGroup;
  final ValueChanged<GroupModel> onGroupTap;

  @override
  State<_GroupsDashboard> createState() => _GroupsDashboardState();
}

class _GroupsDashboardState extends State<_GroupsDashboard> {
  final _firestoreService = FirestoreService();
  final Map<String, StreamSubscription<List<ExpenseModel>>> _subscriptions = {};
  final Map<String, double?> _groupBalances = {};
  final Map<String, Object> _groupErrors = {};
  final Map<String, List<ExpenseModel>> _latestExpenses = {};
  late final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'es_CL',
    symbol: '\$',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    _syncExpenseStreams();
  }

  @override
  void didUpdateWidget(covariant _GroupsDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.groups != widget.groups || oldWidget.uid != widget.uid) {
      _syncExpenseStreams();
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    super.dispose();
  }

  void _syncExpenseStreams() {
    final currentIds = widget.groups.map((group) => group.id).toSet();
    for (final groupId in _subscriptions.keys.toList()) {
      if (!currentIds.contains(groupId)) {
        _subscriptions.remove(groupId)?.cancel();
        _groupBalances.remove(groupId);
        _groupErrors.remove(groupId);
        _latestExpenses.remove(groupId);
      }
    }

    for (final group in widget.groups) {
      if (_subscriptions.containsKey(group.id)) {
        final expenses = _latestExpenses[group.id];
        if (expenses != null) {
          _groupBalances[group.id] = _calculateUserBalance(group.id, expenses);
        }
        continue;
      }
      _groupBalances[group.id] = null;
      _subscriptions[group.id] = _firestoreService
          .watchGroupExpenses(group.id)
          .listen(
            (expenses) {
              if (!widget.groups.any((item) => item.id == group.id)) return;
              final balance = _calculateUserBalance(group.id, expenses);
              if (!mounted) return;
              setState(() {
                _latestExpenses[group.id] = expenses;
                _groupBalances[group.id] = balance;
                _groupErrors.remove(group.id);
              });
            },
            onError: (Object error) {
              if (!widget.groups.any((item) => item.id == group.id)) return;
              if (!mounted) return;
              setState(() {
                _groupErrors[group.id] = error;
                _groupBalances[group.id] = null;
              });
            },
          );
    }
    if (mounted) setState(() {});
  }

  double _calculateUserBalance(String groupId, List<ExpenseModel> expenses) {
    final group = widget.groups.firstWhere((item) => item.id == groupId);
    for (final balance in _firestoreService.calculateBalances(
      group: group,
      expenses: expenses,
    )) {
      if (balance.uid == widget.uid) return balance.balance;
    }
    return 0;
  }

  double get _combinedBalance => _groupBalances.values.whereType<double>().fold(
    0,
    (sum, value) => sum + value,
  );

  bool get _hasBalanceError => _groupErrors.isNotEmpty;

  bool get _allBalancesLoaded =>
      widget.groups.every((group) => _groupBalances[group.id] != null);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasGroups = widget.groups.isNotEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 112),
          children: [
            Text(
              'Hola, ${widget.greetingName}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.7,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tu panorama compartido, claro y al día.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 22),
            _FinancialSummaryCard(
              groupCount: widget.groups.length,
              balance: _combinedBalance,
              isLoading: hasGroups && !_allBalancesLoaded && !_hasBalanceError,
              hasError: _hasBalanceError,
              currencyFormat: _currencyFormat,
            ),
            const SizedBox(height: 30),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mis grupos',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (hasGroups)
                  Text(
                    '${widget.groups.length}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            if (widget.showSearch) ...[
              const SizedBox(height: 14),
              TextField(
                controller: widget.searchController,
                onChanged: widget.onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar grupo',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: widget.searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Limpiar búsqueda',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            widget.searchController.clear();
                            widget.onSearchChanged('');
                          },
                        ),
                  filled: true,
                  fillColor: colors.surfaceContainerLow,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            if (!hasGroups)
              _EmptyGroupsState(onCreateGroup: widget.onCreateGroup)
            else if (widget.visibleGroups.isEmpty)
              _NoSearchResults(query: widget.searchController.text)
            else
              ...widget.visibleGroups.map(
                (group) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _GroupCard(
                    group: group,
                    balance: _groupBalances[group.id],
                    hasBalanceError: _groupErrors.containsKey(group.id),
                    currencyFormat: _currencyFormat,
                    onTap: () => widget.onGroupTap(group),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FinancialSummaryCard extends StatelessWidget {
  const _FinancialSummaryCard({
    required this.groupCount,
    required this.balance,
    required this.isLoading,
    required this.hasError,
    required this.currencyFormat,
  });

  final int groupCount;
  final double balance;
  final bool isLoading;
  final bool hasError;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final positive = balance > 0.01;
    final negative = balance < -0.01;
    final balanceColor = positive
        ? const Color(0xFFB8F2D1)
        : negative
        ? const Color(0xFFFFC5C5)
        : colors.onPrimary;
    final balanceLabel = hasError
        ? 'Balance global'
        : positive
        ? 'Te deben'
        : negative
        ? 'Debes'
        : 'Balance neto';
    final balanceValue = isLoading
        ? 'Calculando…'
        : hasError
        ? 'No disponible'
        : currencyFormat.format(balance.abs());

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colors.primary,
            Color.lerp(colors.primary, colors.tertiary, 0.36)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  label: 'GRUPOS ACTIVOS',
                  value: '$groupCount',
                  detail: groupCount == 1
                      ? 'grupo compartido'
                      : 'grupos compartidos',
                  textColor: colors.onPrimary,
                  mutedColor: colors.onPrimary.withValues(alpha: 0.76),
                ),
              ),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colors.onPrimary.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.groups_2_rounded,
                  color: colors.onPrimary,
                  size: 25,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Divider(
              color: colors.onPrimary.withValues(alpha: 0.2),
              height: 1,
            ),
          ),
          _SummaryMetric(
            label: balanceLabel.toUpperCase(),
            value: balanceValue,
            detail: hasError
                ? 'No fue posible actualizar todos los balances'
                : 'Balance neto combinado de tus grupos',
            textColor: balanceColor,
            mutedColor: colors.onPrimary.withValues(alpha: 0.76),
            valueStyle: theme.textTheme.headlineSmall?.copyWith(
              color: balanceColor,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
            leadingIcon: negative
                ? Icons.south_west_rounded
                : positive
                ? Icons.north_east_rounded
                : Icons.account_balance_wallet_outlined,
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.value,
    required this.detail,
    required this.textColor,
    required this.mutedColor,
    this.valueStyle,
    this.leadingIcon,
  });

  final String label;
  final String value;
  final String detail;
  final Color textColor;
  final Color mutedColor;
  final TextStyle? valueStyle;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: mutedColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            if (leadingIcon != null) ...[
              Icon(leadingIcon, size: 21, color: textColor),
              const SizedBox(width: 7),
            ],
            Flexible(
              child: Text(
                value,
                overflow: TextOverflow.ellipsis,
                style:
                    valueStyle ??
                    theme.textTheme.headlineLarge?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          detail,
          style: theme.textTheme.bodySmall?.copyWith(color: mutedColor),
        ),
      ],
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.balance,
    required this.hasBalanceError,
    required this.currencyFormat,
    required this.onTap,
  });

  final GroupModel group;
  final double? balance;
  final bool hasBalanceError;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final groupColor = _colorForGroup(group.name);
    final initials = _initialsFor(group.name);
    final memberCount = group.memberIds.length;
    final positive = (balance ?? 0) > 0.01;
    final negative = (balance ?? 0) < -0.01;
    final badgeColor = hasBalanceError
        ? colors.error
        : positive
        ? const Color(0xFF19734A)
        : negative
        ? const Color(0xFFB3261E)
        : const Color(0xFF426B5A);
    final badgeBackground = badgeColor.withValues(alpha: 0.1);
    final status = hasBalanceError
        ? 'No disponible'
        : balance == null
        ? 'Calculando'
        : positive
        ? 'Te deben ${currencyFormat.format(balance!)}'
        : negative
        ? 'Debes ${currencyFormat.format(balance!.abs())}'
        : 'Al día';

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: colors.shadow.withValues(alpha: 0.08),
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
                radius: 25,
                backgroundColor: groupColor.withValues(alpha: 0.13),
                child: Text(
                  initials,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: groupColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$memberCount integrante${memberCount == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 168),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBackground,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: badgeColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 15,
                color: colors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyGroupsState extends StatelessWidget {
  const _EmptyGroupsState({required this.onCreateGroup});

  final VoidCallback onCreateGroup;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 30),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: colors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.group_add_rounded,
              size: 46,
              color: colors.onSecondaryContainer,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Aún no participas en ningún grupo',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            'Crea tu primer grupo para compartir gastos y mantener las cuentas claras.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onCreateGroup,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Crear mi primer grupo'),
          ),
        ],
      ),
    );
  }
}

class _NoSearchResults extends StatelessWidget {
  const _NoSearchResults({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 38, color: colors.outline),
          const SizedBox(height: 10),
          Text(
            'No encontramos grupos con “$query”.',
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

String _initialsFor(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty);
  final parts = words.take(2).toList();
  if (parts.isEmpty) return '?';
  return parts.map((word) => word.characters.first.toUpperCase()).join();
}

Color _colorForGroup(String name) {
  const palette = [
    Color(0xFF087F8C),
    Color(0xFF6750A4),
    Color(0xFFB85C38),
    Color(0xFF3B6B57),
    Color(0xFF4267A8),
    Color(0xFF9A4775),
    Color(0xFF8A6D1D),
    Color(0xFF53717A),
  ];
  var hash = 0;
  for (final unit in name.toLowerCase().codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return palette[hash % palette.length];
}
