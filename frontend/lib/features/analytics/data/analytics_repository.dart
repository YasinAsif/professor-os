/// ProfessorOS – Analytics repository.

import 'package:dio/dio.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/network/dio_client.dart';

class AnalyticsRepository {
  final Dio _dio = DioClient.instance;

  Future<Map<String, dynamic>> getDashboard(int courseId) async {
    final response = await _dio.get(ApiConstants.courseAnalytics(courseId));
    return response.data as Map<String, dynamic>;
  }

  Future<void> refreshAnalytics(int courseId, {double threshold = 50.0}) async {
    await _dio.post(
      '${ApiConstants.courseAnalytics(courseId)}/refresh',
      queryParameters: {'threshold': threshold},
    );
  }

  Future<List<dynamic>> getAtRiskStudents(int courseId) async {
    final response = await _dio.get('${ApiConstants.courseAnalytics(courseId)}/at-risk');
    return response.data as List<dynamic>;
  }
}
