import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/features/courses/utils/exam_draft_serializer.dart';

void main() {
  group('ExamDraftSerializer (Item 1.1)', () {
    test('serializes text envelope correctly', () {
      final jsonStr = ExamDraftSerializer.serialize(
        assignmentType: 'text',
        hasOptions: false,
        text: 'Student essay answer',
      );
      final result = ExamDraftSerializer.deserialize(
        jsonStr,
        assignmentType: 'text',
        hasOptions: false,
      );
      expect(result.kind, equals('text'));
      expect(result.text, equals('Student essay answer'));
    });

    test('serializes programming envelope correctly', () {
      final jsonStr = ExamDraftSerializer.serialize(
        assignmentType: 'programming',
        hasOptions: false,
        code: 'def solve(): return 42',
      );
      final result = ExamDraftSerializer.deserialize(
        jsonStr,
        assignmentType: 'programming',
        hasOptions: false,
      );
      expect(result.kind, equals('programming'));
      expect(result.code, equals('def solve(): return 42'));
    });

    test('MCQ with NO options serializes typed text as text semantics', () {
      final jsonStr = ExamDraftSerializer.serialize(
        assignmentType: 'mcq',
        hasOptions: false,
        text: 'Student typed text for unparsed mcq',
      );
      final result = ExamDraftSerializer.deserialize(
        jsonStr,
        assignmentType: 'mcq',
        hasOptions: false,
      );
      expect(result.kind, equals('text'));
      expect(result.text, equals('Student typed text for unparsed mcq'));
    });

    test('MCQ with options serializes selected choices as mcq kind', () {
      final jsonStr = ExamDraftSerializer.serialize(
        assignmentType: 'mcq',
        hasOptions: true,
        mcqAnswers: {0: 1, 1: 3},
      );
      final result = ExamDraftSerializer.deserialize(
        jsonStr,
        assignmentType: 'mcq',
        hasOptions: true,
      );
      expect(result.kind, equals('mcq'));
      expect(result.mcqAnswers, equals({0: 1, 1: 3}));
    });

    test('Legacy compatibility: student who types "{}" on text or unparsed mcq restores as text', () {
      final result = ExamDraftSerializer.deserialize(
        '{}',
        assignmentType: 'mcq',
        hasOptions: false,
      );
      expect(result.kind, equals('text'));
      expect(result.text, equals('{}'));
    });

    test('Legacy compatibility: old raw json map {"0": 1, "1": 2} restores as mcq choices', () {
      final result = ExamDraftSerializer.deserialize(
        '{"0": 1, "1": 2}',
        assignmentType: 'mcq',
        hasOptions: true,
      );
      expect(result.kind, equals('mcq'));
      expect(result.mcqAnswers, equals({0: 1, 1: 2}));
    });

    test('Legacy compatibility: old raw string restores as text for text assignment', () {
      final result = ExamDraftSerializer.deserialize(
        'plain legacy text answer',
        assignmentType: 'text',
        hasOptions: false,
      );
      expect(result.kind, equals('text'));
      expect(result.text, equals('plain legacy text answer'));
    });
  });
}
