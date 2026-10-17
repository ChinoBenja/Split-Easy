import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/category_model.dart';
import '../../models/expense_model.dart';
import '../../models/group_model.dart';
import '../../services/firestore_service.dart';

class EditExpenseScreen extends StatefulWidget {
  const EditExpenseScreen({
    super.key,
    required this.group,
    required this.expense,
  });

  final GroupModel group;
  final ExpenseModel expense;

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();
  final _firestoreService = FirestoreService();

  late String _selectedCategory;
  late DateTime _selectedDate;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _descriptionController.text = widget.expense.description;
    _amountController.text = widget.expense.amount.toStringAsFixed(
      widget.expense.amount % 1 == 0 ? 0 : 2,
    );
    _selectedCategory = widget.expense.category;
    _selectedDate = widget.expense.date;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitProposal() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(
        () => _errorMessage = 'La sesión expiró. Inicia sesión de nuevo.',
      );
      return;
    }

    final newAmount = double.parse(_amountController.text.replaceAll(',', '.'));
    final oldAmount = widget.expense.amount;
    final financialChange = (newAmount - oldAmount).abs() > 0.001;
    final ratio = oldAmount > 0 ? newAmount / oldAmount : 1.0;
    final payments = financialChange
        ? widget.expense.payments.map(
            (uid, amount) => MapEntry(uid, amount * ratio),
          )
        : widget.expense.payments;
    final shares = financialChange
        ? widget.expense.participantShares.map(
            (uid, amount) => MapEntry(uid, amount * ratio),
          )
        : widget.expense.participantShares;

    final oldValues = <String, dynamic>{
      'description': widget.expense.description,
      'amount': oldAmount,
      'category': widget.expense.category,
      'payments': widget.expense.payments,
      'payerNames': widget.expense.payerNames,
      'participantShares': widget.expense.participantShares,
      'splitMode': widget.expense.splitMode,
      'date': widget.expense.date,
    };
    final newValues = <String, dynamic>{
      'description': _descriptionController.text.trim(),
      'amount': newAmount,
      'category': _selectedCategory,
      'payments': payments,
      'payerNames': widget.expense.payerNames,
      'participantShares': shares,
      'splitMode': widget.expense.splitMode,
      'date': _selectedDate,
      if (financialChange) 'settledParticipantIds': <String>[],
      if (financialChange) 'pendingSettlementIds': <String>[],
    };

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await _firestoreService.proposeExpenseEdit(
        groupId: widget.group.id,
        expenseId: widget.expense.id,
        proposedBy: currentUser.uid,
        proposedByName:
            widget.group.memberNames[currentUser.uid] ??
            currentUser.displayName ??
            'Usuario',
        oldValues: oldValues,
        newValues: newValues,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Propuesta enviada al chat para su aprobación.'),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _errorMessage = 'No se pudo enviar la propuesta: $error',
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final categories = {
      ...defaultCategories.map((category) => category.name),
      ...widget.group.customCategories,
    };

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Proponer cambio'),
        surfaceTintColor: Colors.transparent,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: colors.onSecondaryContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Los cambios se enviarán al chat y se aplicarán cuando todos los integrantes los acepten.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Card(
                  margin: EdgeInsets.zero,
                  elevation: 1,
                  color: colors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: 0.6),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Monto del gasto',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          decoration: InputDecoration(
                            prefixText: '\$ ',
                            hintText: '0',
                            filled: true,
                            fillColor: colors.primaryContainer.withValues(
                              alpha: 0.45,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          validator: (value) {
                            final amount = double.tryParse(
                              (value ?? '').replaceAll(',', '.'),
                            );
                            if (amount == null || amount <= 0) {
                              return 'Ingresa un monto válido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'El ajuste al monto actualizará proporcionalmente los pagos y cuotas existentes.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 18),
                        TextFormField(
                          controller: _descriptionController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Descripción',
                            prefixIcon: Icon(Icons.edit_note_rounded),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'Ingresa una descripción'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Categoría',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: categories
                              .map(
                                (category) => FilterChip(
                                  avatar: Icon(
                                    iconForCategory(category),
                                    size: 18,
                                  ),
                                  label: Text(category),
                                  selected: _selectedCategory == category,
                                  showCheckmark: false,
                                  onSelected: (_) {
                                    setState(
                                      () => _selectedCategory = category,
                                    );
                                  },
                                ),
                              )
                              .toList(),
                        ),
                        const SizedBox(height: 14),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            Icons.calendar_month_outlined,
                            color: colors.primary,
                          ),
                          title: const Text('Fecha'),
                          subtitle: Text(
                            DateFormat(
                              'dd MMMM yyyy',
                              'es',
                            ).format(_selectedDate),
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _pickDate,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(_errorMessage!, style: TextStyle(color: colors.error)),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _isSubmitting ? null : _submitProposal,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting ? 'Enviando...' : 'Enviar propuesta',
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
