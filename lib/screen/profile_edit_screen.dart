import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/firestore_service.dart';
import '../widgets/profile_photo_image.dart';

class ProfileEditScreen extends StatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  State<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends State<ProfileEditScreen> {
  final _nameController = TextEditingController();
  final _firestoreService = FirestoreService();

  bool _isLoading = false;
  bool _isEditingName = false;
  String? _photoUrl;

  bool get _supportsLostPhotoRecovery =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _nameController.text = user?.displayName?.trim() ?? '';
    _photoUrl = user?.photoURL;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProfilePhoto();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _changeProfilePhoto() async {
    if (_isLoading) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('No hay una sesión activa.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final picker = ImagePicker();
      var image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 320,
        maxHeight: 320,
        imageQuality: 75,
      );
      if (image == null) {
        if (!_supportsLostPhotoRecovery) return;
        final lostData = await picker.retrieveLostData();
        if (lostData.exception != null) throw lostData.exception!;
        final files = lostData.files;
        if (files == null || files.isEmpty) {
          _showSnackBar(
            'No se recibió la imagen seleccionada. Inténtalo nuevamente.',
            isError: true,
          );
          return;
        }
        image = files.first;
      }

      await _uploadProfilePhoto(image, user);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showSnackBar(
        error.message ?? 'No se pudo actualizar la foto de perfil.',
        isError: true,
      );
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(
        'No se pudo actualizar la foto de perfil: $error',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreLostProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    try {
      final lostData = await ImagePicker().retrieveLostData();
      if (lostData.isEmpty) return;
      if (lostData.exception != null) throw lostData.exception!;
      final files = lostData.files;
      if (files == null || files.isEmpty) {
        throw StateError('No se pudo recuperar la imagen seleccionada.');
      }

      setState(() => _isLoading = true);
      await _uploadProfilePhoto(files.first, user);
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(
        'No se pudo actualizar la foto de perfil: $error',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final photoSource = await _firestoreService.getUserPhoto(user.uid);
      if (!mounted || photoSource == null) return;
      setState(() => _photoUrl = photoSource);
    } catch (error) {
      debugPrint('Error al cargar la foto del perfil ${user.uid}: $error');
      if (mounted) {
        _showSnackBar('No se pudo cargar la foto de perfil.', isError: true);
      }
    }
  }

  Future<void> _initializeProfilePhoto() async {
    if (_supportsLostPhotoRecovery) await _restoreLostProfilePhoto();
    await _loadProfilePhoto();
  }

  Future<void> _uploadProfilePhoto(XFile image, User user) async {
    final bytes = await image.readAsBytes();
    if (bytes.length > 256 * 1024) {
      throw StateError(
        'La imagen optimizada supera los 256 KB. Elige otra foto.',
      );
    }

    await _firestoreService.updateUserPhoto(
      uid: user.uid,
      imageBytes: bytes,
      contentType: image.mimeType?.startsWith('image/') == true
          ? image.mimeType!
          : 'image/jpeg',
    );

    if (!mounted) return;
    setState(() => _photoUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}');
    _showSnackBar('La foto de perfil se actualizó correctamente.');
  }

  Future<void> _saveName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showSnackBar('Ingresa tu nombre de usuario.', isError: true);
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('No hay una sesión activa.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await user.updateDisplayName(name);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showSnackBar(
        error.message ?? 'No se pudo actualizar el nombre de usuario.',
        isError: true,
      );
      setState(() => _isLoading = false);
      return;
    }

    try {
      await _firestoreService.upsertUser(
        uid: user.uid,
        name: name,
        email: user.email ?? '',
      );
      if (!mounted) return;
      setState(() => _isEditingName = false);
      _showSnackBar('El nombre de usuario se actualizó correctamente.');
    } catch (error) {
      if (!mounted) return;
      _showSnackBar(
        'El nombre se actualizó en la cuenta, pero no se pudo guardar en el perfil compartido: $error',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Editar perfil'),
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: InkWell(
                      onTap: _isLoading ? null : _changeProfilePhoto,
                      customBorder: const CircleBorder(),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 72,
                            backgroundColor: colors.primaryContainer,
                            child: ClipOval(
                              child: SizedBox.expand(
                                child: _photoUrl?.trim().isNotEmpty == true
                                    ? ProfilePhotoImage(
                                        source: _photoUrl!,
                                        fallback: Icon(
                                          Icons.person_rounded,
                                          size: 72,
                                          color: colors.onPrimaryContainer,
                                        ),
                                      )
                                    : Icon(
                                        Icons.person_rounded,
                                        size: 72,
                                        color: colors.onPrimaryContainer,
                                      ),
                              ),
                            ),
                          ),
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: colors.primary,
                              child: Icon(
                                _isLoading
                                    ? Icons.hourglass_top_rounded
                                    : Icons.camera_alt_rounded,
                                size: 20,
                                color: colors.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: _isLoading ? null : _changeProfilePhoto,
                      child: const Text('Cambiar foto'),
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _nameController,
                    readOnly: !_isEditingName || _isLoading,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) {
                      if (_isEditingName && !_isLoading) _saveName();
                    },
                    decoration: InputDecoration(
                      labelText: 'Nombre',
                      suffixIcon: IconButton(
                        tooltip: _isEditingName ? 'Guardar nombre' : 'Editar',
                        onPressed: _isLoading
                            ? null
                            : _isEditingName
                            ? _saveName
                            : () => setState(() => _isEditingName = true),
                        icon: Icon(
                          _isEditingName
                              ? Icons.check_rounded
                              : Icons.edit_rounded,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    FirebaseAuth.instance.currentUser?.email ??
                        'Correo no disponible',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
