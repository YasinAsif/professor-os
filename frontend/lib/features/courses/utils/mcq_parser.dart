import 'dart:convert';

/// Parses JSON description containing MCQ questions.
List<Map<String, dynamic>> parseMcqDescription(String? description) {
  if (description == null || description.trim().isEmpty) return [];
  try {
    final decoded = jsonDecode(description);
    if (decoded is! Map) return [];
    final rawQuestions = decoded['questions'];
    if (rawQuestions is! List) return [];
    final list = rawQuestions
        .whereType<Map>()
        .map((question) => Map<String, dynamic>.from(question))
        .where((question) =>
            question['question']?.toString().trim().isNotEmpty == true)
        .toList();
    if (list.isEmpty) return [];
    final type = decoded['type']?.toString().toLowerCase();
    if (type == 'mcq' ||
        type == 'hybrid' ||
        list.any((q) => q['options'] is List && (q['options'] as List).length >= 2)) {
      return list;
    }
    return [];
  } catch (_) {
    return [];
  }
}

/// Parses JSON description containing structured written exam questions (Midterm/Final).
List<Map<String, dynamic>> parseStructuredExamQuestions(String? description) {
  if (description == null || description.trim().isEmpty) return [];
  try {
    final decoded = jsonDecode(description);
    if (decoded is! Map) return [];
    final rawQuestions = decoded['questions'];
    if (rawQuestions is! List) return [];
    final list = rawQuestions
        .whereType<Map>()
        .map((question) => Map<String, dynamic>.from(question))
        .where((question) =>
            question['question']?.toString().trim().isNotEmpty == true ||
            question['text']?.toString().trim().isNotEmpty == true)
        .toList();
    if (list.isEmpty) return [];
    final hasOptions = list.any((q) => q['options'] is List && (q['options'] as List).length >= 2);
    if (hasOptions) return [];
    return list;
  } catch (_) {
    return [];
  }
}

/// Extracts instructions / problem statement from exam description JSON or raw text.
String parseExamInstructions(String? description) {
  if (description == null || description.trim().isEmpty) return '';
  try {
    final decoded = jsonDecode(description);
    if (decoded is Map) {
      final inst = (decoded['instructions'] ?? decoded['instruction'] ?? decoded['prompt'])?.toString();
      if (inst != null && inst.trim().isNotEmpty) {
        return inst.trim();
      }
      return '';
    }
  } catch (_) {}
  return description.trim();
}
