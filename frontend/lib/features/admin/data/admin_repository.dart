/// ProfessorOS – Admin Repository.

import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/network/dio_client.dart';

class AdminRepository {
  final Dio _dio = DioClient.instance;

  Future<Map<String, dynamic>> listUsers({
    int page = 1,
    int pageSize = 50,
    String? role,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (role != null && role != 'all') queryParams['role'] = role;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await _dio.get(
      ApiConstants.adminUsers,
      queryParameters: queryParams,
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> importUsersCsv(Uint8List fileBytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: filename),
    });
    final response = await _dio.post(ApiConstants.adminImport, data: formData);
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateUserStatus(int userId, bool isActive) async {
    final response = await _dio.patch(
      ApiConstants.adminUserStatus(userId),
      data: {'is_active': isActive},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<void> deleteUser(int userId) async {
    await _dio.delete(ApiConstants.adminUserDelete(userId));
  }
}
