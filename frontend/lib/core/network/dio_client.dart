import 'dart:async';
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
    // Note: We intentionally do NOT delete biometric_email and biometric_password here,
    // so the user can use biometrics to log back in.
  }

  /// Store biometric credentials for local_auth login.
  static Future<void> saveBiometricCreds(String email, String password) async {
    await _storage.write(key: 'biometric_email', value: email);
    await _storage.write(key: 'biometric_password', value: password);
  }

  /// Check if biometric credentials exist.
  static Future<Map<String, String>?> getBiometricCreds() async {
    final email = await _storage.read(key: 'biometric_email');
    final password = await _storage.read(key: 'biometric_password');
    if (email != null && password != null && email.isNotEmpty && password.isNotEmpty) {
      return {'email': email, 'password': password};
    }
    return null;
  }

  /// Check if user has a stored token.
  static Future<bool> hasToken() async {
    final token = await _storage.read(key: 'access_token');
    return token != null && token.isNotEmpty;
  }

  /// Get stored access token.
  static Future<String?> getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }
}

/// Interceptor that attaches Bearer token and handles 401 refresh.
/// Uses a Completer-based queue to prevent race conditions when multiple
/// requests receive 401 simultaneously — only one refresh is executed,
/// all others wait for its result.
class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  final _refreshLock = _RefreshLock();

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
    if (err.response?.statusCode == 401) {
      // Wait for or trigger token refresh
      final newAccess = await _refreshLock.performRefresh(_doRefresh);
      if (newAccess == null) {
        return handler.reject(err);
      }

      // Retry the original request with new token
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer $newAccess';
      final retryResponse = await _dio.fetch(opts);
      return handler.resolve(retryResponse);
    }
    handler.next(err);
  }

  Future<String?> _doRefresh() async {
    final refreshToken = await _storage.read(key: 'refresh_token');
    if (refreshToken == null) {
      await DioClient.clearTokens();
      return null;
    }

    // Use a separate Dio instance to avoid interceptor loop.
    final refreshDio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));
    final response = await refreshDio.post(
      ApiConstants.refresh,
      data: {'refresh_token': refreshToken},
    );

    // Validate refresh response
    if (response.statusCode != 200 || response.data == null) {
      await DioClient.clearTokens();
      return null;
    }

    final data = response.data as Map<String, dynamic>;
    final newAccess = data['access_token'] as String?;
    if (newAccess == null || newAccess.isEmpty) {
      await DioClient.clearTokens();
      return null;
    }

    await _storage.write(key: 'access_token', value: newAccess);
    return newAccess;
  }
}

/// A simple lock that ensures only one refresh operation runs at a time.
/// All callers wait on the same Completer; the first caller executes the
/// refresh, and all others receive its result (success or failure).
class _RefreshLock {
  _RefreshLock();

  Future<String?> performRefresh(Future<String?> Function() refreshFn) async {
    // Fast path: if already refreshing, wait for existing completer
    if (_completer != null) {
      return _completer!.future;
    }

    // Create new completer and start refresh
    _completer = Completer<String?>();
    try {
      final result = await refreshFn();
      _completer!.complete(result);
      return result;
    } catch (e) {
      _completer!.completeError(e);
      return null;
    } finally {
      _completer = null;
    }
  }

  Completer<String?>? _completer;
}
