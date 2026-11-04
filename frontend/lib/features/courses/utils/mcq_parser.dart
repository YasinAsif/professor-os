import 'dart:convert';

/// Parses JSON description or markdown plaintext containing MCQ questions.
List<Map<String, dynamic>> parseMcqDescription(String? description) {
  if (description == null || description.trim().isEmpty) return [];
  try {
    final decoded = jsonDecode(description);
    if (decoded is Map) {
      final rawQuestions = decoded['questions'];
      if (rawQuestions is List) {
        final list = rawQuestions
            .whereType<Map>()
            .map((question) {
              final qMap = Map<String, dynamic>.from(question);
              final rawOpts = qMap['options'];
              if (rawOpts is List) {
                qMap['options'] = rawOpts.map((opt) {
                  if (opt is Map) {
                    return (opt['text'] ?? opt['option'] ?? opt['label'] ?? opt.toString()).toString();
                  }
                  return opt.toString();
                }).toList();
              }
              return qMap;
            })
            .where((question) =>
                question['question']?.toString().trim().isNotEmpty == true)
            .toList();
        if (list.isNotEmpty) {
          final type = decoded['type']?.toString().toLowerCase();
          if (type == 'mcq' ||
              type == 'hybrid' ||
              list.any((q) => q['options'] is List && (q['options'] as List).length >= 2)) {
            return list;
          }
        }
      }
    }
  } catch (_) {
    // Fall through to plaintext/markdown parsing
  }

  // Fallback: parse markdown / plaintext MCQs (e.g. 1. What is X?\nA) ...\nB) ...)
  return _parsePlaintextMcqs(description);
}

/// Fallback parser for plaintext/markdown MCQ descriptions.
List<Map<String, dynamic>> _parsePlaintextMcqs(String description) {
  final blocks = description.split(RegExp(r'(?:\n|^)(?:\d+[\.\)]|\*{1,2}Question\s*\d+[\.\:]?\*{0,2}|Q\d+[:\.]?)\s*'));
  final results = <Map<String, dynamic>>[];
  for (final block in blocks) {
    final trimmed = block.trim();
    if (trimmed.isEmpty) continue;
    final lines = trimmed.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) continue;
    final prompt = lines[0];
    final options = <String>[];
    dynamic correct = 0;
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i];
      final optMatch = RegExp(r'^[A-Ea-e][\.\)]\s*(.*)').firstMatch(line);
      final ansMatch = RegExp(r'^(?:Answer|Correct)[:\s]*([A-Ea-e\d])', caseSensitive: false).firstMatch(line);
      if (optMatch != null) {
        options.add(optMatch.group(1)?.trim() ?? line);
      } else if (ansMatch != null) {
        final ansStr = ansMatch.group(1)?.trim();
        if (ansStr != null && RegExp(r'^[A-Ea-e]$').hasMatch(ansStr)) {
          correct = ansStr.toUpperCase().codeUnitAt(0) - 65;
        } else if (ansStr != null) {
          correct = int.tryParse(ansStr) ?? 0;
        }
      }
    }
    if (options.length >= 2) {
      results.add({
        'question': prompt,
        'options': options,
        'correct': correct,
      });
    }
  }
  return results;
}

/// Parses JSON description containing structured written exam questions (Midterm/Final/Short Questions).
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
    // Keep written / short / essay questions (no MCQ options with >= 2 items)
    final textOnly = list.where((q) {
      final opts = q['options'];
      return opts is! List || opts.length < 2;
    }).toList();
    return textOnly;
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


/// Model representing a parsed student response to an MCQ question.
class FormattedMcqChoice {
  final int questionNumber;
  final String questionPrompt;
  final String selectedOptionLetter;
  final String selectedOptionText;

  FormattedMcqChoice({
    required this.questionNumber,
    required this.questionPrompt,
    required this.selectedOptionLetter,
    required this.selectedOptionText,
  });
}

/// Parses raw student submission content (e.g. `{"0": 1}`) against assessment MCQ questions.
/// Returns null if content is not JSON map or no choices could be parsed.
List<FormattedMcqChoice>? parseSubmittedMcqChoices(String? content, String? description) {
  if (content == null || content.trim().isEmpty) return null;
  final trimmed = content.trim();
  if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) return null;

  Map<String, dynamic> choicesMap = {};
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is Map) {
      choicesMap = decoded.map((k, v) => MapEntry(k.toString(), v));
    } else if (decoded is List) {
      for (int i = 0; i < decoded.length; i++) {
        choicesMap[i.toString()] = decoded[i];
      }
    } else {
      return null;
    }
  } catch (_) {
    return null;
  }

  if (choicesMap.isEmpty) return null;

  final questions = parseMcqDescription(description);
  final List<FormattedMcqChoice> formatted = [];

  final sortedKeys = choicesMap.keys.toList()
    ..sort((a, b) {
      final numA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final numB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return numA.compareTo(numB);
    });

  for (final key in sortedKeys) {
    final qIdx = int.tryParse(key.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final val = choicesMap[key];

    Map<String, dynamic>? qData;
    if (qIdx < questions.length) {
      qData = questions[qIdx];
    }

    final prompt = (qData?['question'] ?? 'Question ${qIdx + 1}').toString();
    final rawOptions = qData?['options'];
    final List<String> options = (rawOptions is List)
        ? rawOptions.map((e) => e.toString()).toList()
        : [];

    String letter = '';
    String optText = '';

    if (val is int) {
      letter = val >= 0 && val < 26 ? String.fromCharCode(65 + val) : '${val + 1}';
      if (val >= 0 && val < options.length) {
        optText = options[val];
      }
    } else if (val is String) {
      final valStr = val.trim();
      final asInt = int.tryParse(valStr);
      if (asInt != null) {
        letter = asInt >= 0 && asInt < 26 ? String.fromCharCode(65 + asInt) : '${asInt + 1}';
        if (asInt >= 0 && asInt < options.length) {
          optText = options[asInt];
        }
      } else if (RegExp(r'^[A-Za-z]$').hasMatch(valStr)) {
        letter = valStr.toUpperCase();
        final lIdx = letter.codeUnitAt(0) - 65;
        if (lIdx >= 0 && lIdx < options.length) {
          optText = options[lIdx];
        }
      } else {
        optText = valStr;
        for (int oi = 0; oi < options.length; oi++) {
          if (options[oi].toLowerCase() == valStr.toLowerCase()) {
            letter = String.fromCharCode(65 + oi);
            break;
          }
        }
      }
    } else if (val != null) {
      optText = val.toString();
    }

    formatted.add(FormattedMcqChoice(
      questionNumber: qIdx + 1,
      questionPrompt: prompt,
      selectedOptionLetter: letter.isNotEmpty ? letter : 'Choice',
      selectedOptionText: optText,
    ));
  }

  return formatted.isNotEmpty ? formatted : null;
}
