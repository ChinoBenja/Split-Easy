import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/firestore_service.dart';
import '../widgets/person_avatar.dart';
import '../widgets/profile_photo_image.dart';

class _GroupMember {
  const _GroupMember({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoSource,
  });

  final String uid;
  final String email;
  final String displayName;
  final String? photoSource;
}

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

  // uid -> datos del integrante validado (incluye al creador)
  final Map<String, _GroupMember> _members = {};
  bool _isLoading = false;
  bool _isAddingMember = false;
  bool _isPickingGroupPhoto = false;
  List<int>? _groupPhotoBytes;
  String _groupPhotoContentType = 'image/jpeg';
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _members[user.uid] = _GroupMember(
        uid: user.uid,
        email: user.email ?? '',
        displayName: user.displayName ?? user.email ?? 'Yo',
        photoSource: user.photoURL,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadCurrentMemberPhoto(user.uid);
      });
    }
    if (_supportsLostPhotoRecovery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _restoreLostGroupPhoto();
      });
    }
  }

  Future<void> _loadCurrentMemberPhoto(String uid) async {
    try {
      final photoSource = await _firestoreService.getUserPhoto(uid);
      if (!mounted || photoSource == null) return;
      final member = _members[uid];
      if (member == null) return;
      setState(() {
        _members[uid] = _GroupMember(
          uid: member.uid,
          email: member.email,
          displayName: member.displayName,
          photoSource: photoSource,
        );
      });
    } catch (error) {
      debugPrint('No se pudo cargar la foto del creador del grupo: $error');
    }
  }

  Future<void> _selectGroupPhoto() async {
    if (_isPickingGroupPhoto || _isLoading) return;
    setState(() => _isPickingGroupPhoto = true);
    try {
      final picker = ImagePicker();
      var image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 320,
        maxHeight: 320,
        imageQuality: 70,
      );
      if (image == null && _supportsLostPhotoRecovery) {
        final lostData = await picker.retrieveLostData();
        if (lostData.exception != null) throw lostData.exception!;
        image = lostData.files?.firstOrNull;
      }
      if (image != null) await _applyGroupPhoto(image);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo seleccionar la foto: $error')),
      );
    } finally {
      if (mounted) setState(() => _isPickingGroupPhoto = false);
    }
  }

  bool get _supportsLostPhotoRecovery =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> _restoreLostGroupPhoto() async {
    if (!mounted) return;
    try {
      final lostData = await ImagePicker().retrieveLostData();
      if (lostData.isEmpty) return;
      if (lostData.exception != null) throw lostData.exception!;
      final image = lostData.files?.firstOrNull;
      if (image == null) {
        throw StateError('No se pudo recuperar la imagen seleccionada.');
      }
      await _applyGroupPhoto(image);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo recuperar la foto del grupo: $error'),
        ),
      );
    }
  }

  Future<void> _applyGroupPhoto(XFile image) async {
    final bytes = await image.readAsBytes();
    if (bytes.length > 120 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La foto optimizada supera los 120 KB. Elige otra imagen.',
            ),
          ),
        );
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _groupPhotoBytes = bytes;
      _groupPhotoContentType = image.mimeType?.startsWith('image/') == true
          ? image.mimeType!
          : 'image/jpeg';
    });
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'El usuario no está registrado en Split-Easy. Debe crear una cuenta primero.',
              ),
            ),
          );
        }
        return;
      }

      final uid = user['uid'] as String;
      if (_members.containsKey(uid)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Este usuario ya está en el grupo.')),
          );
        }
        return;
      }

      final userEmail = (user['email'] as String?) ?? email;
      final displayName =
          (user['displayName'] as String?) ??
          (user['name'] as String?) ??
          userEmail;
      if (!mounted) return;

      setState(() {
        _members[uid] = _GroupMember(
          uid: uid,
          email: userEmail,
          displayName: displayName,
          photoSource: user['photoSource'] as String?,
        );
        _memberEmailController.clear();
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'No se pudo validar el usuario: $e');
      }
    } finally {
      if (mounted) setState(() => _isAddingMember = false);
    }
  }

  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _errorMessage = 'Inicia sesión para crear un grupo.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _firestoreService.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        memberNames: _members.map(
          (uid, member) => MapEntry(uid, member.displayName),
        ),
        photoBytes: _groupPhotoBytes,
        photoContentType: _groupPhotoContentType,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _errorMessage = 'No se pudo crear el grupo: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _memberEmailController.dispose();
    super.dispose();
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
                          child: InkWell(
                            onTap: _isLoading || _isPickingGroupPhoto
                                ? null
                                : _selectGroupPhoto,
                            customBorder: const CircleBorder(),
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 42,
                                  backgroundColor: scheme.primaryContainer,
                                  child: ClipOval(
                                    child: SizedBox.expand(
                                      child: _groupPhotoBytes == null
                                          ? Icon(
                                              Icons.groups_rounded,
                                              size: 36,
                                              color: scheme.onPrimaryContainer,
                                            )
                                          : ProfilePhotoImage(
                                              source:
                                                  'data:$_groupPhotoContentType;base64,${base64Encode(_groupPhotoBytes!)}',
                                              fallback: Icon(
                                                Icons.groups_rounded,
                                                size: 36,
                                                color:
                                                    scheme.onPrimaryContainer,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: CircleAvatar(
                                    radius: 14,
                                    backgroundColor: scheme.primary,
                                    child: Icon(
                                      _isPickingGroupPhoto
                                          ? Icons.hourglass_top_rounded
                                          : Icons.camera_alt_rounded,
                                      size: 16,
                                      color: scheme.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Foto del grupo · opcional, solo al crearlo',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
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
                                'Integrantes e invitaciones',
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
                        const SizedBox(height: 6),
                        Text(
                          'Las personas que agregues recibirán una invitación y deberán aceptarla para unirse.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
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
                                tooltip: 'Invitar integrante',
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
                              final member = entry.value;
                              return InputChip(
                                avatar: PersonAvatar(
                                  name: member.displayName,
                                  photoSource: member.photoSource,
                                  radius: 16,
                                  backgroundColor: scheme.primaryContainer,
                                  foregroundColor: scheme.onPrimaryContainer,
                                ),
                                label: Text(
                                  member.email.isEmpty
                                      ? member.displayName
                                      : '${member.displayName} · ${member.email}',
                                ),
                                deleteIcon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                ),
                                onDeleted: isCreator
                                    ? null
                                    : () => setState(
                                        () => _members.remove(member.uid),
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
