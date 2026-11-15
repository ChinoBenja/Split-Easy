import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../widgets/profile_photo_image.dart';
import 'change_password_screen.dart';
import 'notifications_screen.dart';
import 'profile_edit_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _firestoreService = FirestoreService();

  bool _isLoading = false;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _photoUrl = FirebaseAuth.instance.currentUser?.photoURL;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshProfile();
    });
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (!mounted) return;
    await _refreshProfile();
  }

  Future<void> _openProfileEdit() => _openScreen(const ProfileEditScreen());

  Future<void> _refreshProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    try {
      await user?.reload();
    } on FirebaseAuthException catch (error) {
      if (mounted) {
        _showSnackBar(
          error.message ?? 'No se pudo actualizar el perfil.',
          isError: true,
        );
      }
    }

    if (!mounted) return;
    final refreshedUser = FirebaseAuth.instance.currentUser;
    var photoUrl = refreshedUser?.photoURL;
    if (refreshedUser != null) {
      try {
        photoUrl =
            await _firestoreService.getUserPhoto(refreshedUser.uid) ?? photoUrl;
      } catch (error) {
        debugPrint(
          'Error al cargar la foto del perfil ${refreshedUser.uid}: $error',
        );
        if (mounted) {
          _showSnackBar('No se pudo cargar la foto de perfil.', isError: true);
        }
      }
    }
    if (mounted) setState(() => _photoUrl = photoUrl);
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
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim();

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text('Mi perfil'),
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Card(
                  color: colors.surfaceContainerLowest,
                  elevation: 1,
                  shadowColor: colors.shadow.withValues(alpha: 0.12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Tooltip(
                          message: 'Editar perfil',
                          child: InkWell(
                            onTap: _openProfileEdit,
                            customBorder: const CircleBorder(),
                            child: CircleAvatar(
                              radius: 42,
                              backgroundColor: colors.primaryContainer,
                              child: ClipOval(
                                child: SizedBox.expand(
                                  child: _photoUrl?.trim().isNotEmpty == true
                                      ? ProfilePhotoImage(
                                          source: _photoUrl!,
                                          fallback: Icon(
                                            Icons.person_rounded,
                                            size: 44,
                                            color: colors.onPrimaryContainer,
                                          ),
                                        )
                                      : Icon(
                                          Icons.person_rounded,
                                          size: 44,
                                          color: colors.onPrimaryContainer,
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          name?.isNotEmpty == true ? name! : 'Sin nombre',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
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
                _ProfileOption(
                  icon: Icons.person_outline_rounded,
                  title: 'Perfil',
                  subtitle: 'Foto y nombre de usuario',
                  onTap: _openProfileEdit,
                ),
                const SizedBox(height: 12),
                _ProfileOption(
                  icon: Icons.lock_outline_rounded,
                  title: 'Cambiar contraseña',
                  subtitle: 'Actualiza tu contraseña de acceso',
                  onTap: () => _openScreen(const ChangePasswordScreen()),
                ),
                const SizedBox(height: 12),
                _ProfileOption(
                  icon: Icons.notifications_none_rounded,
                  title: 'Notificaciones',
                  subtitle: 'Próximamente',
                  onTap: () => _openScreen(const NotificationsScreen()),
                ),
                const SizedBox(height: 20),
                _ProfileOption(
                  icon: Icons.logout_rounded,
                  title: 'Cerrar sesión',
                  subtitle: 'Salir de tu cuenta en este dispositivo',
                  isDanger: true,
                  onTap: _isLoading ? null : _signOut,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileOption extends StatelessWidget {
  const _ProfileOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDanger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foregroundColor = isDanger ? colors.error : colors.onSurface;

    return Card(
      color: colors.surfaceContainerLowest,
      elevation: 1,
      shadowColor: colors.shadow.withValues(alpha: 0.12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isDanger ? colors.errorContainer : colors.primaryContainer,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            icon,
            color: isDanger ? colors.error : colors.onPrimaryContainer,
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: foregroundColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isDanger ? colors.error : colors.onSurfaceVariant,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: isDanger ? colors.error : colors.onSurfaceVariant,
        ),
      ),
    );
  }
}
