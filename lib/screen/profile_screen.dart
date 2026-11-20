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
        if (!mounted) return;
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
      if (!mounted) return;
      if (image == null) {
        if (!_supportsLostPhotoRecovery) return;
        final lostData = await picker.retrieveLostData();
        if (!mounted) return;
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
      if (!mounted) return;
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
    if (!mounted) return;
    await _loadProfilePhoto();
  }

  Future<void> _uploadProfilePhoto(XFile image, User user) async {
    final bytes = await image.readAsBytes();
    if (!mounted) return;
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
    final passwordBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(color: Color(0xFFDCE8EF)),
    );
    final focusedPasswordBorder = passwordBorder.copyWith(
      borderSide: const BorderSide(color: Color(0xFF2457C5), width: 1.5),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFEAF4FB),
      appBar: AppBar(
        title: Text(
          'Mi perfil',
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 1,
                    shadowColor: const Color(
                      0xFF173B75,
                    ).withValues(alpha: 0.08),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: const BorderSide(color: Color(0xFFDCE8EF)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                height: 104,
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color(0xFF3B82B8),
                                      Color(0xFF69B8D0),
                                    ],
                                  ),
                                ),
                                child: Stack(
                                  children: [
                                    Positioned(
                                      right: -24,
                                      top: -62,
                                      child: Container(
                                        width: 150,
                                        height: 150,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.1,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                    const Positioned(
                                      left: 18,
                                      top: 17,
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.account_circle_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'CUENTA SPLITEASY',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1.1,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Positioned(
                                left: 20,
                                bottom: -34,
                                child: InkWell(
                                  onTap: _isLoading
                                      ? null
                                      : _changeProfilePhoto,
                                  customBorder: const CircleBorder(),
                                  child: Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 42,
                                        backgroundColor: Colors.white,
                                        child: CircleAvatar(
                                          radius: 37,
                                          backgroundColor: const Color(
                                            0xFFE7F3F8,
                                          ),
                                          child: ClipOval(
                                            child: SizedBox.expand(
                                              child:
                                                  _photoUrl
                                                          ?.trim()
                                                          .isNotEmpty ==
                                                      true
                                                  ? ProfilePhotoImage(
                                                      source: _photoUrl!,
                                                      fallback: const Icon(
                                                        Icons.person_rounded,
                                                        size: 40,
                                                        color: Color(
                                                          0xFF087F8C,
                                                        ),
                                                      ),
                                                      fit: BoxFit.cover,
                                                    )
                                                  : const Icon(
                                                      Icons.person_rounded,
                                                      size: 40,
                                                      color: Color(0xFF087F8C),
                                                    ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      Positioned(
                                        right: 1,
                                        bottom: 1,
                                        child: CircleAvatar(
                                          radius: 14,
                                          backgroundColor: const Color(
                                            0xFF2457C5,
                                          ),
                                          child: Icon(
                                            _isLoading
                                                ? Icons.hourglass_top_rounded
                                                : Icons.camera_alt_rounded,
                                            size: 15,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 42, 20, 20),
                            child: Column(
                              children: [
                                TextButton.icon(
                                  onPressed: _isLoading
                                      ? null
                                      : _changeProfilePhoto,
                                  icon: const Icon(
                                    Icons.photo_camera_outlined,
                                    size: 17,
                                  ),
                                  label: const Text('Cambiar foto'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF2457C5),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  user?.displayName?.trim().isNotEmpty == true
                                      ? user!.displayName!.trim()
                                      : 'Sin nombre',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: const Color(0xFF173B75),
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.email_outlined,
                                      size: 16,
                                      color: Color(0xFF687C8D),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        user?.email ?? 'Correo no disponible',
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: const Color(0xFF687C8D),
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Card(
                    margin: EdgeInsets.zero,
                    elevation: 1,
                    shadowColor: const Color(
                      0xFF173B75,
                    ).withValues(alpha: 0.06),
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                      side: const BorderSide(color: Color(0xFFDCE8EF)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE7F3F8),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.lock_reset_rounded,
                                    color: Color(0xFF087F8C),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Cambiar contraseña',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                              color: const Color(0xFF173B75),
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Mínimo 6 caracteres',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: const Color(0xFF687C8D),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            if (_requiresCurrentPassword) ...[
                              TextFormField(
                                controller: _currentPasswordController,
                                obscureText: _obscureCurrentPassword,
                                enabled: !_isLoading,
                                decoration: InputDecoration(
                                  labelText: 'Contraseña actual',
                                  filled: true,
                                  fillColor: const Color(0xFFF5FAFD),
                                  prefixIcon: const Icon(
                                    Icons.lock_outline_rounded,
                                    color: Color(0xFF687C8D),
                                  ),
                                  border: passwordBorder,
                                  enabledBorder: passwordBorder,
                                  focusedBorder: focusedPasswordBorder,
                                  suffixIcon: IconButton(
                                    padding: const EdgeInsets.all(12),
                                    constraints: const BoxConstraints(
                                      minWidth: 48,
                                      minHeight: 48,
                                    ),
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
                              const SizedBox(height: 18),
                            ],
                            TextFormField(
                              controller: _newPasswordController,
                              obscureText: _obscureNewPassword,
                              enabled: !_isLoading,
                              decoration: InputDecoration(
                                labelText: 'Nueva contraseña',
                                filled: true,
                                fillColor: const Color(0xFFF5FAFD),
                                prefixIcon: const Icon(
                                  Icons.lock_reset_rounded,
                                  color: Color(0xFF687C8D),
                                ),
                                border: passwordBorder,
                                enabledBorder: passwordBorder,
                                focusedBorder: focusedPasswordBorder,
                                suffixIcon: IconButton(
                                  padding: const EdgeInsets.all(12),
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
                                  tooltip: _obscureNewPassword
                                      ? 'Mostrar contraseña'
                                      : 'Ocultar contraseña',
                                  onPressed: () => setState(
                                    () => _obscureNewPassword =
                                        !_obscureNewPassword,
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
                            const SizedBox(height: 18),
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: _obscureConfirmPassword,
                              enabled: !_isLoading,
                              decoration: InputDecoration(
                                labelText: 'Confirmar nueva contraseña',
                                filled: true,
                                fillColor: const Color(0xFFF5FAFD),
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: Color(0xFF687C8D),
                                ),
                                border: passwordBorder,
                                enabledBorder: passwordBorder,
                                focusedBorder: focusedPasswordBorder,
                                suffixIcon: IconButton(
                                  padding: const EdgeInsets.all(12),
                                  constraints: const BoxConstraints(
                                    minWidth: 48,
                                    minHeight: 48,
                                  ),
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
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF2457C5),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                shape: const StadiumBorder(),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signOut,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Cerrar sesión'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2457C5),
                      side: const BorderSide(color: Color(0xFF9AABB8)),
                      minimumSize: const Size.fromHeight(48),
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600),
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
