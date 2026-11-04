import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/features/courses/presentation/assignment_detail_screen.dart';
import 'package:professor_os/features/courses/utils/mcq_parser.dart';

void main() {
  group('Structured Q&A Assessment parsing and presentation', () {
    const rawPayload = '''{
      "type": "text",
      "category": "midterm",
      "instructions": "Answer all 4 questions in detail.",
      "questions": [
        {
          "question": "Explain the concept of Object-Oriented Programming (OOP).",
          "marks": 5.0,
          "reference_answer": "OOP is based on encapsulation, abstraction, inheritance, polymorphism."
        },
        {
          "question": "Explain the difference between Manual Testing and Automation Testing.",
          "marks": 5.0,
          "reference_answer": "Manual is human-driven; automation uses scripts."
        }
      ]
    }''';

    test('parseStructuredExamQuestions parses multiple written questions', () {
      final questions = parseStructuredExamQuestions(rawPayload);
      expect(questions.length, 2);
      expect(questions[0]['question'], contains('Object-Oriented Programming'));
      expect(questions[0]['marks'], 5.0);
      expect(questions[1]['question'], contains('Manual Testing'));
    });

    test('parseExamInstructions extracts instructions header', () {
      final instructions = parseExamInstructions(rawPayload);
      expect(instructions, 'Answer all 4 questions in detail.');
    });

    test('AssignmentDetailScreen accepts structured Q&A initialAssignment', () {
      const screen = AssignmentDetailScreen(
        courseId: 68,
        assignmentId: 25,
        initialAssignment: {
          'id': 25,
          'title': 'testing',
          'type': 'text',
          'description': rawPayload,
          'max_marks': 20.0,
          'status': 'published',
        },
      );
      expect(screen.assignmentId, 25);
      expect(screen.initialAssignment?['title'], 'testing');
    });
  });
}
