import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/features/courses/utils/mcq_parser.dart';

void main() {
  test('parses quiz-builder MCQ JSON into student questions', () {
    final questions = parseMcqDescription(jsonEncode({
      'type': 'mcq',
      'questions': [
        {
          'question': 'What is OBE?',
          'options': ['Outcome based education', 'Online backup engine'],
          'correctAnswer': 0,
        },
      ],
    }));

    expect(questions, hasLength(1));
    expect(questions.single['question'], 'What is OBE?');
    expect(questions.single['options'],
        ['Outcome based education', 'Online backup engine']);
    expect(questions.single['correctAnswer'], 0);
  });

  test('returns no questions for ordinary assignment text', () {
    expect(parseMcqDescription('Write a short answer.'), isEmpty);
  });

  test('parses structured 4-question Midterm questions', () {
    final payload = jsonEncode({
      'type': 'text',
      'category': 'midterm',
      'instructions': 'Answer all 4 questions carefully.',
      'questions': [
        {'question': 'Explain OOP concepts', 'marks': 5.0},
        {'question': 'Describe ACID properties', 'marks': 5.0},
        {'question': 'What is normal form?', 'marks': 5.0},
        {'question': 'Compare TCP and UDP', 'marks': 5.0},
      ],
    });

    final questions = parseStructuredExamQuestions(payload);
    expect(questions, hasLength(4));
    expect(questions[0]['question'], 'Explain OOP concepts');
    expect(questions[3]['marks'], 5.0);

    final instructions = parseExamInstructions(payload);
    expect(instructions, 'Answer all 4 questions carefully.');
  });

  test('parses markdown/plaintext MCQs gracefully', () {
    const rawMarkdown = '''
1. What is CAP theorem?
A) Consistency, Availability, Partition tolerance
B) Cache, Authentication, Protocol
C) Cloud, Automation, Privacy
Answer: A
''';
    final questions = parseMcqDescription(rawMarkdown);
    expect(questions, hasLength(1));
    expect(questions.first['question'], 'What is CAP theorem?');
    expect(questions.first['options'], hasLength(3));
    expect(questions.first['options'][0],
        'Consistency, Availability, Partition tolerance');
    expect(questions.first['correct'], 0);
  });

  test('preserves structured short questions even in hybrid payload', () {
    final hybridPayload = jsonEncode({
      'type': 'hybrid',
      'questions': [
        {
          'question': 'What is CAP theorem?',
          'options': ['Option A', 'Option B'],
          'correct': 0,
        },
        {
          'question': 'Explain Paxos consensus invariants in detail.',
          'marks': 5.0,
        },
      ],
    });

    final mcqs = parseMcqDescription(hybridPayload);
    final textQs = parseStructuredExamQuestions(hybridPayload);

    expect(mcqs, hasLength(2));
    expect(textQs, hasLength(1));
    expect(textQs.single['question'],
        'Explain Paxos consensus invariants in detail.');
  });
}
