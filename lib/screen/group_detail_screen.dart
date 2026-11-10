import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../models/balance_model.dart';
import '../../services/firestore_service.dart';
import 'add_expense_screen.dart';
import 'assistant_chat_screen.dart';
import 'balance_screen.dart';
import 'chat_screen.dart';
import 'create_group_screen.dart';
import 'expense_detail_screen.dart';
import 'history_screen.dart';
import 'analytics_dashboard_screen.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';
import 'group_members_screen.dart';
import 'group_options_screen.dart';
import '../widgets/profile_photo_image.dart';
import '../widgets/main_navigation_bar.dart';

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

  bool _isDeletingGroup = false;
  Future<String?>? _userPhotoFuture;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userPhotoFuture = _firestoreService.getUserPhoto(user.uid);
    }
    // ignore: avoid_print
    print(
      'DEBUG: currentUid=${user?.uid}, groupCreatedBy=${widget.group.createdBy}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid.trim();
    final creatorId = widget.group.createdBy.trim();
    final canDeleteGroup =
        currentUserId != null &&
        currentUserId.isNotEmpty &&
        creatorId.isNotEmpty &&
        creatorId == currentUserId;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        title: Tooltip(
          message: 'Ver integrantes del grupo',
          child: InkWell(
            onTap: () =>
                _navigateTo(context, GroupMembersScreen(group: widget.group)),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 17,
                    backgroundColor: colors.primaryContainer,
                    child: widget.group.photoSource == null
                        ? Icon(
                            Icons.groups_rounded,
                            size: 19,
                            color: colors.onPrimaryContainer,
                          )
                        : ClipOval(
                            child: SizedBox.expand(
                              child: ProfilePhotoImage(
                                source: widget.group.photoSource!,
                                fallback: Icon(
                                  Icons.groups_rounded,
                                  size: 19,
                                  color: colors.onPrimaryContainer,
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, size: 20),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Opciones del grupo',
            icon: const Icon(Icons.settings_rounded),
            onPressed: _isDeletingGroup
                ? null
                : () => _navigateTo(
                    context,
                    GroupOptionsScreen(
                      group: widget.group,
                      canDeleteGroup: canDeleteGroup,
                      onAction: _handleGroupAction,
                    ),
                  ),
          ),
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
          final settlements = _firestoreService.simplifyDebts(memberBalances);
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
                    onDebtTap: () => _showDebtDetails(settlements, userId),
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.small(
            heroTag: 'group-chat',
            tooltip: 'Chat del grupo',
            backgroundColor: const Color(0xFF55D4F0),
            foregroundColor: const Color(0xFF12345B),
            onPressed: () =>
                _navigateTo(context, ChatScreen(group: widget.group)),
            child: const Icon(Icons.chat_bubble_rounded),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'invite-member',
            tooltip: 'Invitar integrante',
            backgroundColor: colors.secondaryContainer,
            foregroundColor: colors.onSecondaryContainer,
            onPressed: _showInviteMemberDialog,
            child: const Icon(Icons.person_add_alt_1_rounded),
          ),
        ],
      ),
      bottomNavigationBar: MainNavigationBar(
        onHomeTap: () =>
            Navigator.of(context).popUntil((route) => route.isFirst),
        onGroupsTap: () => Navigator.of(context).maybePop(),
        onAssistantTap: () => _navigateTo(context, const AssistantChatScreen()),
        onCreateGroupTap: () => _navigateTo(context, const CreateGroupScreen()),
        onAddExpenseTap: () =>
            _navigateTo(context, AddExpenseScreen(group: widget.group)),
        onProfileTap: _openProfile,
        profilePhotoFuture: _userPhotoFuture ?? Future<String?>.value(null),
      ),
    );
  }

  Future<void> _openProfile() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const ProfileScreen()));
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !mounted) return;
    setState(() {
      _userPhotoFuture = _firestoreService.getUserPhoto(uid);
    });
  }

  Future<void> _showDebtDetails(
    List<SettlementTransaction> settlements,
    String? userId,
  ) {
    final debts = settlements
        .where((settlement) => settlement.fromUid == userId)
        .toList();

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) {
        final theme = Theme.of(context);
        final colors = theme.colorScheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tus deudas',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'A quién debes y cuánto en ${widget.group.name}.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                if (debts.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'No tienes deudas pendientes en este grupo.',
                    ),
                  )
                else
                  ...debts.map(
                    (debt) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerHighest.withValues(
                          alpha: 0.7,
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(
                            0xFF49C7E8,
                          ).withValues(alpha: 0.18),
                          child: const Icon(
                            Icons.person_rounded,
                            color: Color(0xFF087F8C),
                          ),
                        ),
                        title: Text('Debes a ${debt.toName}'),
                        subtitle: const Text('Liquidación sugerida'),
                        trailing: Text(
                          _currencyFormat.format(debt.amount),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.primary,
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
    );
  }

  void _navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _handleGroupAction(GroupOptionsAction action) {
    switch (action) {
      case GroupOptionsAction.members:
        _navigateTo(context, GroupMembersScreen(group: widget.group));
      case GroupOptionsAction.inviteMember:
        _showInviteMemberDialog();
      case GroupOptionsAction.history:
        _navigateTo(context, HistoryScreen(group: widget.group));
      case GroupOptionsAction.chat:
        _navigateTo(context, ChatScreen(group: widget.group));
      case GroupOptionsAction.balance:
        _navigateTo(context, BalanceScreen(group: widget.group));
      case GroupOptionsAction.analytics:
        _navigateTo(context, AnalyticsDashboardScreen(group: widget.group));
      case GroupOptionsAction.reports:
        _navigateTo(context, ReportsScreen(group: widget.group));
      case GroupOptionsAction.delete:
        _confirmDeleteGroup();
    }
  }

  Future<void> _showInviteMemberDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) =>
          _InviteMemberDialog(onSubmit: _inviteMemberByEmail),
    );
  }

  Future<bool> _inviteMemberByEmail(
    String rawEmail,
    BuildContext dialogContext,
  ) async {
    final email = rawEmail.trim();
    if (email.isEmpty) {
      if (!mounted || !dialogContext.mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un correo electrónico.')),
      );
      return false;
    }

    try {
      final user = await _firestoreService.findUserByEmail(email);
      if (!mounted || !dialogContext.mounted) return false;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El usuario no está registrado en Split-Easy'),
          ),
        );
        return false;
      }

      final uid = user['uid'];
      if (uid is! String || uid.isEmpty) {
        throw StateError('El perfil encontrado no tiene un UID válido.');
      }
      final userEmail = user['email'] as String? ?? email;
      final memberName =
          user['displayName'] as String? ??
          user['name'] as String? ??
          userEmail;
      final invited = await _firestoreService.inviteMemberToGroup(
        groupId: widget.group.id,
        memberUid: uid,
        memberName: memberName,
      );

      if (!mounted || !dialogContext.mounted) return false;
      Navigator.of(dialogContext).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            invited
                ? 'Invitación enviada. El usuario debe aceptarla para unirse.'
                : 'Este usuario ya pertenece al grupo o tiene una invitación pendiente.',
          ),
        ),
      );
      return true;
    } catch (error) {
      if (!mounted || !dialogContext.mounted) return false;
      debugPrint(
        'Error al invitar integrante al grupo ${widget.group.id}: $error',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar la invitación: $error')),
      );
      return false;
    }
  }

  Future<void> _confirmDeleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Eliminar grupo'),
        content: const Text(
          'Esta acción eliminará permanentemente el grupo, sus gastos, '
          'propuestas, mensajes e historial. No se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para eliminar el grupo.'),
        ),
      );
      return;
    }

    setState(() => _isDeletingGroup = true);
    try {
      await _firestoreService.deleteGroup(groupId: widget.group.id);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      debugPrint(
        'Error al eliminar grupo ${widget.group.id}: '
        'code=${error.code}, message=${error.message}',
      );
      final message = error.code == 'permission-denied'
          ? 'Firestore rechazó la eliminación por permisos. '
                'Verifica las reglas publicadas y que seas el creador '
                '(código: ${error.code}).'
          : 'No se pudo eliminar el grupo '
                '(código: ${error.code}). ${error.message ?? 'Inténtalo de nuevo.'}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } on StateError {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo eliminar el grupo. Verifica que seas su creador e inténtalo de nuevo.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeletingGroup = false);
    }
  }
}

