import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart' as intl_local;
import 'firebase_options.dart';
import 'login_screen.dart';
import 'screen/groups_list_screen.dart';
import 'services/firestore_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await intl_local.initializeDateFormatting('es', null);
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {
    // Fallback para entornos de prueba o cuando la inicialización no está disponible.
  }
  runApp(const SplitEasyApp());
}

class SplitEasyApp extends StatelessWidget {
  const SplitEasyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SplitEasy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
      ),
      home: const AuthGate(),
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
    // Registra el token FCM para poder recibir notificaciones push
    // (requiere la Cloud Function descrita en notification_service.dart)
    await NotificationService().initialize(widget.user.uid);
  }

  @override
  Widget build(BuildContext context) {
    return const GroupsListScreen();
  }
}
