import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AssistantService {
  static const _workerUrl = String.fromEnvironment(
    'ASSISTANT_WORKER_URL',
    defaultValue: 'https://spliteasy-assistant.benjahuang200437.workers.dev',
  );

  Future<String> sendMessage(List<Map<String, String>> messages) async {
    if (_workerUrl.isEmpty) {
      throw const AssistantServiceException('not-configured');
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const AssistantServiceException('unauthenticated');
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const AssistantServiceException('unauthenticated');
    }

    final uri = Uri.tryParse(_workerUrl);
    if (uri == null || uri.scheme != 'https' || !uri.hasAuthority) {
      throw const AssistantServiceException('not-configured');
    }

    final response = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'messages': messages}),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode != 200) {
      final errorCode = _readErrorCode(response.body);
      throw AssistantServiceException(
        errorCode ?? _codeForStatus(response.statusCode),
      );
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respuesta inválida del asistente.');
    }
    final reply = data['reply'];
    if (reply is! String || reply.trim().isEmpty) {
      throw const FormatException('El asistente devolvió una respuesta vacía.');
    }
    return reply.trim();
  }

  String? _readErrorCode(String body) {
    try {
      final data = jsonDecode(body);
      if (data is Map<String, dynamic> &&
          data['error'] is Map<String, dynamic>) {
        final code = (data['error'] as Map<String, dynamic>)['code'];
        return code is String ? code : null;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  String _codeForStatus(int statusCode) {
    if (statusCode == 401) return 'unauthenticated';
    if (statusCode == 413 || statusCode == 400) return 'invalid-argument';
    if (statusCode == 429) return 'resource-exhausted';
    return 'unavailable';
  }
}

@immutable
class AssistantServiceException implements Exception {
  const AssistantServiceException(this.code);

  final String code;
}
