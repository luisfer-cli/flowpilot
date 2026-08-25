import 'package:flutter_test/flutter_test.dart';

import 'package:flowpilot/features/ai/ai_service.dart';
import 'package:flowpilot/features/ai/openrouter_client.dart';

class FakeOpenRouterClient extends OpenRouterClient {
  FakeOpenRouterClient(this.responder) : super(baseUrl: 'http://fake');

  final String Function(String system, List<Map<String, String>> messages)
  responder;

  @override
  Future<String> complete({
    required String key,
    required String system,
    required List<Map<String, String>> messages,
    double temperature = 0.3,
    int maxTokens = 600,
  }) async {
    return responder(system, messages);
  }
}

void main() {
  test('parseBrainDump extracts structured tasks from JSON', () async {
    final client = FakeOpenRouterClient(
      (system, messages) =>
          '[{"title":"Terminar portfolio","priority":3,"due":"2026-09-01","notes":"subirlo"},'
          '{"title":"Comprar comida","priority":1}]',
    );
    final service = AiService(
      client: client,
      apiKeyProvider: () async => 'sk-test',
    );

    final result = await service.parseBrainDump(
      'Tengo que terminar el portfolio y comprar comida',
    );

    expect(result, hasLength(2));
    expect(result[0].title, 'Terminar portfolio');
    expect(result[0].priority, 3);
    expect(result[0].due, '2026-09-01');
    expect(result[1].title, 'Comprar comida');
  });

  test('parseBrainDump strips code fences', () async {
    final client = FakeOpenRouterClient(
      (system, messages) => '```json\n[{"title":"Tarea A"}]\n```',
    );
    final service = AiService(
      client: client,
      apiKeyProvider: () async => 'sk-test',
    );

    final result = await service.parseBrainDump('Tarea A');
    expect(result.single.title, 'Tarea A');
  });

  test('parseBrainDump falls back to line parsing on non-JSON', () async {
    final client = FakeOpenRouterClient(
      (system, messages) => '- Primera\n- Segunda',
    );
    final service = AiService(
      client: client,
      apiKeyProvider: () async => 'sk-test',
    );

    final result = await service.parseBrainDump('texto');
    expect(result, hasLength(2));
    expect(result[0].title, 'Primera');
  });
}
