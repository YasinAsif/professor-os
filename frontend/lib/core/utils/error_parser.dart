/// ProfessorOS – Error message parser.
/// Converts raw DioException/error objects into user-friendly strings.

import 'package:dio/dio.dart';

class ErrorParser {
  ErrorParser._();

  static String parse(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map<String, dynamic>) {
        final detail = data['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
        if (detail is List && detail.isNotEmpty) {
          return detail.map((e) => e['msg'] ?? e.toString()).join(', ');
        }
      }
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.sendTimeout:
          return 'Connection timed out. Check your network and try again.';
        case DioExceptionType.connectionError:
          return 'Could not reach the server. Check your network connection.';
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode ?? 0;
          if (code == 401) return 'Session expired. Please log in again.';
          if (code == 403) return 'You do not have permission to do this.';
          if (code == 404) return 'The requested resource was not found.';
          if (code == 429) return 'Too many requests. Please wait and try again.';
          if (code >= 500) return 'Server error. Please try again later.';
          return 'An error occurred (${code}).';
        default:
          return 'An unexpected network error occurred.';
      }
    }
    final msg = error.toString();
    if (msg.contains('Exception:')) {
      return msg.split('Exception:').last.trim();
    }
    return msg;
  }
}
