import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../services/firestore_service.dart';
import 'assistant_chat_screen.dart';
import 'add_expense_screen.dart';
import 'create_group_screen.dart';
import 'group_detail_screen.dart';
import 'profile_screen.dart';
import '../widgets/profile_photo_image.dart';
import '../widgets/main_navigation_bar.dart';

/// Pantalla principal tras el login: lista de grupos del usuario (H.4)
class GroupsListScreen extends StatefulWidget {
  const GroupsListScreen({super.key});

  @override
  State<GroupsListScreen> createState() => _GroupsListScreenState();
}

class _GroupsListScreenState extends State<GroupsListScreen> {
  final _firestoreService = FirestoreService();
  Stream<List<GroupModel>>? _groupsStream;
  String? _streamUid;
  String? _photoUid;
  Future<String?>? _userPhotoFuture;
  List<GroupModel> _currentGroups = const [];

  Future<String?> _loadUserPhoto(String uid) {
    if (_photoUid != uid || _userPhotoFuture == null) {
      _photoUid = uid;
      _userPhotoFuture = _firestoreService.getUserPhoto(uid);
    }
    return _userPhotoFuture!;
  }

  Future<void> _openProfile() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen()));
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !mounted) return;
    setState(() {
      _photoUid = null;
      _userPhotoFuture = null;
      _loadUserPhoto(uid);
    });
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
      backgroundColor: const Color(0xFFEAF4FB),
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

          _currentGroups = snapshot.data!;
          return _GroupsDashboard(
            groups: _currentGroups,
            uid: uid,
            greetingName: greetingName,
            userEmail: user?.email ?? '',
            onSignOut: () => FirebaseAuth.instance.signOut(),
            onHomeTap: _openHome,
            onAssistantTap: _openAssistant,
            onProfileTap: _openProfile,
            profilePhotoFuture: _loadUserPhoto(uid),
            onCreateGroup: _openCreateGroup,
            onAddExpenseTap: _addExpense,
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
      bottomNavigationBar: MainNavigationBar(
        onHomeTap: _openHome,
        onGroupsTap: _openGroups,
        onAssistantTap: _openAssistant,
        onProfileTap: _openProfile,
        profilePhotoFuture: _loadUserPhoto(uid),
        onCreateGroupTap: _openCreateGroup,
        onAddExpenseTap: _addExpense,
      ),
    );
  }

  Future<void> _openAssistant() {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AssistantChatScreen()),
    );
  }

  Future<void> _openCreateGroup() {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CreateGroupScreen()));
  }

  void _openHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _openGroups() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _GroupsGridScreen(
          groups: _currentGroups,
          balances: const {},
          groupErrors: const {},
          currencyFormat: NumberFormat.currency(
            locale: 'es_CL',
            symbol: '\$',
            decimalDigits: 0,
          ),
          onCreateGroup: _openCreateGroup,
          onHomeTap: _openHome,
          onAssistantTap: _openAssistant,
          onProfileTap: _openProfile,
          profilePhotoFuture: _loadUserPhoto(uid),
          onAddExpenseTap: _addExpense,
          onGroupTap: (group) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GroupDetailScreen(group: group),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _addExpense() async {
    final group = await _selectExpenseGroup(context, _currentGroups);
    if (group == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AddExpenseScreen(group: group)),
    );
  }
}

Future<GroupModel?> _selectExpenseGroup(
  BuildContext context,
  List<GroupModel> groups,
) async {
  if (groups.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Primero debes crear o unirte a un grupo.')),
    );
    return null;
  }
  return showModalBottomSheet<GroupModel>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Text(
              'Selecciona un grupo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          ...groups.map(
            (group) => ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE7F3F8),
                child: Icon(Icons.groups_rounded, color: Color(0xFF087F8C)),
              ),
              title: Text(group.name),
              subtitle: Text(
                '${group.memberIds.length} integrante${group.memberIds.length == 1 ? '' : 's'}',
              ),
              onTap: () => Navigator.of(context).pop(group),
            ),
          ),
        ],
      ),
    ),
  );
}

class _RecentGroupExpense {
  const _RecentGroupExpense({required this.group, required this.expense});

  final GroupModel group;
  final ExpenseModel expense;
}

