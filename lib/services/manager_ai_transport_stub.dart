import 'dart:convert';

import 'package:http/http.dart' as http;

class ManagerAiTransportResponse {
  const ManagerAiTransportResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final Map<String, dynamic> body;
}

class ManagerAiTransport {
  static const String _endpoint = String.fromEnvironment(
    'NEOTASK_AI_API_URL',
    defaultValue: 'https://project-0wvza.vercel.app/api/multi-agent',
  );

  static Future<ManagerAiTransportResponse> get({
    String languageCode = 'ar',
  }) async {
    final uri = Uri.parse(_endpoint).replace(
      queryParameters: languageCode == 'en' ? const {'lang': 'en'} : null,
    );
    final response = await http.get(uri).timeout(const Duration(seconds: 12));
    return ManagerAiTransportResponse(
      statusCode: response.statusCode,
      body: _decode(response.body),
    );
  }

  static Future<ManagerAiTransportResponse> post({
    required String firebaseToken,
    required Map<String, dynamic> body,
  }) async {
    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Authorization': 'Bearer $firebaseToken',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 75));
    return ManagerAiTransportResponse(
      statusCode: response.statusCode,
      body: _decode(response.body),
    );
  }

  static Map<String, dynamic> _decode(String value) {
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : const {};
    } catch (_) {
      return const {};
    }
  }
}
