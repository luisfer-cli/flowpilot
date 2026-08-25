import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/settings_service.dart';
import 'openrouter_client.dart';

/// A task parsed from free text by the LLM.
class ParsedTask {
  const ParsedTask({
    required this.title,
    this.due,
    this.priority = 0,
    this.notes,
  });

  final String title;
  final String? due; // ISO date or natural language
  final int priority;
  final String? notes;

  factory ParsedTask.fromJson(Map<String, dynamic> json) {
    return ParsedTask(
      title: json['title'] as String? ?? 'Sin título',
      due: json['due'] as String?,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      notes: json['notes'] as String?,
    );
  }
}

class AiService {
  AiService({OpenRouterClient? client, this.apiKeyProvider = _readKey})
    : client = client ?? OpenRouterClient();

  final OpenRouterClient client;
  final Future<String?> Function() apiKeyProvider;

  static Future<String?> _readKey() async {
    return SettingsService().getApiKey();
  }

  /// Turns a raw brain dump / free text into a list of structured tasks.
  Future<List<ParsedTask>> parseBrainDump(String text) async {
    final key = await apiKeyProvider();
    if (key == null || key.isEmpty) {
      throw AiException('No hay clave de OpenRouter configurada en Ajustes.');
    }
    final system = '''
Eres un asistente de productividad. Convierte el texto del usuario en una lista de tareas.
Responde SOLO con JSON, un array de objetos con campos: title (string), due (string|null, formato ISO fecha o null), priority (int 0-4), notes (string|null).
No añadas texto fuera del JSON.''';

    final raw = await client.complete(
      key: key,
      system: system,
      messages: [
        {'role': 'user', 'content': text},
      ],
      temperature: 0.2,
      maxTokens: 800,
    );

    return _parseTasksJson(raw);
  }

  /// Returns a concrete single recommendation: "Haz X durante Y minutos".
  Future<String> whatNow({required List<String> activeTaskTitles}) async {
    final key = await apiKeyProvider();
    if (key == null || key.isEmpty) {
      throw AiException('No hay clave de OpenRouter configurada en Ajustes.');
    }
    final system = '''
Eres un coach de productividad. Dado el contexto del usuario, devuelve UNA recomendación concreta y accionable.
Responde en español, formato breve: 'Haz "tarea" durante N minutos.' o similar. Una sola recomendación, sin listas.''';

    final raw = await client.complete(
      key: key,
      system: system,
      messages: [
        {
          'role': 'user',
          'content': 'Tareas activas: ${activeTaskTitles.join('; ')}',
        },
      ],
      temperature: 0.4,
      maxTokens: 150,
    );
    return raw;
  }

  /// Chat assistant.
  Future<String> chat(String question) async {
    final key = await apiKeyProvider();
    if (key == null || key.isEmpty) {
      throw AiException('No hay clave de OpenRouter configurada en Ajustes.');
    }
    return client.complete(
      key: key,
      system: 'Eres FlowPilot, asistente de productividad. Responde en español, conciso y útil.',
      messages: [
        {'role': 'user', 'content': question},
      ],
      temperature: 0.5,
      maxTokens: 500,
    );
  }

  List<ParsedTask> _parseTasksJson(String raw) {
    final cleaned = _stripCodeFence(raw);
    try {
      final data = jsonDecode(cleaned);
      if (data is List) {
        return [
          for (final e in data)
            if (e is Map<String, dynamic>) ParsedTask.fromJson(e),
        ];
      }
      if (data is Map<String, dynamic> && data['tasks'] is List) {
        return [
          for (final e in data['tasks'] as List)
            if (e is Map<String, dynamic>) ParsedTask.fromJson(e),
        ];
      }
    } catch (_) {
      // fall through to line-based fallback
    }
    return _fallbackParse(raw);
  }

  String _stripCodeFence(String raw) {
    var s = raw.trim();
    if (s.startsWith('```')) {
      final first = s.indexOf('\n');
      final last = s.lastIndexOf('```');
      if (first != -1 && last > first) s = s.substring(first + 1, last);
    }
    return s.trim();
  }

  List<ParsedTask> _fallbackParse(String raw) {
    return [
      for (final line in raw.split('\n'))
        if (line.trim().isNotEmpty)
          ParsedTask(
            title: line.replaceFirst(RegExp(r'^[-*•\d.\s]+'), '').trim(),
          ),
    ];
  }
}

final aiClientProvider = Provider<OpenRouterClient>(
  (ref) => OpenRouterClient(),
);

final aiServiceProvider = Provider<AiService>(
  (ref) => AiService(client: ref.watch(aiClientProvider)),
);
