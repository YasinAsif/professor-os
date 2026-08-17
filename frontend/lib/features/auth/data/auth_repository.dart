/// ProfessorOS – Auth repository (API calls for authentication).

import 'package:dio/dio.dart';
import '../../../core/network/api_constants.dart';
import '../../../core/network/dio_client.dart';

class AuthRepository {
  final Dio _dio = DioClient.instance;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _dio.post(ApiConstants.login, data: {
      'email': email,
      'password': password,
    });
    final data = response.data as Map<String, dynamic>;
    await DioClient.saveTokens(data['access_token'], data['refresh_token']);
    return data;
  }

  Future<Map<String, dynamic>> register(String email, String fullName, String password, String role) async {
    final res = await _dio.post(ApiConstants.register, data: {
      'email': email,
      'full_name': fullName,
      'password': password,
      'role': role,
    });
    final map = res.data as Map<String, dynamic>? ?? {};
    return {
      'token': map['verification_token'] as String?,
      'approval_required': map['approval_required'] == true,
      'message': map['message'] as String?,
    };
  }

  Future<void> verifyEmail(String token) async {
    await _dio.get(ApiConstants.verifyEmail, queryParameters: {'token': token});
  }

  Future<void> resendVerification(String email) async {
    await _dio.post(ApiConstants.resendVerification, data: {'email': email});
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post(ApiConstants.forgotPassword, data: {'email': email});
  }

  Future<void> resetPassword(String token, String newPassword) async {
    await _dio.post(ApiConstants.resetPassword, data: {
      'token': token,
      'new_password': newPassword,
    });
  }

  Future<Map<String, dynamic>> getMe() async {
    final response = await _dio.get(ApiConstants.me);
    return response.data as Map<String, dynamic>;
  }

  Future<void> updateProfile(String fullName) async {
    await _dio.put(ApiConstants.me, data: {'full_name': fullName});
  }

  Future<void> changePassword(String oldPassword, String newPassword) async {
    await _dio.put(ApiConstants.changePassword, data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }

  Future<void> signOutAll() async {
    await _dio.delete(ApiConstants.signOutAll);
    await DioClient.clearTokens();
  }

  Future<void> logout() async {
    try {
      await _dio.post(ApiConstants.logout);
    } finally {
      await DioClient.clearTokens();
    }
  }
}
