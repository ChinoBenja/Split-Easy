import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';

/// Pantalla de creación de grupos (H.4). Permite agregar integrantes
/// por correo electrónico (deben tener cuenta creada en SplitEasy).
class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _memberEmailController = TextEditingController();
  final _firestoreService = FirestoreService();

  // uid -> nombre, de los integrantes ya agregados (incluye al creador)
  final Map<String, String> _members = {};
  bool _isLoading = false;
  bool _isAddingMember = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _members[user.uid] = user.displayName ?? user.email ?? 'Yo';
    }
  }

  Future<void> _addMemberByEmail() async {
    final email = _memberEmailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _isAddingMember = true;
      _errorMessage = null;
    });

    try {
      final user = await _firestoreService.findUserByEmail(email);
      if (user == null) {
        setState(
          () => _errorMessage = 'No se encontró un usuario con ese correo.',
        );
        return;
      }
      setState(() {
        _members[user['uid']] = user['name'] ?? email;
        _memberEmailController.clear();
      });
    } finally {
      if (mounted) setState(() => _isAddingMember = false);
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _firestoreService.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        createdBy: currentUser.uid,
        memberNames: _members,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _errorMessage = 'No se pudo crear el grupo: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: scheme.outlineVariant),
    );

    InputDecoration fieldDecoration({
      required String labelText,
      required IconData icon,
      String? hintText,
    }) {
      return InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: fieldBorder.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      );
    }

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(title: const Text('Nuevo grupo')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                elevation: 2,
                shadowColor: scheme.shadow.withValues(alpha: 0.12),
                color: scheme.surfaceContainerLowest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: scheme.primaryContainer,
                              borderRadius: BorderRadius.circular(21),
                            ),
                            child: Icon(
                              Icons.groups_rounded,
                              size: 36,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Crea un grupo',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Organiza los gastos y compártelos con tus integrantes',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: fieldDecoration(
                            labelText: 'Nombre del grupo',
                            hintText: 'Ej: Viaje a Valparaíso',
                            icon: Icons.group_outlined,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Ingresa un nombre para el grupo';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: fieldDecoration(
                            labelText: 'Descripción (opcional)',
                            hintText: '¿Cuál es el propósito del grupo?',
                            icon: Icons.notes_rounded,
                          ),
                          maxLines: 3,
                          minLines: 2,
                        ),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Icon(
                              Icons.people_outline_rounded,
                              color: scheme.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Integrantes',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '${_members.length}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _memberEmailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: fieldDecoration(
                                  labelText: 'Correo del integrante',
                                  icon: Icons.alternate_email_rounded,
                                ),
                                onFieldSubmitted: (_) {
                                  if (!_isAddingMember) {
                                    _addMemberByEmail();
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 52,
                              height: 52,
                              child: IconButton.filled(
                                tooltip: 'Añadir integrante',
                                onPressed: _isAddingMember
                                    ? null
                                    : _addMemberByEmail,
                                style: IconButton.styleFrom(
                                  shape: const CircleBorder(),
                                  backgroundColor: scheme.primary,
                                  foregroundColor: scheme.onPrimary,
                                ),
                                icon: _isAddingMember
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: scheme.onPrimary,
                                        ),
                                      )
                                    : const Icon(Icons.add_rounded),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (_members.isEmpty)
                          Text(
                            'Añade a las personas con las que compartirás gastos.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          )
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _members.entries.map((entry) {
                              final isCreator =
                                  entry.key ==
                                  FirebaseAuth.instance.currentUser?.uid;
                              return InputChip(
                                avatar: CircleAvatar(
                                  backgroundColor: scheme.primaryContainer,
                                  foregroundColor: scheme.onPrimaryContainer,
                                  child: Text(
                                    entry.value.isNotEmpty
                                        ? entry.value[0].toUpperCase()
                                        : '?',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                label: Text(entry.value),
                                deleteIcon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                ),
                                onDeleted: isCreator
                                    ? null
                                    : () => setState(
                                        () => _members.remove(entry.key),
                                      ),
                                backgroundColor: scheme.surfaceContainerHighest,
                                side: BorderSide(
                                  color: scheme.outlineVariant.withValues(
                                    alpha: 0.7,
                                  ),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                labelStyle: theme.textTheme.labelLarge
                                    ?.copyWith(
                                      color: scheme.onSurface,
                                      fontWeight: FontWeight.w500,
                                    ),
                              );
                            }).toList(),
                          ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: scheme.errorContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline_rounded,
                                  size: 20,
                                  color: scheme.onErrorContainer,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onErrorContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 28),
                        SizedBox(
                          height: 54,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _createGroup,
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            child: _isLoading
                                ? SizedBox(
                                    width: 21,
                                    height: 21,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: scheme.onPrimary,
                                    ),
                                  )
                                : const Text('Crear grupo'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
