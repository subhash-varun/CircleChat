import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class Services {
  final ApiService api = ApiService();
}

class ApiService {
  static const String _backendBaseUrlOverride = String.fromEnvironment(
    'PUSH_API_BASE_URL',
    defaultValue: '',
  );
  static const String _defaultBackendBaseUrl =
      'https://jholjhal-push-backend.onrender.com';

  String get _backendBaseUrl {
    if (_backendBaseUrlOverride.trim().isNotEmpty) {
      return _backendBaseUrlOverride.trim();
    }
    return _defaultBackendBaseUrl;
  }

  Future<void> registerDeviceToken({
    required String userRef,
    required String token,
    required String platform,
  }) async {
    await _post(
      '/api/push/tokens/register',
      body: {
        'userRef': userRef.trim(),
        'token': token.trim(),
        'platform': platform.trim(),
      },
    );
  }

  Future<void> unregisterDeviceToken({
    required String userRef,
    required String token,
  }) async {
    if (userRef.trim().isEmpty) return;
    if (token.trim().isEmpty) return;
    await _post(
      '/api/push/tokens/unregister',
      body: {
        'userRef': userRef.trim(),
        'token': token.trim(),
      },
    );
  }

  Future<void> sendMessagePush({
    required String recipientRef,
    required String senderRef,
    required String conversationId,
    required String messageId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    await _post(
      '/api/push/messages/send',
      body: {
        'recipientRef': recipientRef.trim(),
        'senderRef': senderRef.trim(),
        'conversationId': conversationId.trim(),
        'messageId': messageId.trim(),
        'title': title.trim(),
        'body': body.trim(),
        'data': data ?? <String, String>{},
      },
    );
  }

  Future<void> _post(
    String path, {
    required Map<String, dynamic> body,
  }) async {
    final uri = Uri.parse('$_backendBaseUrl$path');
    try {
      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode >= 200 && response.statusCode < 300) return;

      throw Exception(
        'HTTP ${response.statusCode} ${response.reasonPhrase ?? ''} ${response.body}',
      );
    } catch (e) {
      debugPrint('[API_SERVICE] POST $uri failed: $e');
      rethrow;
    }
  }
}
