import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart' as intl_local;
import 'firebase_options.dart';
import 'login_screen.dart';
import 'screen/groups_list_screen.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }
  await intl_local.initializeDateFormatting('es', null);
  Object? firebaseInitializationError;
  try {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (error, stackTrace) {
    debugPrint('Firebase initialization failed: $error');
    debugPrintStack(stackTrace: stackTrace);
    firebaseInitializationError = error;
  }
  if (firebaseInitializationError == null && !kIsWeb) {
    NotificationService.registerBackgroundHandler();
  }
  runApp(
    SplitEasyApp(firebaseInitializationError: firebaseInitializationError),
  );
}

class SplitEasyApp extends StatelessWidget {
  final Object? firebaseInitializationError;

  const SplitEasyApp({super.key, this.firebaseInitializationError});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SplitEasy',
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        if (!kIsWeb || child == null) return child ?? const SizedBox.shrink();

        return LayoutBuilder(
          builder: (context, constraints) {
            final usePhoneFrame = constraints.maxWidth > 600;
            final frameHeight = constraints.maxHeight > 853
                ? 853.0
                : constraints.maxHeight;
            final frameWidth = usePhoneFrame
                ? frameHeight * 9 / 16
                : constraints.maxWidth;

            return ColoredBox(
              color: usePhoneFrame
                  ? const Color(0xFFDCE6ED)
                  : Colors.transparent,
              child: Center(
                child: Container(
                  width: frameWidth,
                  height: usePhoneFrame ? frameHeight : constraints.maxHeight,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(usePhoneFrame ? 24 : 0),
                    boxShadow: usePhoneFrame
                        ? [
                            BoxShadow(
                              color: const Color(
                                0xFF173B75,
                              ).withValues(alpha: 0.16),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ]
                        : null,
                  ),
                  child: child,
                ),
              ),
            );
          },
        );
      },
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(
              seedColor: const Color(0xFF176B87),
              brightness: Brightness.light,
            ).copyWith(
              primary: const Color(0xFF2457C5),
              secondary: const Color(0xFF087F8C),
              surface: const Color(0xFFF6F9FC),
              surfaceContainerHighest: const Color(0xFFEAF1F7),
            ),
        useMaterial3: true,
      ),
      home: firebaseInitializationError == null
          ? const AuthGate()
          : const _FirebaseInitializationErrorScreen(),
    );
  }
}

class _FirebaseInitializationErrorScreen extends StatelessWidget {
  const _FirebaseInitializationErrorScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off_rounded, size: 48),
              SizedBox(height: 16),
              Text(
                'No se pudo iniciar Firebase. Comprueba tu conexión e inténtalo de nuevo.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Decide qué pantalla mostrar según si hay una sesión activa.
/// Reemplaza el `home: const LoginScreen()` fijo que usábamos antes:
/// ahora el usuario entra directo a sus grupos si ya inició sesión.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Firebase.apps.isEmpty ? null : FirebaseAuth.instance;

    return StreamBuilder<User?>(
      stream: auth?.authStateChanges() ?? Stream<User?>.value(null),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginScreen();
        }

        // Sesión activa: aseguramos el documento en Firestore y el
        // token de notificaciones, luego mostramos los grupos.
        return _AuthenticatedHome(user: user);
      },
    );
  }
}

class _AuthenticatedHome extends StatefulWidget {
  final User user;
  const _AuthenticatedHome({required this.user});

  @override
  State<_AuthenticatedHome> createState() => _AuthenticatedHomeState();
}

class _AuthenticatedHomeState extends State<_AuthenticatedHome> {
  @override
  void initState() {
    super.initState();
    _setupUser();
  }

  Future<void> _setupUser() async {
    final firestoreService = FirestoreService();
    await firestoreService.upsertUser(
      uid: widget.user.uid,
      name: widget.user.displayName ?? '',
      email: widget.user.email ?? '',
    );
    if (!kIsWeb) {
      await NotificationService().initialize(widget.user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const GroupsListScreen();
  }
}
