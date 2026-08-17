import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:professor_os/features/admin/data/admin_repository.dart';

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
  test('AdminRepository.listUsers sends page and role filters', () async {
    final dio = Dio()
      ..httpClientAdapter = _MockHttpClientAdapter((options) {
        expect(options.method, 'GET');
        expect(options.path, '/admin/users');
        expect(options.queryParameters, {
          'page': 2,
          'page_size': 25,
          'role': 'student',
          'search': 'ali',
        });

        return {
          'data': {'items': [
            {'id': 1, 'email': 'ali@example.com'},
          ]},
        };
      });

    final repository = AdminRepository(dio: dio);

    final result = await repository.listUsers(
      page: 2,
      pageSize: 25,
      role: 'student',
      search: 'ali',
    );

    expect(result['items'], isNotEmpty);
  });

  test('AdminRepository.importUsersCsv sends multipart file', () async {
    final dio = Dio()
      ..httpClientAdapter = _MockHttpClientAdapter((options) {
        expect(options.method, 'POST');
        expect(options.path, '/admin/users/import');
        expect(options.data, isA<FormData>());
        final formData = options.data as FormData;
        expect(formData.fields.length, 0);
        expect(formData.files.length, 1);
        expect(formData.files.first.key, 'file');
        expect(formData.files.first.filename, 'users.csv');

        return {
          'data': {'imported': 2},
        };
      });

    final repository = AdminRepository(dio: dio);

    final result = await repository.importUsersCsv(
      Uint8List.fromList([1, 2, 3]),
      'users.csv',
    );

    expect(result['imported'], 2);
  });
}
