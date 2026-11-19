import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// Servicio que encapsula toda la lógica de autenticación con Firebase.
/// Lo usan tanto la pantalla de Login como la de Registro (H.7 y H.8).
class AuthService {
  FirebaseAuth? _auth;

  FirebaseAuth get _authInstance {
    if (Firebase.apps.isEmpty) {
      throw AuthException('Firebase no está inicializado.');
    }
    _auth ??= FirebaseAuth.instance;
    return _auth!;
  }

  /// Usuario actualmente logueado (null si no hay sesión activa)
  User? get currentUser {
    try {
      return _authInstance.currentUser;
    } on AuthException {
      return null;
    }
  }

  /// Stream para escuchar cambios de sesión (login/logout) en tiempo real
  Stream<User?> get authStateChanges {
    try {
      return _authInstance.authStateChanges();
    } on AuthException {
      return Stream<User?>.value(null);
    }
  }

  /// Inicia sesión con correo y contraseña.
  /// Lanza [AuthException] con un mensaje ya traducido al español si falla.
  Future<User?> login({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _authInstance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapErrorMessage(e.code));
    }
  }

  /// Crea una cuenta nueva con correo, contraseña y nombre visible.
  Future<User?> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _authInstance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Guardamos el nombre en el perfil de Firebase Auth
      await credential.user?.updateDisplayName(name.trim());
      await credential.user?.reload();

      return _authInstance.currentUser;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapErrorMessage(e.code));
    }
  }

  Future<void> logout() async {
    try {
      await _authInstance.signOut();
    } on AuthException {
      // No-op si Firebase no está inicializado.
    }
  }

  /// Traduce los códigos de error de Firebase a mensajes entendibles
  String _mapErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'El correo ingresado no es válido.';
      case 'user-disabled':
        return 'Esta cuenta ha sido deshabilitada.';
      case 'user-not-found':
        return 'No existe una cuenta con este correo.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Correo o contraseña incorrectos.';
      case 'email-already-in-use':
        return 'Ya existe una cuenta registrada con este correo.';
      case 'weak-password':
        return 'La contraseña debe tener al menos 6 caracteres.';
      case 'network-request-failed':
        return 'Error de conexión. Revisa tu internet.';
      default:
        return 'Ocurrió un error inesperado. Intenta nuevamente.';
    }
  }
}

/// Excepción personalizada para mostrar errores legibles en la UI
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