class _MainHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 64)
      ..cubicTo(
        size.width * 0.76,
        size.height - 2,
        size.width * 0.64,
        size.height - 10,
        0,
        size.height - 76,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _GroupGridHeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height - 24)
      ..cubicTo(
        size.width * 0.91,
        size.height - 38,
        size.width * 0.84,
        size.height - 4,
        size.width * 0.75,
        size.height - 12,
      )
      ..cubicTo(
        size.width * 0.66,
        size.height - 22,
        size.width * 0.59,
        size.height - 32,
        size.width * 0.5,
        size.height - 20,
      )
      ..cubicTo(
        size.width * 0.4,
        size.height - 5,
        size.width * 0.33,
        size.height - 5,
        size.width * 0.25,
        size.height - 15,
      )
      ..cubicTo(
        size.width * 0.16,
        size.height - 28,
        size.width * 0.08,
        size.height - 38,
        0,
        size.height - 24,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _RecentActivityPlaceholder extends StatelessWidget {
  const _RecentActivityPlaceholder({required this.hasGroups});

  final bool hasGroups;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFFE7F3F8),
            child: Icon(Icons.receipt_long_rounded, color: Color(0xFF087F8C)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasGroups
                  ? 'Tus movimientos aparecerán aquí'
                  : 'Crea o únete a un grupo para ver tus movimientos',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF586B7A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupsGridScreen extends StatefulWidget {
  const _GroupsGridScreen({
    required this.groups,
    required this.balances,
    required this.groupErrors,
    required this.currencyFormat,
    required this.onCreateGroup,
    required this.onHomeTap,
    required this.onAssistantTap,
    required this.onProfileTap,
    required this.profilePhotoFuture,
    required this.onAddExpenseTap,
    required this.onGroupTap,
  });

  final List<GroupModel> groups;
  final Map<String, double?> balances;
  final Set<String> groupErrors;
  final NumberFormat currencyFormat;
  final VoidCallback onCreateGroup;
  final VoidCallback onHomeTap;
  final VoidCallback onAssistantTap;
  final VoidCallback onProfileTap;
  final Future<String?> profilePhotoFuture;
  final VoidCallback onAddExpenseTap;
  final ValueChanged<GroupModel> onGroupTap;

  @override
  State<_GroupsGridScreen> createState() => _GroupsGridScreenState();
}

class _GroupsGridScreenState extends State<_GroupsGridScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _createGroup() {
    Navigator.of(context).pop();
    widget.onCreateGroup();
  }

  @override
  Widget build(BuildContext context) {
    final groups = widget.groups
        .where(
          (group) =>
              group.name.toLowerCase().contains(_query.trim().toLowerCase()),
        )
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEAF4FB),
        surfaceTintColor: Colors.transparent,
        title: const Text('Mis grupos'),
      ),
      body: Column(
        children: [
          if (widget.groups.length > 2)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Buscar grupo',
                  prefixIcon: const Icon(Icons.search_rounded),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          Expanded(
            child: groups.isEmpty
                ? widget.groups.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: _EmptyGroupsState(
                              onCreateGroup: _createGroup,
                            ),
                          ),
                        )
                      : Center(child: _NoSearchResults(query: _query))
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = switch (constraints.maxWidth) {
                        >= 760 => 4,
                        >= 540 => 3,
                        _ => 2,
                      };
                      return GridView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.94,
                        ),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return _GroupGridCard(
                            group: group,
                            balance: widget.balances[group.id],
                            hasBalanceError: widget.groupErrors.contains(
                              group.id,
                            ),
                            currencyFormat: widget.currencyFormat,
                            onTap: () => widget.onGroupTap(group),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: MainNavigationBar(
        onHomeTap: widget.onHomeTap,
        onGroupsTap: null,
        onAssistantTap: widget.onAssistantTap,
        onCreateGroupTap: _createGroup,
        onAddExpenseTap: widget.onAddExpenseTap,
        onProfileTap: widget.onProfileTap,
        profilePhotoFuture: widget.profilePhotoFuture,
      ),
    );
  }
}

