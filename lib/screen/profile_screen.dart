import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/firestore_service.dart';

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

  @override
  void initState() {
    super.initState();
    _photoUrl = FirebaseAuth.instance.currentUser?.photoURL;
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
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (image == null) return;

      final bytes = await image.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        throw StateError('La imagen no puede superar los 10 MB.');
      }

      final extension = image.name.contains('.')
          ? image.name.split('.').last.toLowerCase()
          : 'jpg';
      final safeExtension = RegExp(r'^[a-z0-9]+$').hasMatch(extension)
          ? extension
          : 'jpg';
      final contentType = image.mimeType?.startsWith('image/') == true
          ? image.mimeType!
          : 'image/$safeExtension';
      final storageRef = FirebaseStorage.instance.ref().child(
        'profile_images/${user.uid}.$safeExtension',
      );
      await storageRef.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      final downloadUrl = await storageRef.getDownloadURL();

      await user.updatePhotoURL(downloadUrl);
      await _firestoreService.updateUserPhoto(
        uid: user.uid,
        photoUrl: downloadUrl,
      );
      await user.reload();
      await NetworkImage(downloadUrl).evict();

      if (!mounted) return;
      setState(() => _photoUrl = downloadUrl);
      _showSnackBar('La foto de perfil se actualizó correctamente.');
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
                                          ? Image.network(
                                              _photoUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder:
                                                  (
                                                    context,
                                                    error,
                                                    stackTrace,
                                                  ) => Icon(
                                                    Icons.person_rounded,
                                                    size: 38,
                                                    color: colors
                                                        .onPrimaryContainer,
                                                  ),
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
