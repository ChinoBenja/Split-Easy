import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/category_model.dart';
import '../../models/group_model.dart';
import '../../services/firestore_service.dart';
import '../widgets/person_avatar.dart';

enum _SplitMode { equal, percentage, custom }

class _ExpenseIntroCard extends StatelessWidget {
  const _ExpenseIntroCard({
    required this.groupName,
    required this.amount,
    required this.currencyFormat,
    required this.memberCount,
  });

  final String groupName;
  final double amount;
  final NumberFormat currencyFormat;
  final int memberCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2457C5), Color(0xFF087F8C), Color(0xFF25A9A7)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF176B87).withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -68,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.09),
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
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.24),
                      ),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Colors.white,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NUEVO MOVIMIENTO',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.9,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          groupName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.auto_awesome_rounded,
                    color: Color(0xFFB4F0FF),
                    size: 23,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL DEL GASTO',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.82),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            key: ValueKey(amount),
                            amount > 0
                                ? currencyFormat.format(amount)
                                : 'Ingresa el monto',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.groups_rounded,
                          size: 17,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$memberCount ${memberCount == 1 ? 'persona' : 'personas'}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 32),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _PaymentProgressCard extends StatelessWidget {
  const _PaymentProgressCard({
    required this.isValid,
    required this.paid,
    required this.total,
    required this.currencyFormat,
  });

  final bool isValid;
  final double paid;
  final double total;
  final NumberFormat currencyFormat;

  @override
  Widget build(BuildContext context) {
    final color = isValid ? const Color(0xFF167451) : const Color(0xFFB4233A);
    final progress = (paid / total).clamp(0.0, 1.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isValid ? const Color(0xFFEAF7F1) : const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.17)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isValid ? Icons.check_circle_rounded : Icons.payments_rounded,
                size: 19,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isValid ? 'Pago completo' : 'Distribución del pago',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                '${currencyFormat.format(paid)} / ${currencyFormat.format(total)}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.13),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (!isValid) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                paid < total
                    ? 'Faltan ${currencyFormat.format(total - paid)} por asignar.'
                    : 'El monto asignado supera el total del gasto.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, required this.group});

  final GroupModel group;

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _firestoreService = FirestoreService();
  final _currencyFormat = NumberFormat.currency(
    locale: 'es_CL',
    symbol: '\$',
    decimalDigits: 0,
  );

  late final Set<String> _selectedPayers;
  late final Set<String> _selectedParticipants;
  final Map<String, TextEditingController> _payerAmountControllers = {};
  final Map<String, TextEditingController> _shareControllers = {};
  String _selectedCategory = defaultCategories.first.name;
  DateTime _selectedDate = DateTime.now();
  _SplitMode _splitMode = _SplitMode.equal;
  bool _isLoading = false;
  String? _errorMessage;
  late final Future<Map<String, String>> _memberPhotoUrls;

  @override
  void initState() {
    super.initState();
    _memberPhotoUrls = _firestoreService.getUserPhotoUrls(
      widget.group.memberIds,
    );
    _selectedParticipants = widget.group.memberIds.toSet();
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    _selectedPayers =
        currentUid != null && widget.group.memberIds.contains(currentUid)
        ? {currentUid}
        : {};
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    for (final controller in _payerAmountControllers.values) {
      controller.dispose();
    }
    for (final controller in _shareControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  double get _totalAmount =>
      double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;

  TextEditingController _payerControllerFor(String uid) =>
      _payerAmountControllers.putIfAbsent(uid, TextEditingController.new);

  TextEditingController _shareControllerFor(String uid) =>
      _shareControllers.putIfAbsent(uid, TextEditingController.new);

  double _parseController(TextEditingController controller) =>
      double.tryParse(controller.text.replaceAll(',', '.').trim()) ?? 0;

  double get _sumOfPayments => _selectedPayers.fold(
    0,
    (sum, uid) => sum + _parseController(_payerControllerFor(uid)),
  );

  double get _sumOfShares => _selectedParticipants.fold(
    0,
    (sum, uid) => sum + _parseController(_shareControllerFor(uid)),
  );

  void _splitPayersEqually() {
    if (_selectedPayers.isEmpty || _totalAmount <= 0) return;
    final share = _totalAmount / _selectedPayers.length;
    setState(() {
      for (final uid in _selectedPayers) {
        _payerControllerFor(uid).text = share.toStringAsFixed(0);
      }
    });
  }

  void _distributeSharesEqually() {
    if (_selectedParticipants.isEmpty) return;
    setState(() {
      if (_splitMode == _SplitMode.percentage) {
        final share = 100 / _selectedParticipants.length;
        for (final uid in _selectedParticipants) {
          _shareControllerFor(uid).text = share.toStringAsFixed(1);
        }
      } else if (_splitMode == _SplitMode.custom) {
        final share = _totalAmount / _selectedParticipants.length;
        for (final uid in _selectedParticipants) {
          _shareControllerFor(uid).text = share.toStringAsFixed(0);
        }
      }
    });
  }

  Map<String, double>? _computeShares(double amount) {
    if (_selectedParticipants.isEmpty) return null;
    if (_splitMode == _SplitMode.equal) {
      final share = amount / _selectedParticipants.length;
      return {for (final uid in _selectedParticipants) uid: share};
    }
    if (_splitMode == _SplitMode.percentage) {
      if ((_sumOfShares - 100).abs() > 0.5) return null;
      return {
        for (final uid in _selectedParticipants)
          uid: amount * (_parseController(_shareControllerFor(uid)) / 100),
      };
    }
    if ((_sumOfShares - amount).abs() > 1) return null;
    return {
      for (final uid in _selectedParticipants)
        uid: _parseController(_shareControllerFor(uid)),
    };
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _addCustomCategory() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva categoría'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre',
            hintText: 'Ej. Regalos',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.isEmpty || !mounted) return;
    try {
      await _firestoreService.addCustomCategory(widget.group.id, name);
      if (!mounted) return;
      setState(() => _selectedCategory = name);
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = 'No se pudo agregar la categoría: $error',
        );
      }
    }
  }

  Future<void> _saveExpense() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedParticipants.isEmpty) {
      setState(() => _errorMessage = 'Selecciona al menos un participante.');
      return;
    }
    if (_selectedPayers.isEmpty) {
      setState(() => _errorMessage = 'Indica quién pagó este gasto.');
      return;
    }
    if ((_totalAmount - _sumOfPayments).abs() > 1) {
      setState(() {
        _errorMessage =
            'Los pagos (${_currencyFormat.format(_sumOfPayments)}) deben sumar el total del gasto.';
      });
      return;
    }

    final shares = _computeShares(_totalAmount);
    if (shares == null) {
      setState(() {
        _errorMessage = _splitMode == _SplitMode.percentage
            ? 'Los porcentajes deben sumar 100%.'
            : 'Los montos asignados deben sumar el total del gasto.';
      });
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(
        () => _errorMessage = 'La sesión expiró. Inicia sesión de nuevo.',
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final payments = <String, double>{};
      final payerNames = <String, String>{};
      for (final uid in _selectedPayers) {
        payments[uid] = _parseController(_payerControllerFor(uid));
        payerNames[uid] = widget.group.memberNames[uid] ?? 'Usuario';
      }

      await _firestoreService.addExpense(
        groupId: widget.group.id,
        description: _descriptionController.text.trim(),
        amount: _totalAmount,
        category: _selectedCategory,
        payments: payments,
        payerNames: payerNames,
        participantShares: shares,
        splitMode: _splitMode.name,
        date: _selectedDate,
        createdBy: currentUser.uid,
        createdByName:
            widget.group.memberNames[currentUser.uid] ??
            currentUser.displayName ??
            'Usuario',
      );
      if (!mounted) return;
      await _firestoreService.notifyBalanceUpdate(widget.group);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = 'No se pudo guardar el gasto: $error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _section({
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 2,
      shadowColor: const Color(0xFF173B75).withValues(alpha: 0.06),
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFDCE8EF)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF087F8C), Color(0xFF25A9A7)],
                    ),
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF087F8C).withValues(alpha: 0.16),
                        blurRadius: 9,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 21),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF173B75),
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF687C8D),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _avatar(String name, String uid) {
    return FutureBuilder<Map<String, String>>(
      future: _memberPhotoUrls,
      builder: (context, snapshot) => PersonAvatar(
        name: name,
        photoSource: snapshot.data?[uid],
        radius: 18,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
    );
  }

  Widget _statusMessage({required bool isValid, required String text}) {
    final color = isValid ? const Color(0xFF167451) : const Color(0xFFB4233A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isValid ? const Color(0xFFEAF7F1) : const Color(0xFFFFF0F1),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  void _toggleAllParticipants() {
    setState(() {
      if (_selectedParticipants.length == widget.group.memberIds.length) {
        _selectedParticipants.clear();
        for (final uid in widget.group.memberIds) {
          _shareControllerFor(uid).clear();
        }
      } else {
        _selectedParticipants
          ..clear()
          ..addAll(widget.group.memberIds);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final categories = [
      ...defaultCategories.map((category) => category.name),
      ...widget.group.customCategories,
    ];
    final amountFieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: colors.outlineVariant),
    );
    final paymentsValid = (_totalAmount - _sumOfPayments).abs() <= 1;
    final sharesValid = _splitMode == _SplitMode.percentage
        ? (_sumOfShares - 100).abs() <= 0.5
        : (_sumOfShares - _totalAmount).abs() <= 1;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: const Text('Nuevo gasto'),
        backgroundColor: const Color(0xFFEAF4FB),
        foregroundColor: const Color(0xFF173B75),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _ExpenseIntroCard(
                  groupName: widget.group.name,
                  amount: _totalAmount,
                  currencyFormat: _currencyFormat,
                  memberCount: widget.group.memberIds.length,
                ),
                const SizedBox(height: 16),
                _section(
                  icon: Icons.payments_outlined,
                  title: 'Monto y detalles',
                  subtitle: 'Cuánto costó y cuándo ocurrió',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(17, 12, 17, 6),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFFE8F7FC), Color(0xFFD8EFF8)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFC9E5F0)),
                        ),
                        child: TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -1,
                            color: const Color(0xFF173B75),
                          ),
                          decoration: InputDecoration(
                            labelText: 'Monto total',
                            labelStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF526879),
                            ),
                            prefixText: '\$ ',
                            prefixStyle: theme.textTheme.headlineMedium
                                ?.copyWith(
                                  color: const Color(0xFF2457C5),
                                  fontWeight: FontWeight.w700,
                                ),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.only(bottom: 8),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            final amount = double.tryParse(
                              (value ?? '').replaceAll(',', '.'),
                            );
                            return amount == null || amount <= 0
                                ? 'Ingresa un monto válido'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _descriptionController,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          labelText: 'Descripción',
                          hintText: 'Ej. Cena o alojamiento del viaje',
                          prefixIcon: const Icon(
                            Icons.edit_note_rounded,
                            color: Color(0xFF176B87),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5FAFD),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE8EF),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: Color(0xFFDCE8EF),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: const BorderSide(
                              color: Color(0xFF2457C5),
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Ingresa una descripción'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      Material(
                        color: const Color(0xFFF5FAFD),
                        borderRadius: BorderRadius.circular(15),
                        child: InkWell(
                          onTap: _pickDate,
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: const Color(0xFFDCE8EF),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE7F3F8),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_month_rounded,
                                    color: Color(0xFF176B87),
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Fecha del gasto',
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
                                              color: const Color(0xFF687C8D),
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat(
                                          'dd MMMM yyyy',
                                          'es',
                                        ).format(_selectedDate),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: const Color(0xFF173B75),
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: Color(0xFF526879),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _section(
                  icon: Icons.sell_outlined,
                  title: 'Categoría',
                  subtitle: 'Organiza este gasto para encontrarlo fácilmente',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...categories.map(
                        (name) => FilterChip(
                          avatar: Icon(
                            iconForCategory(name),
                            size: 18,
                            color: _selectedCategory == name
                                ? const Color(0xFF176B87)
                                : const Color(0xFF687C8D),
                          ),
                          label: Text(name),
                          selected: _selectedCategory == name,
                          showCheckmark: false,
                          selectedColor: const Color(0xFFD9EDF4),
                          backgroundColor: const Color(0xFFF5FAFD),
                          side: BorderSide(
                            color: _selectedCategory == name
                                ? const Color(0xFF2457C5)
                                : const Color(0xFFDCE8EF),
                            width: _selectedCategory == name ? 1.5 : 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          labelStyle: theme.textTheme.labelLarge?.copyWith(
                            color: _selectedCategory == name
                                ? const Color(0xFF173B75)
                                : const Color(0xFF526879),
                            fontWeight: _selectedCategory == name
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedCategory = name);
                          },
                        ),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Nueva'),
                        onPressed: _addCustomCategory,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _section(
                  icon: Icons.account_balance_wallet_outlined,
                  title: '¿Quién pagó?',
                  subtitle: 'Selecciona quién adelantó el dinero',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CountBadge(
                        count: _selectedPayers.length,
                        color: const Color(0xFF2457C5),
                      ),
                      IconButton(
                        tooltip: 'Dividir el pago por igual',
                        onPressed: _splitPayersEqually,
                        icon: const Icon(Icons.balance_rounded),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      ...widget.group.memberIds.map((uid) {
                        final name = widget.group.memberNames[uid] ?? uid;
                        final isSelected = _selectedPayers.contains(uid);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFEAF7FC),
                                        Color(0xFFF5FBFD),
                                      ],
                                    )
                                  : null,
                              color: isSelected ? null : Colors.white,
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF9CCDDD)
                                    : const Color(0xFFEDF2F5),
                                width: isSelected ? 1.3 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  visualDensity: VisualDensity.compact,
                                  activeColor: const Color(0xFF087F8C),
                                  onChanged: (selected) {
                                    setState(() {
                                      if (selected == true) {
                                        _selectedPayers.add(uid);
                                      } else {
                                        _selectedPayers.remove(uid);
                                        _payerControllerFor(uid).clear();
                                      }
                                    });
                                  },
                                ),
                                _avatar(name, uid),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF263F55),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    width: 118,
                                    child: TextField(
                                      controller: _payerControllerFor(uid),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        prefixText: '\$ ',
                                        labelText: 'Aportó',
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 10,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFDCE8EF),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFFDCE8EF),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF2457C5),
                                            width: 1.4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      }),
                      if (_selectedPayers.isNotEmpty && _totalAmount > 0) ...[
                        const SizedBox(height: 13),
                        _PaymentProgressCard(
                          isValid: paymentsValid,
                          paid: _sumOfPayments,
                          total: _totalAmount,
                          currencyFormat: _currencyFormat,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _section(
                  icon: Icons.groups_2_outlined,
                  title: '¿Entre quiénes se divide?',
                  subtitle: 'Elige quiénes comparten este gasto',
                  trailing: _CountBadge(
                    count: _selectedParticipants.length,
                    color: const Color(0xFF087F8C),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Elige a quienes les corresponde una parte.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF687C8D),
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _toggleAllParticipants,
                            icon: Icon(
                              _selectedParticipants.length ==
                                      widget.group.memberIds.length
                                  ? Icons.remove_done_rounded
                                  : Icons.done_all_rounded,
                              size: 17,
                            ),
                            label: Text(
                              _selectedParticipants.length ==
                                      widget.group.memberIds.length
                                  ? 'Quitar todos'
                                  : 'Seleccionar todos',
                            ),
                          ),
                        ],
                      ),
                      ...widget.group.memberIds.map((uid) {
                        final name = widget.group.memberNames[uid] ?? uid;
                        final selected = _selectedParticipants.contains(uid);
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              gradient: selected
                                  ? const LinearGradient(
                                      colors: [
                                        Color(0xFFEAF7FC),
                                        Color(0xFFF5FBFD),
                                      ],
                                    )
                                  : null,
                              color: selected ? null : Colors.white,
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF9CCDDD)
                                    : const Color(0xFFEDF2F5),
                                width: selected ? 1.3 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: selected,
                                  visualDensity: VisualDensity.compact,
                                  activeColor: const Color(0xFF087F8C),
                                  onChanged: (value) {
                                    setState(() {
                                      if (value == true) {
                                        _selectedParticipants.add(uid);
                                      } else {
                                        _selectedParticipants.remove(uid);
                                        _shareControllerFor(uid).clear();
                                      }
                                    });
                                  },
                                ),
                                _avatar(name, uid),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF263F55),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                if (selected && _splitMode != _SplitMode.equal)
                                  SizedBox(
                                    width: 112,
                                    child: TextField(
                                      controller: _shareControllerFor(uid),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      onChanged: (_) => setState(() {}),
                                      decoration: InputDecoration(
                                        isDense: true,
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 9,
                                              vertical: 10,
                                            ),
                                        prefixText:
                                            _splitMode == _SplitMode.custom
                                            ? '\$ '
                                            : null,
                                        suffixText:
                                            _splitMode == _SplitMode.percentage
                                            ? '%'
                                            : null,
                                        labelText:
                                            _splitMode == _SplitMode.percentage
                                            ? 'Porcentaje'
                                            : 'Monto',
                                        border: amountFieldBorder,
                                        enabledBorder: amountFieldBorder,
                                        focusedBorder: amountFieldBorder
                                            .copyWith(
                                              borderSide: const BorderSide(
                                                color: Color(0xFF2457C5),
                                                width: 1.4,
                                              ),
                                            ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                      const Divider(height: 24),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Método de reparto',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<_SplitMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: _SplitMode.equal,
                              label: Text('Igual'),
                              icon: Icon(Icons.call_split_rounded),
                            ),
                            ButtonSegment(
                              value: _SplitMode.percentage,
                              label: Text('%'),
                              icon: Icon(Icons.percent_rounded),
                            ),
                            ButtonSegment(
                              value: _SplitMode.custom,
                              label: Text('Monto'),
                              icon: Icon(Icons.edit_outlined),
                            ),
                          ],
                          selected: {_splitMode},
                          onSelectionChanged: (selection) {
                            setState(() => _splitMode = selection.first);
                          },
                        ),
                      ),
                      if (_splitMode == _SplitMode.equal &&
                          _selectedParticipants.isNotEmpty &&
                          _totalAmount > 0) ...[
                        const SizedBox(height: 14),
                        _statusMessage(
                          isValid: true,
                          text:
                              'Cuota por persona: ${_currencyFormat.format(_totalAmount / _selectedParticipants.length)}',
                        ),
                      ],
                      if (_splitMode != _SplitMode.equal) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: _distributeSharesEqually,
                            icon: const Icon(Icons.auto_awesome, size: 18),
                            label: const Text('Repartir por igual'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        _statusMessage(
                          isValid: sharesValid,
                          text: _splitMode == _SplitMode.percentage
                              ? 'Suma: ${_sumOfShares.toStringAsFixed(1)}% (debe ser 100%)'
                              : 'Suma: ${_currencyFormat.format(_sumOfShares)} de ${_currencyFormat.format(_totalAmount)}',
                        ),
                      ],
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.errorContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          color: colors.onErrorContainer,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: colors.onErrorContainer),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Container(
                  height: 58,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [Color(0xFF2457C5), Color(0xFF087F8C)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF176B87).withValues(alpha: 0.2),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: FilledButton.icon(
                    onPressed: _isLoading ? null : _saveExpense,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      disabledBackgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white70,
                      minimumSize: const Size.fromHeight(58),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                      textStyle: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(_isLoading ? 'Guardando...' : 'Guardar gasto'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
