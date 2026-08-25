import 'dart:convert';

import 'package:http/http.dart' as http;

class AiException implements Exception {
  AiException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Minimal OpenAI-compatible client for OpenRouter.
///
/// https://openrouter.ai/docs — endpoint is OpenAI-compatible.
class OpenRouterClient {
  OpenRouterClient({http.Client? httpClient, String? baseUrl})
    : _http = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? 'https://openrouter.ai/api/v1';

  static const _model = 'openrouter/auto';

  final http.Client _http;
  final String _baseUrl;

  /// Sends a chat completion request. [key] is the OpenRouter API key.
  /// [system] and [messages] are the conversation parts.
  /// Returns the assistant text.
  Future<String> complete({
    required String key,
    required String system,
    required List<Map<String, String>> messages,
    double temperature = 0.3,
    int maxTokens = 600,
  }) async {
    final uri = Uri.parse('$_baseUrl/chat/completions');
    final response = await _http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
            'HTTP-Referer': 'https://flowpilot.app',
            'X-Title': 'FlowPilot',
          },
          body: jsonEncode({
            'model': _model,
            'temperature': temperature,
            'max_tokens': maxTokens,
            'messages': [
              {'role': 'system', 'content': system},
              ...messages,
            ],
          }),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 401) {
      throw AiException(
        'Clave de OpenRouter no autorizada (401). Revisa que la clave sea '
        'correcta y tenga crédito en https://openrouter.ai/keys.',
      );
    }
    if (response.statusCode != 200) {
      throw AiException(
        'OpenRouter error ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw AiException('OpenRouter returned no choices');
    }
    final content =
        (choices.first as Map<String, dynamic>)['message']?['content'];
    return (content as String? ?? '').trim();
  }
}
