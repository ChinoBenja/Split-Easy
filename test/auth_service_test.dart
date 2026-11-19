import 'package:flutter_test/flutter_test.dart';
import 'package:split_easy/auth_service.dart';

void main() {
  group('AuthService email validation', () {
    test('accepts standard email formats', () {
      expect(AuthService.isValidEmail('usuario@example.com'), isTrue);
      expect(AuthService.isValidEmail('user.name+tag@sub.domain.com'), isTrue);
    });

    test('rejects invalid email formats', () {
      expect(AuthService.isValidEmail(''), isFalse);
      expect(AuthService.isValidEmail('correo'), isFalse);
      expect(AuthService.isValidEmail('usuario@'), isFalse);
      expect(AuthService.isValidEmail('usuario@dominio'), isFalse);
      expect(AuthService.isValidEmail('usuario@dominio.'), isFalse);
    });
  });
}
