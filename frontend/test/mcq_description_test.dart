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
}
