import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Servicio que encapsula toda la lógica de autenticación con Firebase.
/// Lo usan tanto la pantalla de Login como la de Registro (H.7 y H.8).
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static bool isValidEmail(String value) {
    final trimmed = value.trim();
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return trimmed.isNotEmpty && emailRegex.hasMatch(trimmed);
  }

  /// Usuario actualmente logueado (null si no hay sesión activa)
  User? get currentUser => _auth.currentUser;

  /// Stream para escuchar cambios de sesión (login/logout) en tiempo real
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Inicia sesión con correo y contraseña.
  /// Lanza [AuthException] con un mensaje ya traducido al español si falla.
  Future<User?> login({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      return credential.user;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapErrorMessage(e.code));
    }
  }

  /// Envía un correo de recuperación de contraseña.
  Future<void> sendPasswordResetEmail({required String email}) async {
    if (!isValidEmail(email)) {
      throw AuthException('Ingresa un correo válido.');
    }

    final normalizedEmail = email.trim().toLowerCase();

    try {
      await _auth.sendPasswordResetEmail(email: normalizedEmail);
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
    if (!isValidEmail(email)) {
      throw AuthException('Ingresa un correo válido.');
    }

    final normalizedEmail = email.trim().toLowerCase();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );

      // Guardamos el nombre en el perfil de Firebase Auth
      await credential.user?.updateDisplayName(name.trim());
      await credential.user?.reload();

      // Guardamos los datos del usuario en Firestore
      if (credential.user != null) {
        await _firestore.collection('users').doc(credential.user!.uid).set({
          'uid': credential.user!.uid,
          'name': name.trim(),
          'email': normalizedEmail,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return _auth.currentUser;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapErrorMessage(e.code));
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  /// Traduce los códigos de error de Firebase a mensajes entendibles
  String _mapErrorMessage(String code) {
    switch (code) {
      case 'invalid-email':
        return 'El correo ingresado no es válido.';
      case 'missing-android-pkg-name':
      case 'missing-continue-uri':
      case 'missing-ios-bundle-id':
      case 'invalid-action-code':
        return 'No se pudo completar la recuperación de contraseña.';
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
