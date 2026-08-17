import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/features/auth/data/auth_repository.dart';

class _MockHttpClientAdapter extends HttpClientAdapter {
  final Map<String, dynamic> Function(RequestOptions options) handler;

  _MockHttpClientAdapter(this.handler);

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<dynamic>? cancelFuture,
  ) async {
    final response = handler(options);
    final payload = response['data'];
    final body = jsonEncode(payload ?? {});

    return ResponseBody(
      Stream.value(utf8.encode(body)),
      response['statusCode'] ?? 200,
      headers: response['headers'] ?? {},
      statusMessage: response['statusMessage'] ?? '',
      isRedirect: false,
      redirects: const [],
    );
  }
}

void main() {
  test('AuthRepository.login posts credentials and returns tokens', () async {
    final dio = Dio()
      ..httpClientAdapter = _MockHttpClientAdapter((options) {
        expect(options.method, 'POST');
        expect(options.path, '/auth/login');
        expect(options.data, {
          'email': 'student@example.com',
          'password': 'secret123',
        });

        return {
          'data': {
            'access_token': 'access-123',
            'refresh_token': 'refresh-456',
            'user': {'id': 1, 'email': 'student@example.com'},
          },
        };
      });

    final repository = AuthRepository(dio: dio);

    final result = await repository.login('student@example.com', 'secret123');

    expect(result['access_token'], 'access-123');
    expect(result['refresh_token'], 'refresh-456');
  });

  test('AuthRepository.register sends registration payload', () async {
    final dio = Dio()
      ..httpClientAdapter = _MockHttpClientAdapter((options) {
        expect(options.method, 'POST');
        expect(options.path, '/auth/register');
        expect(options.data, {
          'email': 'teacher@example.com',
          'full_name': 'Teacher User',
          'password': 'StrongPass!23',
          'role': 'teacher',
        });

        return {
          'data': {'verification_token': 'token-abc'},
        };
      });

    final repository = AuthRepository(dio: dio);

    final result = await repository.register(
      'teacher@example.com',
      'Teacher User',
      'StrongPass!23',
      'teacher',
    );

    expect(result, 'token-abc');
  });
}
