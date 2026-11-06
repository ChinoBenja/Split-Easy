import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/firestore_service.dart';
import '../widgets/profile_photo_image.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firestoreService = FirestoreService();

  bool _isLoading = false;
  String? _photoUrl;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  bool get _requiresCurrentPassword {
    final user = FirebaseAuth.instance.currentUser;
    return user?.providerData.any(
          (provider) => provider.providerId == 'password',
        ) ??
        false;
  }

  bool get _supportsLostPhotoRecovery =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _photoUrl = FirebaseAuth.instance.currentUser?.photoURL;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProfilePhoto();
    });
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showSnackBar('No hay una sesión activa.', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_requiresCurrentPassword) {
        final email = user.email;
        if (email == null || email.isEmpty) {
          _showSnackBar(
            'No se pudo verificar el correo de esta cuenta.',
            isError: true,
          );
          return;
        }

        final credential = EmailAuthProvider.credential(
          email: email,
          password: _currentPasswordController.text,
        );
        await user.reauthenticateWithCredential(credential);
      }

      await user.updatePassword(_newPasswordController.text);
      if (!mounted) return;

      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      _showSnackBar('La contraseña se cambió correctamente.');
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showSnackBar(_getAuthErrorMessage(error), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getAuthErrorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'La contraseña actual es incorrecta.';
      case 'weak-password':
        return 'La nueva contraseña debe tener al menos 6 caracteres.';
      case 'requires-recent-login':
        return 'Por seguridad, cierra sesión e inicia sesión nuevamente antes de cambiar la contraseña.';
      case 'network-request-failed':
        return 'Error de conexión. Revisa tu internet e inténtalo nuevamente.';
      default:
        return error.message ?? 'No se pudo cambiar la contraseña.';
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      _showSnackBar(
        error.message ?? 'No se pudo cerrar sesión.',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Mi perfil'),
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
                  Card(
                    color: colors.surfaceContainerLowest,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          InkWell(
                            onTap: _isLoading ? null : _changeProfilePhoto,
                            customBorder: const CircleBorder(),
                            child: Stack(
                              children: [
                                CircleAvatar(
                                  radius: 36,
                                  backgroundColor: colors.primaryContainer,
                                  child: ClipOval(
                                    child: SizedBox.expand(
                                      child:
                                          _photoUrl?.trim().isNotEmpty == true
                                          ? ProfilePhotoImage(
                                              source: _photoUrl!,
                                              fallback: Icon(
                                                Icons.person_rounded,
                                                size: 38,
                                                color:
                                                    colors.onPrimaryContainer,
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : Icon(
                                              Icons.person_rounded,
                                              size: 38,
                                              color: colors.onPrimaryContainer,
                                            ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: CircleAvatar(
                                    radius: 13,
                                    backgroundColor: colors.primary,
                                    child: Icon(
                                      _isLoading
                                          ? Icons.hourglass_top_rounded
                                          : Icons.camera_alt_rounded,
                                      size: 15,
                                      color: colors.onPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _isLoading ? null : _changeProfilePhoto,
                            child: const Text('Cambiar foto'),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            user?.displayName?.trim().isNotEmpty == true
                                ? user!.displayName!.trim()
                                : 'Sin nombre',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            user?.email ?? 'Correo no disponible',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Cambiar contraseña',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'La nueva contraseña debe tener al menos 6 caracteres.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_requiresCurrentPassword) ...[
                          TextFormField(
                            controller: _currentPasswordController,
                            obscureText: _obscureCurrentPassword,
                            enabled: !_isLoading,
                            decoration: InputDecoration(
                              labelText: 'Contraseña actual',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                tooltip: _obscureCurrentPassword
                                    ? 'Mostrar contraseña'
                                    : 'Ocultar contraseña',
                                onPressed: () => setState(
                                  () => _obscureCurrentPassword =
                                      !_obscureCurrentPassword,
                                ),
                                icon: Icon(
                                  _obscureCurrentPassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Ingresa tu contraseña actual.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),
                        ],
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: _obscureNewPassword,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: 'Nueva contraseña',
                            prefixIcon: const Icon(Icons.lock_reset_rounded),
                            suffixIcon: IconButton(
                              tooltip: _obscureNewPassword
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              onPressed: () => setState(
                                () =>
                                    _obscureNewPassword = !_obscureNewPassword,
                              ),
                              icon: Icon(
                                _obscureNewPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Ingresa una nueva contraseña.';
                            }
                            if (value.length < 6) {
                              return 'Debe tener al menos 6 caracteres.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirmPassword,
                          enabled: !_isLoading,
                          decoration: InputDecoration(
                            labelText: 'Confirmar nueva contraseña',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              tooltip: _obscureConfirmPassword
                                  ? 'Mostrar contraseña'
                                  : 'Ocultar contraseña',
                              onPressed: () => setState(
                                () => _obscureConfirmPassword =
                                    !_obscureConfirmPassword,
                              ),
                              icon: Icon(
                                _obscureConfirmPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Confirma la nueva contraseña.';
                            }
                            if (value != _newPasswordController.text) {
                              return 'Las contraseñas no coinciden.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _changePassword,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.key_rounded),
                          label: const Text('Actualizar contraseña'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Cerrar sesión'),
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
