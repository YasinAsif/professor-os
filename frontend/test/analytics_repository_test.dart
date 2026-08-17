import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/features/analytics/data/analytics_repository.dart';

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
  test('AnalyticsRepository.getDashboard calls the course analytics endpoint', () async {
    final dio = Dio()
      ..httpClientAdapter = _MockHttpClientAdapter((options) {
        expect(options.method, 'GET');
        expect(options.path, '/courses/7/analytics');
        return {
          'data': {'course_id': 7, 'total_students': 25},
        };
      });

    final repository = AnalyticsRepository(dio: dio);

    final result = await repository.getDashboard(7);

    expect(result['course_id'], 7);
    expect(result['total_students'], 25);
  });

  test('AnalyticsRepository.refreshAnalytics adds threshold query param', () async {
    final dio = Dio()
      ..httpClientAdapter = _MockHttpClientAdapter((options) {
        expect(options.method, 'POST');
        expect(options.path, '/courses/7/analytics/refresh');
        expect(options.queryParameters, {'threshold': 75.0});
        return {'data': {'ok': true}};
      });

    final repository = AnalyticsRepository(dio: dio);

    await repository.refreshAnalytics(7, threshold: 75.0);
  });
}
