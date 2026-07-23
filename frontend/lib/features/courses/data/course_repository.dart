/// ProfessorOS – Course repository.

import 'package:dio/dio.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/network/dio_client.dart';

class CourseRepository {
  final Dio _dio = DioClient.instance;

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

  Future<Map<String, dynamic>> updateCourse(int id, Map<String, dynamic> data) async {
    final response = await _dio.put(ApiConstants.course(id), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<void> archiveCourse(int id) async {
    await _dio.delete(ApiConstants.course(id));
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

  Future<Map<String, dynamic>> importEnrollmentsCsv(int courseId, List<int> fileBytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: filename),
    });
    final response = await _dio.post(ApiConstants.courseEnrollCsv(courseId), data: formData);
    return response.data as Map<String, dynamic>;
  }

  Future<List<dynamic>> listClos(int courseId) async {
    final response = await _dio.get(ApiConstants.courseClos(courseId));
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> createClo(int courseId, String code, String description) async {
    final response = await _dio.post(ApiConstants.courseClos(courseId), data: {
      'code': code,
      'description': description,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> listAssignments(int courseId, {String? status, int page = 1, int pageSize = 50}) async {
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

  Future<Map<String, dynamic>> createAssignment(int courseId, Map<String, dynamic> data) async {
    final response = await _dio.post(ApiConstants.courseAssignments(courseId), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateAssignment(int courseId, int aid, Map<String, dynamic> data) async {
    final response = await _dio.put(ApiConstants.assignment(courseId, aid), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> publishAssignment(int courseId, int aid) async {
    final response = await _dio.post(ApiConstants.publishAssignment(courseId, aid));
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

  Future<Map<String, dynamic>> saveRubric(int aid, Map<String, dynamic> data) async {
    final response = await _dio.post(ApiConstants.rubric(aid), data: data);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> joinCourse(String joinCode) async {
    final response = await _dio.post('${ApiConstants.courses}/join', data: {
      'join_code': joinCode,
    });
    return response.data as Map<String, dynamic>;
  }
}