class _GroupGridCard extends StatelessWidget {
  const _GroupGridCard({
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
    final accent = _colorForGroup(group.name);
    final balanceText = hasBalanceError
        ? 'Balance no disponible'
        : balance == null
        ? 'Calculando balance'
        : balance! > 0.01
        ? 'Te deben ${currencyFormat.format(balance!)}'
        : balance! < -0.01
        ? 'Debes ${currencyFormat.format(balance!.abs())}'
        : 'Al día';
    final initials = _initialsFor(group.name);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: accent.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: ClipPath(
                    clipper: _GroupGridHeaderClipper(),
                    child: Container(
                      width: double.infinity,
                      color: accent.withValues(alpha: 0.18),
                      alignment: Alignment.center,
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(21),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: group.photoSource == null
                            ? Center(
                                child: Text(
                                  initials,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: accent,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              )
                            : ProfilePhotoImage(
                                source: group.photoSource!,
                                fallback: Center(
                                  child: Text(
                                    initials,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          color: accent,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF173B75),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${group.memberIds.length} integrante${group.memberIds.length == 1 ? '' : 's'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                balanceText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: hasBalanceError ? colors.error : accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentExpenseTile extends StatelessWidget {
  const _RecentExpenseTile({
    required this.activity,
    required this.currencyFormat,
    required this.onTap,
  });

  final _RecentGroupExpense activity;
  final NumberFormat currencyFormat;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final date = DateFormat('dd MMM', 'es').format(activity.expense.date);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.45)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: const Color(0xFFE7F3F8),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 20,
                  color: Color(0xFF087F8C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      activity.expense.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: const Color(0xFF173B75),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${activity.group.name} · $date',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF687C8D),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                currencyFormat.format(activity.expense.amount),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: const Color(0xFF087F8C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupsDashboard extends StatefulWidget {
  const _GroupsDashboard({
    required this.groups,
    required this.uid,
    required this.greetingName,
    required this.userEmail,
    required this.onSignOut,
    required this.onHomeTap,
    required this.onAssistantTap,
    required this.onProfileTap,
    required this.profilePhotoFuture,
    required this.onCreateGroup,
    required this.onAddExpenseTap,
    required this.onGroupTap,
  });

  final List<GroupModel> groups;
  final String uid;
  final String greetingName;
  final String userEmail;
  final VoidCallback onSignOut;
  final VoidCallback onHomeTap;
  final VoidCallback onAssistantTap;
  final VoidCallback onProfileTap;
  final Future<String?> profilePhotoFuture;
  final VoidCallback onCreateGroup;
  final VoidCallback onAddExpenseTap;
  final ValueChanged<GroupModel> onGroupTap;

  @override
  State<_GroupsDashboard> createState() => _GroupsDashboardState();
}

class _GroupsDashboardState extends State<_GroupsDashboard> {
  final _firestoreService = FirestoreService();
  final _activitySheetController = DraggableScrollableController();
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
    _activitySheetController.dispose();
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

  void _openGroups() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _GroupsGridScreen(
          groups: widget.groups,
          balances: Map.unmodifiable(_groupBalances),
          groupErrors: Set.unmodifiable(_groupErrors.keys),
          currencyFormat: _currencyFormat,
          onCreateGroup: widget.onCreateGroup,
          onHomeTap: widget.onHomeTap,
          onAssistantTap: widget.onAssistantTap,
          onProfileTap: widget.onProfileTap,
          profilePhotoFuture: widget.profilePhotoFuture,
          onAddExpenseTap: widget.onAddExpenseTap,
          onGroupTap: widget.onGroupTap,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasGroups = widget.groups.isNotEmpty;
    final groupById = {for (final group in widget.groups) group.id: group};
    final recentExpenses =
        _latestExpenses.entries
            .where((entry) => groupById.containsKey(entry.key))
            .expand(
              (entry) => entry.value.map(
                (expense) => _RecentGroupExpense(
                  group: groupById[entry.key]!,
                  expense: expense,
                ),
              ),
            )
            .toList()
          ..sort((a, b) => b.expense.date.compareTo(a.expense.date));

    return LayoutBuilder(
      builder: (context, constraints) {
        final headerHeight = (constraints.maxHeight * 0.34)
            .clamp(210.0, 270.0)
            .toDouble();
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 880),
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: headerHeight,
                  child: ClipPath(
                    clipper: _MainHeaderClipper(),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 52),
                      alignment: Alignment.topCenter,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFF3B82B8), Color(0xFF69B8D0)],
                        ),
                      ),
                      child: SafeArea(
                        bottom: false,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 832),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.17,
                                      ),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Icon(
                                      Icons.account_balance_wallet_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  Expanded(
                                    child: Text(
                                      'SplitEasy',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    tooltip: 'Configuración',
                                    icon: const Icon(
                                      Icons.settings_outlined,
                                      color: Colors.white,
                                    ),
                                    onSelected: (value) {
                                      if (value == 'settings') {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Las opciones estarán disponibles pronto.',
                                            ),
                                          ),
                                        );
                                      } else if (value == 'sign_out') {
                                        widget.onSignOut();
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      PopupMenuItem<String>(
                                        enabled: false,
                                        child: SizedBox(
                                          width: 210,
                                          child: Text(
                                            widget.userEmail.isEmpty
                                                ? 'Cuenta SplitEasy'
                                                : widget.userEmail,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem<String>(
                                        value: 'settings',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.settings_outlined,
                                              size: 20,
                                            ),
                                            SizedBox(width: 12),
                                            Text('Configuración'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem<String>(
                                        value: 'sign_out',
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.logout_rounded,
                                              size: 20,
                                            ),
                                            SizedBox(width: 12),
                                            Text('Cerrar sesión'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              Text(
                                'Hola, ${widget.greetingName}',
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.7,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: headerHeight - 94,
                  left: 20,
                  right: 20,
                  child: _FinancialSummaryCard(
                    groupCount: widget.groups.length,
                    balance: _combinedBalance,
                    isLoading:
                        hasGroups && !_allBalancesLoaded && !_hasBalanceError,
                    hasError: _hasBalanceError,
                    currencyFormat: _currencyFormat,
                    onGroupsTap: _openGroups,
                  ),
                ),
                DraggableScrollableSheet(
                  controller: _activitySheetController,
                  initialChildSize: 0.34,
                  minChildSize: 0.2,
                  maxChildSize: 1,
                  snap: true,
                  snapSizes: const [0.34, 0.62, 1],
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FCFF),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF173B75,
                            ).withValues(alpha: 0.16),
                            blurRadius: 22,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: ListView(
                        controller: scrollController,
                        physics: const ClampingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                        children: [
                          Center(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => _activitySheetController.animateTo(
                                1,
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOutCubic,
                              ),
                              child: SizedBox(
                                width: 72,
                                height: 20,
                                child: Center(
                                  child: Container(
                                    width: 38,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFBACAD6),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Actividad reciente',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: const Color(0xFF173B75),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Text(
                                '${recentExpenses.length} movimientos',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (recentExpenses.isEmpty)
                            _RecentActivityPlaceholder(hasGroups: hasGroups)
                          else
                            ...recentExpenses
                                .take(30)
                                .map(
                                  (activity) => Padding(
                                    padding: const EdgeInsets.only(bottom: 9),
                                    child: _RecentExpenseTile(
                                      activity: activity,
                                      currencyFormat: _currencyFormat,
                                      onTap: () =>
                                          widget.onGroupTap(activity.group),
                                    ),
                                  ),
                                ),
                          const SizedBox(height: 12),
                          _PendingInvitationsSection(uid: widget.uid),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PendingInvitationsSection extends StatefulWidget {
  const _PendingInvitationsSection({required this.uid});

  final String uid;

  @override
  State<_PendingInvitationsSection> createState() =>
      _PendingInvitationsSectionState();
}

class _PendingInvitationsSectionState
    extends State<_PendingInvitationsSection> {
  final _firestoreService = FirestoreService();
  final Set<String> _respondingGroupIds = {};
  late Stream<List<GroupModel>> _invitationsStream;

  @override
  void initState() {
    super.initState();
    _invitationsStream = _firestoreService.watchPendingInvitations(widget.uid);
  }

  @override
  void didUpdateWidget(covariant _PendingInvitationsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _invitationsStream = _firestoreService.watchPendingInvitations(
        widget.uid,
      );
    }
  }

  Future<void> _respond(GroupModel group, {required bool accept}) async {
    if (!_respondingGroupIds.add(group.id)) return;
    setState(() {});

    try {
      await _firestoreService.respondToGroupInvitation(
        groupId: group.id,
        accept: accept,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'Te uniste al grupo "${group.name}".'
                : 'Invitación al grupo "${group.name}" rechazada.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo responder a la invitación: $error')),
      );
    } finally {
      _respondingGroupIds.remove(group.id);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return StreamBuilder<List<GroupModel>>(
      stream: _invitationsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Card(
            color: colors.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No se pudieron cargar las invitaciones: ${snapshot.error}',
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final invitations = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Invitaciones pendientes',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            ...invitations.map((group) {
              final isResponding = _respondingGroupIds.contains(group.id);
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: colors.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.group_add_outlined,
                            color: colors.onSecondaryContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              group.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colors.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (group.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          group.description,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSecondaryContainer,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (isResponding)
                        const LinearProgressIndicator()
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () => _respond(group, accept: false),
                              child: const Text('Rechazar'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: () => _respond(group, accept: true),
                              child: const Text('Aceptar'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            }),
          ],
        );
      },
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
    required this.onGroupsTap,
  });

  final int groupCount;
  final double balance;
  final bool isLoading;
  final bool hasError;
  final NumberFormat currencyFormat;
  final VoidCallback onGroupsTap;

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
        gradient: const LinearGradient(
          colors: [Color(0xFF12345B), Color(0xFF075A78)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF12345B).withValues(alpha: 0.24),
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
                  textColor: Colors.white,
                  mutedColor: Colors.white.withValues(alpha: 0.72),
                ),
              ),
              Semantics(
                button: true,
                label: 'Abrir mis grupos',
                child: Material(
                  color: const Color(0xFF16708D),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onGroupsTap,
                    child: const SizedBox(
                      width: 52,
                      height: 52,
                      child: Icon(
                        Icons.groups_2_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Divider(
              color: Colors.white.withValues(alpha: 0.2),
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
            mutedColor: Colors.white.withValues(alpha: 0.72),
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
