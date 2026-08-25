import 'dart:convert';

/// A single checklist item stored inside a task's checklistJson field.
class ChecklistItem {
  const ChecklistItem({required this.text, this.done = false});

  final String text;
  final bool done;

  Map<String, dynamic> toJson() => {'text': text, 'done': done};

  factory ChecklistItem.fromJson(Map<String, dynamic> json) {
    return ChecklistItem(
      text: json['text'] as String? ?? '',
      done: json['done'] as bool? ?? false,
    );
  }
}

List<ChecklistItem> parseChecklist(String? json) {
  if (json == null || json.isEmpty) return const [];
  try {
    final data = jsonDecode(json) as List;
    return data
        .map((e) => ChecklistItem.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return const [];
  }
}

String encodeChecklist(List<ChecklistItem> items) {
  return jsonEncode([for (final i in items) i.toJson()]);
}
