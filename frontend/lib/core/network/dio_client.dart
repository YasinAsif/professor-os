/// ProfessorOS – Dio HTTP client with auth interceptor.

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_constants.dart';

const _storage = FlutterSecureStorage();

class DioClient {
  static Dio? _instance;

  static Dio get instance {
    _instance ??= _createDio();
    return _instance!;
  }

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ));

    dio.interceptors.add(_AuthInterceptor(dio));
    return dio;
  }

  /// Store tokens after login.
  static Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: 'access_token', value: access);
    await _storage.write(key: 'refresh_token', value: refresh);
  }

  /// Clear tokens on logout.
  static Future<void> clearTokens() async {
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  /// Check if user has a stored token.
  static Future<bool> hasToken() async {
    final token = await _storage.read(key: 'access_token');
    return token != null && token.isNotEmpty;
  }
}

/// Interceptor that attaches Bearer token and handles 401 refresh.
class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  bool _isRefreshing = false;

  _AuthInterceptor(this._dio);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _storage.read(key: 'access_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401 && !_isRefreshing) {
      _isRefreshing = true;
      try {
        final refreshToken = await _storage.read(key: 'refresh_token');
        if (refreshToken == null) {
          await DioClient.clearTokens();
          return handler.reject(err);
        }

        // Use a separate Dio instance to avoid interceptor loop.
        final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
        final response = await refreshDio.post(
          ApiConstants.refresh,
          data: {'refresh_token': refreshToken},
        );

        final newAccess = response.data['access_token'] as String;
        await _storage.write(key: 'access_token', value: newAccess);

        // Retry the original request.
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer $newAccess';
        final retryResponse = await _dio.fetch(opts);
        return handler.resolve(retryResponse);
      } catch (e) {
        await DioClient.clearTokens();
        return handler.reject(err);
      } finally {
        _isRefreshing = false;
      }
    }
    handler.next(err);
  }
}
