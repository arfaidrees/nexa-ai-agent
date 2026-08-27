import 'dart:convert';

import 'package:http/http.dart' as http;

const defaultApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://127.0.0.1:8000',
);

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({String? baseUrl, http.Client? client})
      : baseUrl = (baseUrl ?? defaultApiBaseUrl).replaceAll(RegExp(r'/$'), ''),
        _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<ChatResult> sendMessage({required String message, String? sessionId}) async {
    final payload = <String, dynamic>{'message': message};
    if (sessionId != null) payload['session_id'] = sessionId;

    late http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 20));
    } on Exception {
      throw const ApiException(
        'Nexa is unreachable right now. Check that the backend is running and try again.',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      var message = 'Nexa could not process that request.';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        if (body['detail'] is String && (body['detail'] as String).isNotEmpty) {
          message = body['detail'] as String;
        }
      } on Object {
        // Preserve a friendly message for non-JSON backend errors.
      }
      throw ApiException(message);
    }

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final reply = body['reply'];
      final sessionId = body['session_id'];
      if (reply is! String || reply.trim().isEmpty || sessionId is! String) {
        throw const ApiException('Nexa returned an empty response. Please try again.');
      }
      final type = body['type'];
      final data = body['data'];
      return ChatResult(
        sessionId: sessionId,
        reply: reply,
        type: type is String ? type : 'text',
        data: data is Map<String, dynamic> ? data : null,
      );
    } on ApiException {
      rethrow;
    } on Object {
      throw const ApiException('Nexa returned an invalid response. Please try again.');
    }
  }

  void dispose() => _client.close();
}

class ChatResult {
  const ChatResult({required this.sessionId, required this.reply, required this.type, this.data});

  final String sessionId;
  final String reply;
  final String type;
  final Map<String, dynamic>? data;
}
