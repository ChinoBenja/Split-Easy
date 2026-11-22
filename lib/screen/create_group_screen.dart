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
      if (!mounted) return;
      if (image == null && _supportsLostPhotoRecovery) {
        final lostData = await picker.retrieveLostData();
        if (!mounted) return;
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
      if (!mounted) return;
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
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'No se pudo crear el grupo: $e');
      }
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
    final fieldBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFFDCE8EF)),
    );
    final focusedFieldBorder = fieldBorder.copyWith(
      borderSide: const BorderSide(color: Color(0xFF2457C5), width: 1.5),
    );

    InputDecoration fieldDecoration({
      required String labelText,
      required IconData icon,
      String? hintText,
    }) {
      return InputDecoration(
        labelText: labelText,
        hintText: hintText,
        prefixIcon: Icon(icon, color: const Color(0xFF687C8D)),
        filled: true,
        fillColor: const Color(0xFFF5FAFD),
        border: fieldBorder,
        enabledBorder: fieldBorder,
        focusedBorder: focusedFieldBorder,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: Text(
          'Nuevo grupo',
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
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: const Border(top: BorderSide(color: Color(0xFFDCE8EF))),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF173B75).withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            height: 82,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                  child: SizedBox(
                    height: 54,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _createGroup,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF2457C5),
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        elevation: 0,
                        textStyle: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: _isLoading
                            ? const SizedBox(
                                key: ValueKey('loading'),
                                width: 21,
                                height: 21,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                key: ValueKey('create'),
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.group_add_rounded, size: 19),
                                  SizedBox(width: 8),
                                  Text('Crear grupo'),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Card(
                elevation: 1,
                shadowColor: const Color(0xFF173B75).withValues(alpha: 0.08),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  side: const BorderSide(color: Color(0xFFDCE8EF)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CreateGroupHero(
                          photoBytes: _groupPhotoBytes,
                          photoContentType: _groupPhotoContentType,
                          isPickingPhoto: _isPickingGroupPhoto,
                          onSelectPhoto: _isLoading || _isPickingGroupPhoto
                              ? null
                              : _selectGroupPhoto,
                        ),
                        const SizedBox(height: 22),
                        _FormSectionLabel(
                          icon: Icons.edit_note_rounded,
                          title: 'Información del grupo',
                          subtitle: 'Define el nombre y el propósito',
                        ),
                        const SizedBox(height: 14),
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
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFF2FAFD), Color(0xFFE7F3F8)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFD2E7EF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          Color(0xFF2457C5),
                                          Color(0xFF087F8C),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(15),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(
                                            0xFF087F8C,
                                          ).withValues(alpha: 0.16),
                                          blurRadius: 9,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.people_alt_rounded,
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Arma tu equipo',
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF173B75),
                                          ),
                                    ),
                                  ),
                                  _MemberCountBadge(count: _members.length),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Agrega personas por correo para compartir gastos e invitarlas a participar.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF526879),
                                  height: 1.4,
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
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 54,
                                    height: 54,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            Color(0xFF2457C5),
                                            Color(0xFF087F8C),
                                          ],
                                        ),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF176B87,
                                            ).withValues(alpha: 0.2),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: IconButton(
                                        tooltip: 'Invitar integrante',
                                        onPressed: _isAddingMember
                                            ? null
                                            : _addMemberByEmail,
                                        style: IconButton.styleFrom(
                                          shape: const CircleBorder(),
                                          foregroundColor: Colors.white,
                                        ),
                                        icon: _isAddingMember
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : const Icon(
                                                Icons.person_add_alt_1_rounded,
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              Row(
                                children: [
                                  Text(
                                    'INTEGRANTES DEL GRUPO',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: const Color(0xFF687C8D),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.65,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      height: 1,
                                      color: const Color(0xFFD2E7EF),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (_members.isEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: const Color(0xFFDCE8EF),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.person_search_rounded,
                                        color: Color(0xFF7C9AAA),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Aquí aparecerán las personas que invites.',
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color: const Color(0xFF687C8D),
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Column(
                                  children: _members.entries.map((entry) {
                                    final isCreator =
                                        entry.key ==
                                        FirebaseAuth.instance.currentUser?.uid;
                                    final member = entry.value;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: _GroupMemberTile(
                                        member: member,
                                        isCreator: isCreator,
                                        onRemove: isCreator
                                            ? null
                                            : () => setState(
                                                () =>
                                                    _members.remove(member.uid),
                                              ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                        if (_errorMessage != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(
                                  0xFFD94E61,
                                ).withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 20,
                                  color: Color(0xFFD94E61),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFFD94E61),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
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

class _MemberCountBadge extends StatelessWidget {
  const _MemberCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD2E7EF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF173B75).withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups_rounded, size: 15, color: Color(0xFF087F8C)),
          const SizedBox(width: 5),
          Text(
            '$count',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: const Color(0xFF176B87),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupMemberTile extends StatelessWidget {
  const _GroupMemberTile({
    required this.member,
    required this.isCreator,
    required this.onRemove,
  });

  final _GroupMember member;
  final bool isCreator;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FAFD),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDCE8EF)),
      ),
      child: Row(
        children: [
          PersonAvatar(
            name: member.displayName,
            photoSource: member.photoSource,
            radius: 19,
            backgroundColor: const Color(0xFFD9EDF4),
            foregroundColor: const Color(0xFF176B87),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: const Color(0xFF173B75),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (member.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    member.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF687C8D),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isCreator)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE7F3F8),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Tú',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: const Color(0xFF087F8C),
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            IconButton(
              onPressed: onRemove,
              tooltip: 'Quitar integrante',
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                foregroundColor: const Color(0xFF687C8D),
              ),
              icon: const Icon(Icons.close_rounded, size: 19),
            ),
        ],
      ),
    );
  }
}

class _CreateGroupHero extends StatelessWidget {
  const _CreateGroupHero({
    required this.photoBytes,
    required this.photoContentType,
    required this.isPickingPhoto,
    required this.onSelectPhoto,
  });

  final List<int>? photoBytes;
  final String photoContentType;
  final bool isPickingPhoto;
  final VoidCallback? onSelectPhoto;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photoSource = photoBytes == null
        ? null
        : 'data:$photoContentType;base64,${base64Encode(photoBytes!)}';

    return Container(
      height: 186,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2457C5), Color(0xFF087F8C), Color(0xFF20A6A7)],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF176B87).withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -50,
            right: -24,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
          ),
          Positioned(
            left: -44,
            bottom: -82,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            right: -14,
            bottom: -18,
            child: Icon(
              Icons.groups_rounded,
              size: 130,
              color: Colors.white.withValues(alpha: 0.06),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: photoSource == null
                      ? 'Añadir foto del grupo'
                      : 'Cambiar foto del grupo',
                  child: GestureDetector(
                    onTap: onSelectPhoto,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 82,
                          height: 82,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.15),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.8),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF12345B,
                                ).withValues(alpha: 0.15),
                                blurRadius: 12,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: photoSource == null
                                ? Container(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    child: const Icon(
                                      Icons.groups_rounded,
                                      color: Colors.white,
                                      size: 40,
                                    ),
                                  )
                                : ProfilePhotoImage(
                                    source: photoSource,
                                    fallback: Container(
                                      color: Colors.white.withValues(
                                        alpha: 0.18,
                                      ),
                                      child: const Icon(
                                        Icons.groups_rounded,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          right: -1,
                          bottom: 0,
                          child: Container(
                            width: 29,
                            height: 29,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFB7DCE8),
                              ),
                            ),
                            child: isPickingPhoto
                                ? const Padding(
                                    padding: EdgeInsets.all(6),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF087F8C),
                                    ),
                                  )
                                : const Icon(
                                    Icons.add_a_photo_rounded,
                                    size: 15,
                                    color: Color(0xFF176B87),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 17),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          'TU PRÓXIMO PLAN',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.94),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.75,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Crea tu espacio compartido',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Añade una foto y organiza gastos en equipo.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: onSelectPhoto,
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                photoSource == null
                                    ? Icons.add_a_photo_outlined
                                    : Icons.edit_rounded,
                                size: 15,
                                color: const Color(0xFFB4F0FF),
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  photoSource == null
                                      ? 'Añadir foto del grupo'
                                      : 'Cambiar foto',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFFB4F0FF),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
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

class _FormSectionLabel extends StatelessWidget {
  const _FormSectionLabel({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F3F8),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF176B87), size: 23),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
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
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF687C8D),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
