Map<String, dynamic> emptyExamSubmission(
  String assignmentType, {
  required bool autoSubmitted,
}) {
  final content = switch (assignmentType) {
    'file' => '[No File Attached]',
    'programming' => autoSubmitted
        ? '// [Time Expired - Auto-Submitted by System]'
        : '// [Submitted with empty response]',
    'mcq' => autoSubmitted
        ? '[Time Expired - No answers selected]'
        : '[No answers selected]',
    _ => autoSubmitted
        ? '[Time Expired - Auto-Submitted by System]'
        : '[Submitted with empty response]',
  };
  return {'submission_type': assignmentType, 'content': content};
}