class _InviteMemberDialog extends StatefulWidget {
  const _InviteMemberDialog({required this.onSubmit});

  final Future<bool> Function(String email, BuildContext dialogContext)
  onSubmit;

  @override
  State<_InviteMemberDialog> createState() => _InviteMemberDialogState();
}

class _InviteMemberDialogState extends State<_InviteMemberDialog> {
  final _emailController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa un correo electrónico.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final shouldClose = await widget.onSubmit(_emailController.text, context);
    if (!mounted || shouldClose) return;
    setState(() => _isSubmitting = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Invitar integrante'),
      content: TextField(
        controller: _emailController,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        enabled: !_isSubmitting,
        decoration: const InputDecoration(
          labelText: 'Correo electrónico',
          hintText: 'nombre@ejemplo.com',
          prefixIcon: Icon(Icons.email_outlined),
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enviar invitación'),
        ),
      ],
    );
  }
}

class _FinancialSummaryCard extends StatelessWidget {
  const _FinancialSummaryCard({
    required this.totalSpent,
    required this.userContribution,
    required this.userBalance,
    required this.currencyFormat,
    required this.onDebtTap,
  });

  final double totalSpent;
  final double userContribution;
  final double userBalance;
  final NumberFormat currencyFormat;
  final VoidCallback onDebtTap;

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
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.19),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colors.primary,
                      Color.lerp(colors.primary, colors.secondary, 0.34)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            Positioned(
              right: -54,
              top: -72,
              child: Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 28,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 46,
              bottom: -96,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.045),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
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
                        onTap: isDebt ? onDebtTap : null,
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
            ),
          ],
        ),
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
    this.onTap,
  });

  final String title;
  final String value;
  final Color color;
  final Color mutedColor;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
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
              if (onTap != null)
                TextButton(
                  onPressed: onTap,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFB4F0FF),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Ver deudas',
                    maxLines: 1,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),
        ],
      ),
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
      elevation: 0,
      shadowColor: colors.primary.withValues(alpha: 0.06),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colors.primary.withValues(alpha: 0.09)),
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
                backgroundColor: const Color(0xFFE7F3F8),
                child: Icon(
                  iconForCategory(expense.category),
                  size: 21,
                  color: colors.secondary,
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
                      color: colors.primary,
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
                          : colors.secondaryContainer,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Text(
                      isSettled
                          ? 'Al día'
                          : '${expense.participantIds.length} personas',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isSettled
                            ? const Color(0xFF19734A)
                            : colors.onSecondaryContainer,
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
