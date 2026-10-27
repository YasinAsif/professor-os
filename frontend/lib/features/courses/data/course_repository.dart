/// ProfessorOS – Course repository.

import 'package:dio/dio.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/network/dio_client.dart';

class CourseRepository {
  final Dio _dio;

  CourseRepository({Dio? dio}) : _dio = dio ?? DioClient.instance;

  Future<Map<String, dynamic>> listCourses() async {
    final response = await _dio.get(ApiConstants.courses);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCourse(int id) async {
    final response = await _dio.get(ApiConstants.course(id));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createCourse(Map<String, dynamic> data) async {
    final response = await _dio.post(ApiConstants.courses, data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateCourse(
      int id, Map<String, dynamic> data) async {
    final response = await _dio.put(ApiConstants.course(id), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> archiveCourse(int id) async {
    await _dio.delete(ApiConstants.course(id));
  }

  Future<void> permanentlyDeleteCourse(int id) async {
    await _dio.delete(ApiConstants.permanentDeleteCourse(id));
  }

  Future<List<dynamic>> listEnrollments(int courseId) async {
    final response = await _dio.get(ApiConstants.courseEnrollments(courseId));
    return response.data as List<dynamic>;
  }

  Future<void> enrollUser(int courseId, int userId, String role) async {
    await _dio.post(ApiConstants.courseEnroll(courseId), data: {
      'user_id': userId,
      'role': role,
    });
  }

  Future<void> removeEnrollment(int courseId, int userId) async {
    await _dio.delete('${ApiConstants.courseEnroll(courseId)}/$userId');
  }

  Future<Map<String, dynamic>> importEnrollmentsCsv(
      int courseId, List<int> fileBytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: filename),
    });
    final response =
        await _dio.post(ApiConstants.courseEnrollCsv(courseId), data: formData);
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> listClos(int courseId) async {
    final response = await _dio.get(ApiConstants.courseClos(courseId));
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createClo(
      int courseId, String code, String description) async {
    final response = await _dio.post(ApiConstants.courseClos(courseId), data: {
      'code': code,
      'description': description,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteClo(int courseId, int cloId) async {
    await _dio.delete('${ApiConstants.courseClos(courseId)}/$cloId');
  }

  Future<Map<String, dynamic>> listAssignments(int courseId,
      {String? status, int page = 1, int pageSize = 50}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    params['page'] = page;
    params['page_size'] = pageSize;
    final response = await _dio.get(
      ApiConstants.courseAssignments(courseId),
      queryParameters: params,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createAssignment(
      int courseId, Map<String, dynamic> data) async {
    final response =
        await _dio.post(ApiConstants.courseAssignments(courseId), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAssignment(
      int courseId, int aid, Map<String, dynamic> data) async {
    final response =
        await _dio.put(ApiConstants.assignment(courseId, aid), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> publishAssignment(int courseId, int aid) async {
    final response =
        await _dio.post(ApiConstants.publishAssignment(courseId, aid));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAssignment(int courseId, int aid) async {
    final response = await _dio.get(ApiConstants.assignment(courseId, aid));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getRubric(int aid) async {
    try {
      final response = await _dio.get(ApiConstants.rubric(aid));
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> saveRubric(
      int aid, Map<String, dynamic> data) async {
    final response = await _dio.post(ApiConstants.rubric(aid), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> joinCourse(String joinCode) async {
    final response = await _dio.post('${ApiConstants.courses}/join', data: {
      'join_code': joinCode,
    });
    return response.data as Map<String, dynamic>;
  }

  // ── Submission methods ──────────────────────────────

  Future<Map<String, dynamic>> submitAssignment(
      int courseId, int aid, Map<String, dynamic> data) async {
    final response =
        await _dio.post(ApiConstants.submissions(courseId, aid), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitFile(
      int courseId, int aid, List<int> fileBytes, String filename,
      {bool autoSubmitted = false}) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: filename),
      'auto_submitted': autoSubmitted.toString(),
    });
    final response = await _dio.post(
      ApiConstants.submitFile(courseId, aid),
      data: formData,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getMySubmission(int courseId, int aid) async {
    try {
      final response = await _dio.get(ApiConstants.mySubmission(courseId, aid));
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> listSubmissions(int courseId, int aid) async {
    final response = await _dio.get(ApiConstants.submissions(courseId, aid));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> gradeSubmission(
      int sid, double score, String? feedback) async {
    final response = await _dio.put(
      ApiConstants.gradeSubmission(sid),
      data: {'score': score, 'feedback': feedback},
    );
    return response.data as Map<String, dynamic>;
  }


  Future<Map<String, dynamic>> submitGradeAppeal(
    int submissionId, {
    String? challengedCriterion,
    required String justification,
  }) async {
    final response = await _dio.post(
      ApiConstants.submitAppeal(submissionId),
      data: {
        'challenged_criterion': challengedCriterion,
        'justification': justification,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> getSubmissionAppeal(int submissionId) async {
    try {
      final response = await _dio.get(ApiConstants.getAppeal(submissionId));
      if (response.data == null) return null;
      return response.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAssignmentAppeals(int assignmentId) async {
    final response = await _dio.get(ApiConstants.assignmentAppeals(assignmentId));
    final list = response.data as List? ?? [];
    return list.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> resolveGradeAppeal(
    int appealId, {
    required String status,
    double? adjustedScore,
    String? professorFeedback,
  }) async {
    final response = await _dio.patch(
      ApiConstants.resolveAppeal(appealId),
      data: {
        'status': status,
        if (adjustedScore != null) 'adjusted_score': adjustedScore,
        if (professorFeedback != null) 'professor_feedback': professorFeedback,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> aiGradeSubmission(int sid,
      {bool sync = true}) async {
    final response = await _dio.post(
      ApiConstants.aiGradeSubmission(sid),
      queryParameters: {'sync': sync},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> batchAiGrade(int courseId, int aid) async {
    final response = await _dio.post(ApiConstants.batchAiGrade(courseId, aid));
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteAssignment(int courseId, int aid) async {
    await _dio.delete(ApiConstants.deleteAssignment(courseId, aid));
  }

  Future<Map<String, dynamic>> getStudentDashboard() async {
    final response = await _dio.get(ApiConstants.studentDashboard);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> ingestCourseMaterial(
      int courseId, List<int> fileBytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: filename),
    });
    final response = await _dio.post(
      '/courses/$courseId/materials/ingest',
      data: formData,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> chatWithCourse(
    int courseId,
    String message, {
    String? sessionId,
    List<Map<String, String>>? history,
  }) async {
    final data = <String, dynamic>{'message': message};
    if (sessionId != null && sessionId.isNotEmpty) {
      data['session_id'] = sessionId;
    }
    if (history != null && history.isNotEmpty) {
      data['history'] = history;
    }
    final response = await _dio.post(
      ApiConstants.courseChat(courseId),
      data: data,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> listAssignmentTAs(int courseId, int aid) async {
    final response = await _dio.get(ApiConstants.assignmentTAs(courseId, aid));
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> assignTA(
      int courseId, int aid, int taUserId) async {
    final response = await _dio.post(
      ApiConstants.assignmentTAs(courseId, aid),
      data: {'user_id': taUserId},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> removeTA(int courseId, int aid, int taUserId) async {
    await _dio.delete(ApiConstants.assignmentTA(courseId, aid, taUserId));
  }

  Future<void> deleteRubric(int aid) async {
    await _dio.delete(ApiConstants.deleteRubric(aid));
  }

  // ── Enroll by email ─────────────────────────────────

  Future<void> enrollUserByEmail(
      int courseId, String email, String role) async {
    await _dio.post(ApiConstants.courseEnroll(courseId),
        data: {'email': email, 'role': role});
  }

  // ── Exam methods ───────────────────────────────

  Future<Map<String, dynamic>> startExam(int courseId, int aid, {String? biometricStatus}) async {
    final response = await _dio.post(
      ApiConstants.examStart(courseId, aid),
      queryParameters: biometricStatus != null ? {'biometric_status': biometricStatus} : null,
    );
    return response.data as Map<String, dynamic>;
  }


  Future<Map<String, dynamic>> reportAttemptViolation(
    int attemptId, {
    required String type,
    String? details,
  }) async {
    final response = await _dio.post(
      ApiConstants.attemptViolations(attemptId),
      data: {
        'type': type,
        if (details != null && details.isNotEmpty) 'details': details,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendHeartbeat(
    int attemptId, {
    String? answers,
  }) async {
    final response = await _dio.post(
      ApiConstants.attemptHeartbeat(attemptId),
      data: {
        if (answers != null) 'answers': answers,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getAttemptState(int attemptId) async {
    final response = await _dio.get(ApiConstants.attemptState(attemptId));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getExamState(int courseId, int aid) async {
    final response = await _dio.get(ApiConstants.examState(courseId, aid));
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> submitExam(int courseId, int aid, {Map<String, dynamic>? data}) async {
    final response = await _dio.post(ApiConstants.examSubmit(courseId, aid), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> listExamAttempts(int courseId, int aid) async {
    final response = await _dio.get(ApiConstants.examAttempts(courseId, aid));
    return response.data as List<dynamic>;
  }


  Future<Map<String, dynamic>> recordExamDecision({
    required int courseId,
    required int aid,
    required int attemptId,
    required String action,
    required String reason,
  }) async {
    final response = await _dio.post(
      ApiConstants.examAttemptDecision(courseId, aid, attemptId),
      data: {
        'action': action,
        'reason': reason,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateExamSettings({
    required int courseId,
    required int aid,
    required Map<String, dynamic> settings,
  }) async {
    final response = await _dio.put(
      ApiConstants.examSettings(courseId, aid),
      data: settings,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<String> exportExamCsv({
    required int courseId,
    required int aid,
  }) async {
    final response = await _dio.get(
      ApiConstants.examExportCsv(courseId, aid),
      options: Options(responseType: ResponseType.plain),
    );
    return response.data.toString();
  }


  // ── Course Materials (Docling / RAG Ingestion) ──

  Future<List<Map<String, dynamic>>> getCourseMaterials(int courseId) async {
    final response = await _dio.get(ApiConstants.courseMaterials(courseId));
    final data = response.data as Map<String, dynamic>;
    final raw = data['materials'] as List<dynamic>? ?? [];
    return raw.map((m) => Map<String, dynamic>.from(m as Map)).toList();
  }

  Future<Map<String, dynamic>> uploadCourseMaterial(
      int courseId, List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post(
      ApiConstants.uploadCourseMaterial(courseId),
      data: formData,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteCourseMaterial(int courseId, String materialId) async {
    await _dio.delete('/courses/$courseId/materials/$materialId');
  }

  // ── AI Question Bank & OBE Attainment ──

  Future<List<Map<String, dynamic>>> getQuestionBank(int courseId,
      {String? status, String? bloomLevel}) async {
    final response = await _dio.get(
      '/courses/$courseId/question-bank',
      queryParameters: {
        if (status != null && status.isNotEmpty) 'status': status,
        if (bloomLevel != null && bloomLevel.isNotEmpty)
          'bloom_level': bloomLevel,
      },
    );
    final raw = response.data as List<dynamic>? ?? [];
    return raw.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<Map<String, dynamic>> approveQuestion(String questionId) async {
    final response = await _dio.post('/question-bank/$questionId/approve');
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> rejectQuestion(String questionId) async {
    final response = await _dio.post('/question-bank/$questionId/reject');
    return response.data as Map<String, dynamic>;
  }
}
