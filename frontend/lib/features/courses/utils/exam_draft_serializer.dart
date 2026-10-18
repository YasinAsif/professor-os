import 'dart:convert';

/// Tagged draft answer result decoded from server draft or envelope.
class ExamDraftResult {
  final String kind; // 'text' | 'programming' | 'mcq' | 'file'
  final String? text;
  final String? code;
  final Map<int, int> mcqAnswers;
  final String? fileName;

  ExamDraftResult({
    required this.kind,
    this.text,
    this.code,
    Map<int, int>? mcqAnswers,
    this.fileName,
  }) : mcqAnswers = mcqAnswers ?? {};
}

/// Canonical tagged envelope serializer & compatibility reader (Item 1.1).
class ExamDraftSerializer {
  /// Serialize current answers into tagged envelope: `{"v":1,"kind":"...","data":...}`.
  static String serialize({
    required String assignmentType,
    required bool hasOptions,
    String? text,
    String? code,
    Map<int, int>? mcqAnswers,
    String? fileName,
  }) {
    String kind = assignmentType;
    dynamic data;

    if (assignmentType == 'mcq') {
      if (!hasOptions) {
        // Fallback for MCQ without options: treat input as text
        kind = 'text';
        data = text ?? '';
      } else {
        kind = 'mcq';
        // Map integer keys to string keys for JSON serialization
        final map = <String, int>{};
        if (mcqAnswers != null) {
          mcqAnswers.forEach((k, v) => map[k.toString()] = v);
        }
        data = map;
      }
    } else if (assignmentType == 'programming') {
      kind = 'programming';
      data = code ?? '';
    } else if (assignmentType == 'file') {
      kind = 'file';
      data = fileName ?? '';
    } else {
      kind = 'text';
      data = text ?? '';
    }

    return jsonEncode({
      'v': 1,
      'kind': kind,
      'data': data,
    });
  }

  /// Compatibility reader for tagged envelope and legacy drafts.
  static ExamDraftResult deserialize(
    String? raw, {
    required String assignmentType,
    required bool hasOptions,
  }) {
    if (raw == null || raw.trim().isEmpty) {
      return ExamDraftResult(kind: assignmentType);
    }

    final trimmed = raw.trim();

    // 1. Attempt JSON decoding
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) {
          // Tagged envelope format: {"v": 1, "kind": "...", "data": ...}
          if (decoded.containsKey('v') && decoded.containsKey('kind')) {
            final kind = decoded['kind']?.toString() ?? assignmentType;
            final data = decoded['data'];

            if (kind == 'mcq' && data is Map) {
              final answers = <int, int>{};
              data.forEach((k, v) {
                final intKey = int.tryParse(k.toString());
                final intVal = int.tryParse(v.toString());
                if (intKey != null && intVal != null) {
                  answers[intKey] = intVal;
                }
              });
              return ExamDraftResult(kind: 'mcq', mcqAnswers: answers);
            } else if (kind == 'programming') {
              return ExamDraftResult(kind: 'programming', code: data?.toString() ?? '');
            } else if (kind == 'file') {
              return ExamDraftResult(kind: 'file', fileName: data?.toString());
            } else {
              return ExamDraftResult(kind: 'text', text: data?.toString() ?? '');
            }
          }

          // Legacy JSON map {"0": 1, "1": 2} for MCQ
          if (assignmentType == 'mcq' && hasOptions) {
            final answers = <int, int>{};
            var allNumeric = true;
            decoded.forEach((k, v) {
              final intKey = int.tryParse(k.toString());
              final intVal = int.tryParse(v.toString());
              if (intKey != null && intVal != null) {
                answers[intKey] = intVal;
              } else {
                allNumeric = false;
              }
            });
            if (allNumeric && answers.isNotEmpty) {
              return ExamDraftResult(kind: 'mcq', mcqAnswers: answers);
            }
          }

          // If student typed "{}" on text or MCQ with no options, treat as text
          if (!hasOptions || assignmentType != 'mcq') {
            return ExamDraftResult(kind: 'text', text: raw);
          }
        }
      } catch (_) {
        // Fall through to raw string treatment
      }
    }

    // 2. Raw string fallback
    if (assignmentType == 'mcq') {
      if (!hasOptions) {
        return ExamDraftResult(kind: 'text', text: raw);
      }
      return ExamDraftResult(kind: 'mcq');
    } else if (assignmentType == 'programming') {
      return ExamDraftResult(kind: 'programming', code: raw);
    } else if (assignmentType == 'file') {
      return ExamDraftResult(kind: 'file', fileName: raw);
    } else {
      return ExamDraftResult(kind: 'text', text: raw);
    }
  }
}
