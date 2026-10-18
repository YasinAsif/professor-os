String examRoutePath(int courseId, int assignmentId) =>
    '/courses/$courseId/assignments/$assignmentId/exam';

Map<String, dynamic> examRouteExtra({
  required String title,
  required String type,
  required String? description,
  required double maxMarks,
  required int? timeLimitMinutes,
  required bool randomizeQuestions,
  required bool showResultsAfter,
}) => {
      'title': title,
      'type': type,
      'description': description,
      'max_marks': maxMarks,
      'time_limit_minutes': timeLimitMinutes,
      'randomize_questions': randomizeQuestions,
      'show_results_after': showResultsAfter,
    };
